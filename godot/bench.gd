class_name Bench
## 성능 테스트: 조립한 부품으로 손님 용도(게임 FPS · 렌더 시간 · 빌드 시간 · 사무)의 실제 숫자를 계산한다.
## FPS = min(CPU 한계, 그래픽카드 한계) → 둘 중 낮은 쪽이 '병목'. 발열 · RAM 부족 · 방송 부하 · 소음도 반영.
## 어려운 숫자 대신 쉬운 말(notes)과 '가장 싸게 고치는 방법'(fix)을 같이 돌려준다.

const GENRE := {"aos": 2.0, "fps": 1.0, "open": 0.6}   # 가벼운 게임일수록 프레임이 잘 나옴
const GENRE_NAMES := {"aos": "AOS 게임", "fps": "FPS 게임", "open": "오픈월드 게임"}
const RES := {"1080p": 1.0, "1440p": 0.7, "4K": 0.42}   # 해상도가 높을수록 그래픽카드가 힘듦
const KIND_NAMES := {"office": "문서 · 화상회의", "code": "코딩(빌드)", "render": "영상 · 그림 렌더"}


## 조립 상태 → 계산에 쓰는 부품 묶음 {CPU, GPU, COOLER, CASE: id, RAM: [id...]}
static func parts_of(pc: PCBuild) -> Dictionary:
	var d := {"RAM": pc.ram.filter(func(r): return r != ""), "faults": pc.faults, "loose": pc.loose(), "tidy": pc.tidy(), "laptop": pc.has_meta("laptop")}
	for t in ["CPU", "GPU", "COOLER", "CASE", "MB", "PSU", "SSD"]:
		d[t] = pc.parts.get(t, "")
	d["dead_cooler"] = pc.dead("COOLER")   # 고장 난 중고 쿨러: 팬이 안 돎
	d["cond"] = {}
	for t in ["PSU", "COOLER", "GPU"]:
		d["cond"][t] = pc.cond_of(t)
	return d


## 손님 요구를 한 줄로
static func describe(use: Dictionary) -> String:
	var s: String
	match use.get("kind", "office"):
		"game": s = "%s %s %dfps 이상" % [GENRE_NAMES[use["genre"]], use["res"], use["fps"]] + (" · 방송 겸용" if use.get("stream", false) else "")
		"render": s = "렌더 %d분 안에" % use["min"]
		"code": s = "빌드 %d초 안에" % use["sec"]
		_: s = KIND_NAMES["office"] + " (켜지기만 하면 OK)"
	if use.has("quiet"):
		s += " · 조용하게 %ddB 이하" % use["quiet"]
	if use.get("wifi", false):
		s += " · 무선 인터넷(Wi-Fi)"
	if use.has("storage"):
		s += " · 저장공간 %s 이상" % (("%dTB" % (use["storage"] / 1000)) if use["storage"] >= 1000 else "%dGB" % use["storage"])
	if use.has("vram"):
		s += " · 그래픽 메모리 %dGB 이상" % use["vram"]
	return s


## SSD 용량 글자 → GB ("1TB" → 1000)
static func gb_of(cap: String) -> int:
	return int(cap.to_int() * (1000 if cap.ends_with("TB") else 1))


static func _s(id: String, key: String, def = 0):
	return DB.PARTS[id].get(key, def) if id != "" else def


