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
	var d := {"RAM": pc.ram.filter(func(r): return r != "")}
	for t in ["CPU", "GPU", "COOLER", "CASE", "MB"]:
		d[t] = pc.parts.get(t, "")
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
	return s


static func _s(id: String, key: String, def = 0):
	return DB.PARTS[id].get(key, def) if id != "" else def


## 계산. ok = 목표 달성, points = 채점의 PC 성능(0~20)
static func run(d: Dictionary, use: Dictionary) -> Dictionary:
	var r := {"kind": use.get("kind", "office"), "notes": [], "value": 0.0, "target": 0.0, "ok": false, "ratio": 0.0, "limit": ""}
	if d["CPU"] == "" or d["GPU"] == "" or d["RAM"].is_empty():
		r["notes"].append("CPU · 그래픽카드 · RAM이 있어야 테스트할 수 있어요")
		r["points"] = 0.0
		return r
	var gb := 0
	for id in d["RAM"]:
		gb += _s(id, "gb", 8)
	var dual: bool = d["RAM"].size() >= 2 and d["RAM"][0] == d["RAM"][1]
	var af: int = _s(d["CASE"], "airflow", 2)
	var cpu_w: int = _s(d["CPU"], "watt")
	var tdp: int = _s(d["COOLER"], "tdp", 95)
	var gpu_w: int = _s(d["GPU"], "watt")
	r["cpu_temp"] = clampi(roundi(30 + 60.0 * cpu_w / tdp - (af - 1) * 4), 30, 105)
	r["gpu_temp"] = clampi(roundi(45 + gpu_w * 0.1 - (af - 1) * 6), 35, 100)
	r["noise"] = roundi(16 + _s(d["COOLER"], "noise", 12) + gpu_w / 40.0 + af)
	var cpu_thr := 0.75 if r["cpu_temp"] >= 90 else 1.0
	var gpu_thr := 0.85 if r["gpu_temp"] >= 85 else 1.0
	if cpu_thr < 1:
		r["notes"].append("CPU가 %d°C로 너무 뜨거워서 스스로 느려졌어요 → 더 좋은 쿨러" % r["cpu_temp"])
	if gpu_thr < 1:
		r["notes"].append("그래픽카드가 %d°C로 뜨거워요 → 바람이 잘 통하는 케이스" % r["gpu_temp"])
	if r["cpu_temp"] >= 100:   # 쿨러가 턱없이 모자라면 테스트 도중 꺼짐
		r["notes"].push_front("CPU가 %d°C까지 올라가서 테스트 중에 꺼졌어요 → 쿨러를 바꿔 주세요" % r["cpu_temp"])
		r["shutdown"] = true
		r["points"] = 0.0
		return r
	var mt: float = _s(d["CPU"], "mt") * cpu_thr
	match r["kind"]:
		"game":
			var w: float = GENRE[use["genre"]]
			var ram_f := 0.75 if gb < 16 else 1.0
			var cpu_fps: float = _s(d["CPU"], "game") * w * cpu_thr * ram_f * (1.05 if dual else 1.0) * (0.8 if use.get("stream", false) else 1.0)
			var gpu_fps: float = _s(d["GPU"], "fps") * w * RES[use["res"]] * gpu_thr * (0.85 if use["res"] == "4K" and _s(d["GPU"], "vram") < 12 else 1.0)
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
			if use.get("stream", false):
				r["notes"].append("방송 프로그램이 CPU를 20% 써요")
		"render":
			var ram_f := 1.0 if gb >= 32 else 1.15 if gb >= 16 else 1.5
			r["value"] = 120.0 / (mt + _s(d["GPU"], "fps") / 40.0) * ram_f
			r["target"] = float(use["min"])
			r["ratio"] = r["target"] / r["value"]
			r["limit"] = "CPU 코어 수"
			if gb < 32:
				r["notes"].append("RAM %dGB → 32GB면 렌더가 더 빨라요" % gb)
		"code":
			var ram_f := 1.0 if gb >= 32 else 1.1 if gb >= 16 else 1.5
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
	r["ok"] = r["ratio"] >= 1.0 and (not use.has("quiet") or r["noise"] <= use["quiet"])
	if r["kind"] != "office" and r["ratio"] >= 1.6:
		r["notes"].append("목표보다 훨씬 좋아요. 더 싼 부품으로도 충분해요 (마진↑)")
	r["points"] = max(0.0, pts)
	return r


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