## 계산. ok = 목표 달성, points = 채점의 PC 성능(0~20)
static func run(d: Dictionary, use: Dictionary) -> Dictionary:
	var r := {"kind": use.get("kind", "office"), "notes": [], "value": 0.0, "target": 0.0, "ok": false, "ratio": 0.0, "limit": ""}
	if d["GPU"] == "" and _s(d["CPU"], "igpu") > 0:   # 내장 그래픽: 그래픽카드 대신 CPU가 화면을 그림 (전력 · 발열은 CPU에 포함)
		d = d.duplicate()
		d["IGPU"] = _s(d["CPU"], "igpu")
	if d["CPU"] == "" or d["RAM"].is_empty() or (d["GPU"] == "" and not d.has("IGPU")):
		r["notes"].append("CPU · RAM이 있어야 테스트할 수 있어요 (내장 그래픽이 없는 CPU면 그래픽카드도)" if d["GPU"] != "" or d["CPU"] == "" or d["RAM"].is_empty() else "이 CPU는 내장 그래픽이 없어서 그래픽카드가 필요해요")
		r["points"] = 0.0
		return r
	var gb := 0
	for id in d["RAM"]:
		gb += _s(id, "gb", 8)
	var dual: bool = d["RAM"].size() >= 2 and d["RAM"][0] == d["RAM"][1] and not d.get("faults", {}).has("ram_channel")   # 같은 RAM 2개를 A2 · B2에 = 듀얼 채널
	var mhz: int = d["RAM"].map(func(i): return _s(i, "mhz", 3200)).min() if not d["RAM"].is_empty() else 3200   # 섞어 꽂으면 느린 쪽에 맞춰짐
	var ram_speed: float = 1.0 + (mhz - 3200) / 3200.0 * 0.12   # RAM이 빠르면 CPU가 덜 기다림
	var af: int = _s(d["CASE"], "airflow", 2) + (1 if d.get("tidy", false) else 0)   # 선 정리 = 바람길
	var cpu_w: int = _s(d["CPU"], "watt")
	var cd: Dictionary = d.get("cond", {})
	var tdp: float = _s(d["COOLER"], "tdp", 95) * (0.75 if cd.get("COOLER", 100) < 60 else 1.0)   # 낡은 쿨러: 팬 베어링 · 굳은 구리스
	var gpu_w: int = _s(d["GPU"], "watt")
	r["cpu_temp"] = clampi(roundi(30 + 60.0 * cpu_w / tdp - (af - 1) * 4), 30, 105)
	r["gpu_temp"] = clampi(roundi(45 + gpu_w * 0.1 - (af - 1) * 6), 35, 100) + (8 if cd.get("GPU", 100) < 60 else 0)
	var f: Dictionary = d.get("faults", {})
	r["cpu_temp"] += (25 if f.has("paste_dry") else 0) + (10 if f.has("dust") else 0) + (70 if f.has("cpu_fan") or d.get("dead_cooler", false) else 0)
	r["gpu_temp"] += 10 if f.has("dust") else 0
	var lz: Array = d.get("loose", [])
	if "COOLER" in lz:   # 쿨러가 CPU에 꽉 안 붙음
		r["cpu_temp"] += 30
		r["notes"].append("쿨러 나사가 헐거워서 CPU가 뜨거워요 → 드라이버로 조이기")
	r["noise"] = roundi(-_s(d["CASE"], "quiet", 0) + (5 if cd.get("COOLER", 100) < 60 else 0) + 16 + _s(d["COOLER"], "noise", 12) + gpu_w / 40.0 + af + (7 if f.has("dust") else 0) + (4 if f.has("bloat") else 0))
	var cpu_thr := 0.75 if r["cpu_temp"] >= 90 else 1.0
	var gpu_thr := 0.85 if r["gpu_temp"] >= 85 else 1.0
	if cpu_thr < 1:
		r["notes"].append("CPU가 %d°C로 너무 뜨거워서 스스로 느려졌어요 → 더 좋은 쿨러" % r["cpu_temp"])
	if gpu_thr < 1:
		r["notes"].append("그래픽카드가 %d°C로 뜨거워요 → 바람이 잘 통하는 케이스" % r["gpu_temp"])
	var psu_cap: float = _s(d.get("PSU", ""), "capacity", 9999) * _s(d.get("PSU", ""), "real", 1.0) * (0.55 + 0.45 * cd.get("PSU", 100) / 100.0)   # 낡은 파워 · 인증 없는 '뻥파워'는 표시 용량을 못 냄
	var spike: float = gpu_w * (1.4 if gpu_w >= 250 else 1.15)   # 고성능 그래픽카드는 순간적으로 전력이 확 튐 (스파이크)
	r["watt"] = cpu_w + gpu_w + 60
	if cpu_w + gpu_w + 60 > psu_cap or cpu_w + spike + 60 > psu_cap:
		r["notes"].push_front("부하가 걸리자 파워가 버티지 못하고 꺼졌어요" if cpu_w + gpu_w + 60 > psu_cap else "게임 중 순간 전력(스파이크)이 튀어서 파워가 꺼졌어요 → 여유 있는 파워 (평소 전력 +30%)")
		r["shutdown"] = true
		r["points"] = 0.0
		return r
	if r["cpu_temp"] >= 100:   # 쿨러가 턱없이 모자라면 테스트 도중 꺼짐
		r["notes"].push_front("CPU가 %d°C까지 올라가서 테스트 중에 꺼졌어요 → 쿨러를 바꿔 주세요" % r["cpu_temp"])
		r["shutdown"] = true
		r["points"] = 0.0
		return r
	r["throttle"] = cpu_thr < 1
	r["ram_low"] = gb < 16
	r["gb"] = gb
	if "MB" in lz or "PSU" in lz:
		r["noise"] += 4
		r["notes"].append("본체에서 달그락 소리가 나요 → 나사 조이기")
	var soft: float = (0.9 if f.has("xmp_off") or f.has("cmos_battery") else 1.0) * (0.92 if f.has("ram_channel") else 1.0) * (0.35 if f.has("bloat") else 1.0)   # 숨은 고장: 숫자만 조금 모자람
	if cpu_w > _s(d.get("MB", ""), "vrm", 999):   # 보드 전원부가 CPU 전력을 못 대 줌
		cpu_thr *= 0.8
		r["notes"].append("보드 전원부(VRM)가 약해서 CPU가 제 힘을 못 내요 → 더 좋은 보드")
	var mt: float = _s(d["CPU"], "mt") * cpu_thr * soft * (1.0 + (ram_speed - 1.0) * 0.4)
	match r["kind"]:
		"game":
			var w: float = GENRE[use["genre"]]
			var ram_f := 0.75 if gb < 16 else 1.0
			var enc: bool = _s(d["GPU"], "enc", false)   # 그래픽카드 인코더로 방송하면 CPU 부담이 적음
			var cpu_fps: float = _s(d["CPU"], "game") * w * cpu_thr * soft * ram_f * ram_speed * (1.05 if dual else 1.0) * ((0.93 if enc else 0.8) if use.get("stream", false) else 1.0)
			var vram_need: int = {"1080p": 6, "1440p": 8, "4K": 12}[use["res"]] + (2 if use["genre"] == "open" else 0)   # 해상도 · 오픈월드일수록 텍스처가 큼
			var vram_short: bool = not d.has("IGPU") and _s(d["GPU"], "vram", 8) < vram_need
			var gpu_fps: float = d.get("IGPU", _s(d["GPU"], "fps")) * (0.88 if cd.get("GPU", 100) < 60 else 1.0) * w * RES[use["res"]] * gpu_thr * (0.85 if vram_short else 1.0)
			r["cpu_fps"] = roundi(cpu_fps)
			r["gpu_fps"] = roundi(gpu_fps)
			r["value"] = min(cpu_fps, gpu_fps)
			r["target"] = float(use["fps"])
			r["ratio"] = r["value"] / r["target"]
			r["limit"] = "CPU" if cpu_fps < gpu_fps else "그래픽카드"
			var other: float = max(cpu_fps, gpu_fps)
			if r["limit"] == "CPU":
				r["notes"].push_front("CPU가 느려서 그래픽카드가 %d%%만 일하고 있어요" % roundi(100 * cpu_fps / other))
			else:
				r["notes"].push_front("그래픽카드가 힘들어해요 (CPU는 %dfps까지 여유)" % roundi(other))
			if gb < 16:
				r["notes"].append("RAM이 %dGB뿐이라 화면이 끊겨요 → 16GB 이상" % gb)
			# 1% 최저 프레임: 평균이 높아도 가끔 뚝 떨어지면 손님은 '끊긴다'고 느낌
			var sata: bool = _s(d.get("SSD", ""), "read", 3500) < 1000
			var low: float = (0.8 if r["limit"] != "CPU" else 0.7) * (0.6 if gb < 16 else 1.0) * (1.0 if dual else 0.9) * (0.88 if sata and use["genre"] == "open" else 1.0) * (0.7 if vram_short else 1.0) * (0.9 if cpu_thr < 1 else 1.0)
			r["low1"] = roundi(r["value"] * low)
			if vram_short:
				r["notes"].append("그래픽 메모리 %dGB < 필요 %dGB → 텍스처가 늦게 떠서 끊겨요" % [_s(d["GPU"], "vram", 0), vram_need])
			if not dual:
				r["notes"].append("RAM이 싱글 채널이라 최저 프레임이 낮아요 → 같은 RAM 2개를 A2 · B2에")
			if sata and use["genre"] == "open":
				r["notes"].append("SATA SSD라 맵 불러올 때 멈칫해요 → NVMe(M.2) SSD")
			if use.get("stream", false):
				r["notes"].append("그래픽카드 인코더로 방송해서 CPU 부담이 적어요" if enc else "방송 인코딩을 CPU가 해서 20% 써요 → 인코더 있는 그래픽카드")
		"render":
			var ram_f := 1.0 if gb >= 32 else 1.15 if gb >= 16 else 1.5
			r["value"] = 120.0 / (mt + d.get("IGPU", _s(d["GPU"], "fps")) / 40.0) * ram_f
			r["target"] = float(use["min"])
			r["ratio"] = r["target"] / r["value"]
			r["limit"] = "CPU 코어 수"
			if gb < 32:
				r["notes"].append("RAM %dGB → 32GB면 렌더가 더 빨라요" % gb)
		"code":
			var ram_f := (1.0 if gb >= 32 else 1.1 if gb >= 16 else 1.5) * (1.2 if _s(d.get("SSD", ""), "read", 3500) < 1000 else 1.0)   # 느린 SATA SSD는 빌드도 느림
			r["value"] = 600.0 / mt * ram_f
			r["target"] = float(use["sec"])
			r["ratio"] = r["target"] / r["value"]
			r["limit"] = "CPU 코어 수"
		_:
			r["ratio"] = 1.0
	var pts := 20.0 * clampf((r["ratio"] - 0.5) / 0.5, 0.0, 1.0)
	if use.has("quiet") and r["noise"] > use["quiet"]:
		pts -= min(10.0, (r["noise"] - use["quiet"]) * 2.0)
		r["notes"].append("소음 %ddB: 손님 기준 %ddB보다 시끄러워요 → 조용한 쿨러 · 작은 그래픽카드" % [r["noise"], use["quiet"]])
	if r["kind"] == "game" and gb < 16:   # 평균 FPS가 높아도 주기적으로 멈칫하면 손님은 못 참음
		pts = minf(pts, 10.0)
	if r["kind"] == "game" and r.get("low1", 9999) < r["target"] * 0.5:   # 최저 프레임이 목표의 절반도 안 되면 감점
		pts -= 3.0
	var extra_ok := true   # 손님 추가 조건: Wi-Fi · 저장공간 · 그래픽 메모리
	if use.get("wifi", false) and not (d.get("laptop", false) or _s(d.get("MB", ""), "wifi", false)):
		extra_ok = false
		r["notes"].push_front("무선 인터넷이 안 돼요 → Wi-Fi 있는 보드")
	if use.has("storage") and gb_of(str(_s(d.get("SSD", ""), "capacity", "0GB"))) < use["storage"]:
		extra_ok = false
		r["notes"].push_front("저장공간이 모자라요 → 더 큰 SSD")
	if use.has("vram") and _s(d["GPU"], "vram", 0) < use["vram"]:
		extra_ok = false
		r["notes"].push_front("그래픽 메모리(VRAM)가 %dGB 필요해요 → 메모리 큰 그래픽카드" % use["vram"])
	if not extra_ok:
		pts *= 0.5
	r["ok"] = extra_ok and r["ratio"] >= 1.0 and (not use.has("quiet") or r["noise"] <= use["quiet"]) and not (r["kind"] == "game" and gb < 16)
	if r["kind"] != "office" and r["ratio"] >= 1.6:
		r["notes"].append("목표보다 훨씬 좋아요. 더 싼 부품으로도 충분해요 (마진↑)")
	r["points"] = max(0.0, pts)
	return r


## 테스트 중 FPS(또는 속도) 변화 n개: 출렁임 + 과열이면 처음엔 높다가 떨어짐 + RAM 부족이면 주기적으로 뚝 끊김
static func series(r: Dictionary, n: int) -> Array:
	var out := []
	for k in n:
		var v: float = r["value"] * (1.0 + 0.05 * sin(k * 1.3) + 0.03 * sin(k * 3.7 + 1.0))
		if r.get("throttle", false):
			v *= lerpf(1.0 / 0.75, 1.0, minf(1.0, k / (n * 0.3)))
		if r.get("ram_low", false) and r["kind"] == "game" and k % 9 == 4:
			v *= 0.35
		elif r.get("low1", 0) > 0 and k % 11 == 7:   # 1% 최저: 가끔 이만큼 떨어짐
			v = r["low1"]
		out.append(v)
	return out


## 결과 숫자를 쉬운 말로: "132fps / 목표 144"
static func value_text(r: Dictionary) -> String:
	match r["kind"]:
		"game": return "%dfps" % roundi(r["value"])
		"render": return "%.1f분" % r["value"]
		"code": return "%d초" % roundi(r["value"])
	return "OK"


static func short(r: Dictionary) -> String:
	if r.get("shutdown", false):
		return "과열로 꺼짐"
	if r["kind"] == "office":
		return "켜지면 OK" + (" · 소음 %ddB" % r["noise"] if r.has("noise") else "")
	if r["value"] == 0.0:
		return "부품 부족"
	var goal: String = {"game": "%dfps" % r["target"], "render": "%d분" % r["target"], "code": "%d초" % r["target"]}[r["kind"]]
	return "%s / 목표 %s" % [value_text(r), goal]


## 목표에 못 미치면: 부품 하나(소켓이 다른 CPU면 보드까지)만 바꿔서 달성하는 가장 싼 방법 {type, id, mb?, value, cost} 또는 {}
static func fix(d: Dictionary, use: Dictionary, unlocked: Callable) -> Dictionary:
	if run(d, use)["ok"]:
		return {}
	var best := {}
	for t in ["CPU", "GPU", "RAM", "COOLER", "CASE"]:
		for id in DB.PARTS:
			var p: Dictionary = DB.PARTS[id]
			if p["type"] != t or not unlocked.call(p):
				continue
			var mb := ""
			var mb_cost := 0
			if t == "CPU" and d.get("MB", "") != "" and p["socket"] != DB.PARTS[d["MB"]]["socket"]:
				for b in DB.PARTS:   # 소켓이 다르면 그 소켓의 가장 싼 보드로 같이 바꿈 (케이스에 들어가는 크기)
					var q: Dictionary = DB.PARTS[b]
					var fits: bool = d.get("CASE", "") == "" or q.get("size") == "mATX" or DB.PARTS[d["CASE"]]["mb_max"] == "ATX"
					if q["type"] == "MB" and q["socket"] == p["socket"] and unlocked.call(q) and fits and (mb == "" or q["price"] < mb_cost):
						mb = b
						mb_cost = q["price"]
				if mb == "":
					continue
			var e := d.duplicate(true)
			if t == "RAM":
				e["RAM"] = [id, id]
			else:
				e[t] = id
			var r := run(e, use)
			var cost: int = p["price"] * (2 if t == "RAM" else 1) + mb_cost
			if r["ok"] and (best.is_empty() or cost < best["cost"]):
				best = {"type": t, "id": id, "mb": mb, "value": r["value"], "cost": cost}
	return best
