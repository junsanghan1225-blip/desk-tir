class_name Rules
## 배치(room.py) · 배선(cables.py) · 채점(scorer.py) 규칙 이식. 좌표는 pico2d와 같은 1280x720, y가 위로 커지는 좌표.
## 놓인 소품 p = {"id", "layer", "x", "y", "color"?} · 케이블 c = {"dev": p, "type", "port"} · 사각형 = [x1, y1, x2, y2]

# ---------- 배치 ----------
const AREA_X1 := 300
const AREA_X2 := 1150      # 오른쪽은 PC 자리
const DESK_Y := 210        # 책상 상판 높이
const WALL_Y1 := 400
const WALL_Y2 := 640
const SLOT_X0 := 300
const SLOT_W := 110
const COLORS := 4
const UNIT := 4.6          # 책상 좌표 1cm. 책상 = 850 x 380 = 185 x 83cm (그림은 5.5px/cm로 그려져 DB.size_of에서 줄임)
const DESK_DEPTH := 380   # 책상 앞뒤 깊이 (탑뷰). z = 0이 벽쪽, 클수록 앞
const Z_STEP := 10
const LAYER_NAMES := {"wall": "벽", "desk": "책상 위"}


static func inside(x: float, y: float, r: Array) -> bool:
	return r[0] <= x and x <= r[2] and r[1] <= y and y <= r[3]


static func rect_of(p: Dictionary) -> Array:
	if DB.ITEMS.has(p["id"]) and DB.ITEMS[p["id"]].get("mount", "") == "arm":   # 모니터 암: x = 집게 가운데, 누르는 곳은 집게 + 기둥
		return [p["x"] - 16, p["y"] - 24, p["x"] + 16, p["y"] + 64]
	var s := DB.size_of(p["id"])
	return [p["x"], p["y"], p["x"] + s.x, p["y"] + s.y]


## 책상 위에서 차지하는 실제 크기 (items.json foot = [가로 cm, 앞뒤 cm]). 없으면 정면 그림 너비 x 60.
static func foot_of(id: String) -> Vector2i:
	if DB.ITEMS[id].has("foot"):
		return Vector2i(roundi(DB.ITEMS[id]["foot"][0] * UNIT), roundi(DB.ITEMS[id]["foot"][1] * UNIT))
	return Vector2i(DB.size_of(id).x, 60)


static func depth_of(id: String) -> int:
	return foot_of(id).y


## 책상 위 좌우 범위: 정면 그림 가운데를 중심으로 실제 가로 크기만큼
static func foot_x(id: String, x: float) -> Vector2:
	var c := x + DB.size_of(id).x / 2.0
	return Vector2(c - foot_of(id).x / 2.0, c + foot_of(id).x / 2.0)


## 책상 위는 좌우(x)와 앞뒤(z)가 둘 다 겹칠 때만 부딪힌다. 벽은 z 없음.
static func fits_at(placed: Array, id: String, layer: String, x: int, y: int, ignore = null, z := 0) -> bool:
	var s := DB.size_of(id)
	var d := depth_of(id)
	if DB.ITEMS[id]["layer"] != layer or x < AREA_X1 or x + s.x > AREA_X2 + 1:
		return false
	if layer == "wall" and (y < WALL_Y1 or y + s.y > WALL_Y2):
		return false
	if layer == "desk" and (z < 0 or z + d > DESK_DEPTH or foot_x(id, x).x < AREA_X1 - 1 or foot_x(id, x).y > AREA_X2 + 1):
		return false
	for p in placed:
		if is_same(p, ignore) or p["layer"] != layer or is_mounted(p):   # 붙는 소품은 책상 칸을 차지하지 않음
			continue
		if layer == "wall":
			var r := rect_of(p)
			if x < r[2] - 2 and r[0] < x + s.x - 2 and y < r[3] - 2 and r[1] < y + s.y - 2:
				return false
			continue
		var a := foot_x(id, x)   # 책상 위: 실제 크기로 좌우 · 앞뒤가 둘 다 겹치면 부딪힘
		var b := foot_x(p["id"], p["x"])
		var pz: int = p.get("z", 0)
		if a.x < b.y - 2 and b.x < a.y - 2 and z < pz + depth_of(p["id"]) - 2 and pz < z + d - 2:
			return false
	return true


## 정면 뷰에서 놓을 때: 그 x에서 비어 있는 앞뒤 자리 (벽쪽부터). prefer 자리가 비어 있으면 그대로. 없으면 -1.
static func free_z(placed: Array, id: String, x: int, ignore = null, prefer := -1) -> int:
	if prefer >= 0 and fits_at(placed, id, "desk", x, DESK_Y, ignore, prefer):
		return prefer
	for z in range(0, DESK_DEPTH - depth_of(id) + 1, Z_STEP):
		if fits_at(placed, id, "desk", x, DESK_Y, ignore, z):
			return z
	return -1


## 예전 칸 번호 → 자유 좌표 (테스트 · 자동 배치용)
static func slot_pos(id: String, layer: String, slot: int) -> Vector2i:
	return Vector2i(SLOT_X0 + slot * SLOT_W + 6, DESK_Y if layer == "desk" else 495 - DB.size_of(id).y / 2)


static func place_slot(placed: Array, id: String, layer: String, slot: int) -> Dictionary:
	var pos := slot_pos(id, layer, slot)
	var p := {"id": id, "layer": layer, "x": pos.x, "y": pos.y}
	placed.append(p)
	return p


static func item_at(placed: Array, x: float, y: float):
	for want in ["mount", "desk", "wall"]:  # 모니터에 붙은 것 → 책상 위 → 벽 순서로 (앞에 있는 것 먼저)
		for p in placed:
			if (p["layer"] if not is_mounted(p) else "mount") == want and inside(x, y, rect_of(p)):
				return p
	return null


static func adjacent(a: Dictionary, b: Dictionary, gap := 30) -> bool:
	if a["layer"] != b["layer"]:
		return false
	var ra := rect_of(a)
	var rb := rect_of(b)
	return max(ra[0], rb[0]) - min(ra[2], rb[2]) <= gap and ra[1] < rb[3] and rb[1] < ra[3]


## 손가락 위치(물건 중심) → 놓일 [layer, x, y]. 그 소품의 레이어 근처가 아니면 null.
static func drop_target(id: String, x: float, y: float):
	var layer: String = DB.ITEMS[id]["layer"]
	var s := DB.size_of(id)
	var w: float = max(s.x, foot_of(id).x) if layer == "desk" else s.x   # 정면 그림 · 실제 크기 둘 다 책상 안에
	var left := int(clamp(x, AREA_X1 + w / 2.0, AREA_X2 - w / 2.0) - s.x / 2.0)
	if layer == "desk":
		return [layer, left, DESK_Y] if y >= DESK_Y - 60 and y <= DESK_Y + 240 else null
	if y < WALL_Y1 - 30:
		return null
	return [layer, left, int(clamp(y - s.y / 2.0, WALL_Y1, WALL_Y2 - s.y))]


# ---------- 현실적인 배치: 붙는 소품 · 자석 ----------
## mount: "monitor" = 모니터 윗면에 끼움 (host · slot) / "edge" = 책상 앞 가장자리 걸이 / "clamp" = 책상 뒤 가장자리 집게
static func is_monitor(id: String) -> bool:   # 화면 있는 기기 중 노트북 · 휴대용 빼고
	return DB.ITEMS[id].has("hz") and not DB.ITEMS[id].has("pc") and id != "monitor_portable"


static func monitor_ids() -> Array:
	return DB.ITEMS.keys().filter(is_monitor)
const MOUNT_TOP := {"monitor_bar": 14.0 / 34, "webcam": 26.0 / 40}   # 그림 윗변이 모니터 윗변보다 (그림 높이의) 얼마나 위인지
const ARM_REACH := 160.0   # 모니터 암이 집게에서 뻗을 수 있는 가로 거리(px)    # 이 거리 안이면 짝 소품 옆 제자리로 끌려감


static func mount_of(id: String) -> String:
	return DB.ITEMS[id].get("mount", "")


static func is_mounted(p: Dictionary) -> bool:
	return mount_of(p["id"]) != ""


static func center_x(p: Dictionary) -> float:
	return p["x"] + DB.size_of(p["id"]).x / 2.0


## 붙은 소품의 위치를 붙은 곳에 맞춘다 (모니터를 옮기면 같이 따라감). 그림 · 클릭 · 배선 모두 이 x · y · z를 쓴다.
static func mount_pos(p: Dictionary) -> void:
	var s := DB.size_of(p["id"])
	match mount_of(p["id"]):
		"monitor":
			var h: Dictionary = p["host"]
			var hr := rect_of(h)
			var cx: float = (hr[0] + hr[2]) / 2.0 + (0.0 if p.get("slot", 0) == 0 else (hr[2] - hr[0]) * 0.3)
			p["x"] = int(cx - s.x / 2.0)
			p["y"] = int(hr[3] + MOUNT_TOP.get(p["id"], 0.3) * s.y - s.y)
			p["z"] = h.get("z", 0)
		"edge":
			p["y"] = int(DESK_Y + s.y * 0.06 - s.y)   # 집게가 상판 앞 모서리를 물고 아래로 늘어짐
			p["z"] = DESK_DEPTH - depth_of(p["id"]) / 2
		"clamp":
			p["y"] = DESK_Y
			p["z"] = 0
		"arm":   # 집게는 책상 뒤에 고정, 팔이 모니터까지 뻗음 (모니터가 팔 길이보다 멀어지면 집게가 따라 미끄러짐)
			var h: Dictionary = p["host"]
			var hc: float = center_x(h)
			if not p.has("x"):
				p["x"] = int(hc)   # 처음엔 모니터 바로 뒤
			elif absf(p["x"] - hc) > ARM_REACH:
				p["x"] = int(clampf(hc + (ARM_REACH if p["x"] > hc else -ARM_REACH) * 0.6, AREA_X1 + 10, AREA_X2 - 10))
			p["y"] = DESK_Y
			p["z"] = h.get("z", 0) - 1


static func sync_mounts(placed: Array) -> void:
	for p in placed:
		if is_mounted(p) and (not mount_of(p["id"]) in ["monitor", "arm"] or placed.has(p["host"])):
			mount_pos(p)


## 모니터에 붙은 소품들 (모니터를 치우면 같이 창고로)
static func mounts_on(placed: Array, host: Dictionary) -> Array:
	return placed.filter(func(p): return mount_of(p["id"]) in ["monitor", "arm"] and is_same(p.get("host"), host))


## 모니터 위 빈 자리: 0 = 가운데, 1 = 오른쪽. 없으면 -1
static func free_slot(placed: Array, host: Dictionary, ignore = null) -> int:
	var used := mounts_on(placed, host).filter(func(p): return not is_same(p, ignore) and mount_of(p["id"]) == "monitor").map(func(p): return p.get("slot", 0))
	for k in [0, 1]:
		if not k in used:
			return k
	return -1


## 가장자리 걸이 · 집게: 책상 안 + 같은 종류끼리 안 겹침
static func edge_fits(placed: Array, id: String, x: int, ignore = null) -> bool:
	var w := DB.size_of(id).x
	if x < AREA_X1 or x + w > AREA_X2 + 1:
		return false
	for p in placed:
		if not is_same(p, ignore) and mount_of(p["id"]) == mount_of(id) and x < p["x"] + DB.size_of(p["id"]).x - 4 and p["x"] < x + w - 4:
			return false
	return true


## 놓을 자리 후보 [x, z]. 탑뷰(z >= 0)는 놓은 자리 그대로 (키보드는 모니터 앞 같은 강제 자리 없음).
## 정면 뷰(z < 0)는 앞뒤 정보가 없어 구역(뒤 = 벽쪽, 앞 = 손 닿는 곳)으로 앞뒤만 정함.
static func magnet(_placed: Array, id: String, x: int, z: int, _ignore = null) -> Array:
	if z >= 0:
		return [[x, z]]
	var f := foot_of(id)
	var out := []
	match DB.ITEMS[id].get("zone", ""):
		"back":
			out.append([x, 0])
		"front":
			out.append([x, DESK_DEPTH - f.y - 20])
	return out


# ---------- 배선 ----------
const MAX_PORTS := {"HDMI": 2, "DP": 3, "USB": 6, "AUDIO": 2}
const PORT_COLOR := {"HDMI": Color8(255, 150, 60), "DP": Color8(255, 77, 141), "USB": Color8(46, 230, 214), "AUDIO": Color8(255, 214, 92)}
const PORT_NAMES := {"HDMI": "HDMI", "DP": "DP", "USB": "USB", "AUDIO": "오디오"}
const PORT_ORDER := ["HDMI", "DP", "USB", "AUDIO"]   # 포트는 한 줄: 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다
const PORT_Y := 170
const PORT_X0 := 196
const PORT_GAP := 74
const SLOT_OFFSET := {"HDMI": 0, "DP": 2, "USB": 5, "AUDIO": 11}
const PORT_PANEL := [150, 114, 1130, 214]
const PLUG_Y := 405


## 영상(HDMI · DP)은 그래픽카드(없으면 내장 그래픽의 보드 단자), USB는 메인보드가 개수를 정한다.
static func port_count(t: String, pc: PCBuild) -> int:
	if t == "DP":
		return pc.spec("GPU")["dp"] if pc.has("GPU") else (1 if pc.igpu() else 0)
	if t == "HDMI":
		return pc.spec("GPU").get("hdmi", 1) if pc.has("GPU") else (1 if pc.igpu() else 0)
	if t == "USB":
		return pc.spec("MB")["usb"] if pc.has("MB") else 0
	return 2


static func port_pos(t: String, i: int) -> Vector2:
	return Vector2(PORT_X0 + (SLOT_OFFSET[t] + i) * PORT_GAP, PORT_Y)


## 배선 화면의 기기 자리: 책상 위 왼쪽 → 오른쪽 순서 그대로, 고르게 펼침 (같은 x에 겹친 모니터 · 키보드도 안 겹치게)
static func plug_pos(p: Dictionary, placed: Array) -> Vector2:
	var devs := placed.filter(needs_cable)
	devs.sort_custom(func(a, b): return center_x(a) < center_x(b) or (center_x(a) == center_x(b) and a.get("z", 0) < b.get("z", 0)))
	var gap: float = min(145.0, 980.0 / max(devs.size(), 1))
	return Vector2(640 - gap * devs.size() / 2.0 + gap * (devs.find(p) + 0.5), PLUG_Y)


static func port_at(x: float, y: float, pc: PCBuild):
	for t in PORT_ORDER:
		for i in port_count(t, pc):
			var pp := port_pos(t, i)
			if abs(x - pp.x) <= 30 and abs(y - pp.y) <= 22:
				return [t, i]
	return null


## 한 번에 꽂기: 안 꽂힌 기기를 놓은 순서대로 남는 포트에. 순서가 엇갈리면 꼬일 수 있음 → 정리는 손으로 (보너스)
static func auto_plug(cables: Array, placed: Array, pc: PCBuild) -> Array:
	var out := cables.duplicate()
	for p in placed.filter(needs_cable):
		if out.any(func(c): return is_same(c["dev"], p)):
			continue
		var need: String = DB.ITEMS[p["id"]]["port"]
		for t in (["HDMI", "DP"] if need in ["HDMI", "DP"] else [need]):
			var free := range(port_count(t, pc)).filter(func(i): return not out.any(func(c): return c["type"] == t and c["port"] == i))
			if not free.is_empty():
				out.append({"dev": p, "type": t, "port": free[0]})
				break
	return out


static func needs_cable(p: Dictionary) -> bool:
	return DB.ITEMS[p["id"]].has("port")


static func is_dongle(c: Dictionary) -> bool:
	return DB.ITEMS[c["dev"]["id"]].get("dongle", false)


## 사라진 기기 · 없어진 포트(그래픽카드 교체 등)에 꽂힌 선은 뽑는다.
static func prune(cables: Array, placed: Array, pc: PCBuild) -> Array:
	return cables.filter(func(c): return placed.any(func(p): return is_same(p, c["dev"])) and c["port"] < port_count(c["type"], pc))


static func _orient(p: Vector2, q: Vector2, r: Vector2) -> float:
	return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)


static func crossings(cables: Array, placed: Array) -> int:
	var segs := []
	for c in cables:
		if not is_dongle(c):  # 동글은 선이 없어 안 꼬인다
			segs.append([plug_pos(c["dev"], placed), port_pos(c["type"], c["port"])])
	var n := 0
	for i in segs.size():
		for j in range(i + 1, segs.size()):
			var a: Vector2 = segs[i][0]
			var b: Vector2 = segs[i][1]
			var c2: Vector2 = segs[j][0]
			var d: Vector2 = segs[j][1]
			if _orient(a, b, c2) * _orient(a, b, d) < 0 and _orient(c2, d, a) * _orient(c2, d, b) < 0:
				n += 1
	return n


## [점수(10점 만점), 미연결 수, 꼬임 수]
static func wiring_score(cables: Array, placed: Array) -> Array:
	var devices := placed.filter(needs_cable)
	if devices.is_empty():
		return [10.0, 0, 0]
	var connected := devices.filter(func(p): return cables.any(func(c): return is_same(c["dev"], p))).size()
	var x := crossings(cables, placed)
	return [max(0.0, 10.0 * connected / devices.size() - 2 * x), devices.size() - connected, x]


# ---------- 채점 ----------
## 손님 만족도: 테마 25 + 필수/금지 25 + PC 성능 20 + 시너지 15 + 배선 15. 예산은 점수가 아니라 가게 마진.
const MAX := {"테마 일치": 25, "필수 · 금지": 25, "PC 성능": 20, "조합 시너지": 15, "배선": 15, "증상 해결": 50, "성능": 50}
const LINES := {
	"테마 일치": "음… 제가 말한 분위기랑은 좀 달라요.",
	"필수 · 금지": "부탁드린 게 빠졌거나, 싫다는 게 들어갔어요.",
	"PC 성능": "켜지긴 하는데 좀 느리네요…",
	"조합 시너지": "하나하나는 좋은데, 어울림이 아쉬워요.",
	"배선": "선이 너무 엉켜 있어요… 정리 좀 해 주세요.",
	"증상 해결": "어… 아직 그대로인데요?",
	"성능": "고쳐지긴 했는데 좀 아쉬워요.",
	"조립 마감": "나사가 덜 조여졌는지 덜컹거려요…",
	"모니터": "모니터가 PC 성능을 못 따라가요. 화면이 아쉬워요.",
	"배치": "물건은 좋은데… 쓰기 불편하게 놓였어요.",
	"목표 달성": "바꿨는데도 아직 버벅여요…",
	"아낀 돈": "좋아지긴 했는데… 생각보다 돈이 많이 들었네요.",
}


## 특이 조건 (둘째 날부터 몇몇 의뢰에): 놓는 방식 자체를 바꾸게 만드는 퍼즐 같은 요청
static func twist_ok(t: Dictionary, placed: Array) -> bool:
	var desk := placed.filter(func(p): return p["layer"] == "desk" and not is_mounted(p))
	match t["kind"]:
		"few":   # 좁은 책상: 책상 위 물건 n개까지
			return desk.size() <= t["n"]
		"left":   # 왼손잡이: 마우스가 키보드 왼쪽
			var kbs := desk.filter(func(p): return p["id"] in KEYBOARDS)
			var ms := desk.filter(func(p): return p["id"] in MICE)
			return not kbs.is_empty() and not ms.is_empty() and ms.all(func(m): return kbs.any(func(k): return center_x(m) < center_x(k)))
		"dual":   # 모니터 두 대
			return placed.filter(func(p): return is_monitor(p["id"])).size() >= 2
	return true


## 배치 0~1: 놓는 건 자유, 쓰기 편하게 놓았는지만 본다 (해당하는 것만 평균).
## 모니터는 벽 쪽 · 키보드는 모니터 바로 앞 · 마우스는 키보드 옆 · 책상 위 물건이 한쪽에 몰리지 않게
const KEYBOARDS := ["keyboard", "gaming_kb", "kb_white", "kb_mini"]
const MICE := ["mouse_gaming", "mouse_vertical"]
static func layout_score(placed: Array) -> float:
	var desk := placed.filter(func(p): return p["layer"] == "desk" and not is_mounted(p))
	if desk.is_empty():
		return 0.0
	var checks := []
	var mons := desk.filter(func(p): return is_monitor(p["id"]))
	for mon in mons:
		checks.append(1.0 if mon.get("z", 0) <= DESK_DEPTH * 0.4 else 0.0)
	for kb in desk.filter(func(p): return p["id"] in KEYBOARDS):
		checks.append(1.0 if mons.any(func(mon): return absf(center_x(kb) - center_x(mon)) <= 70 and kb.get("z", 0) > mon.get("z", 0)) else 0.0)
	for ms in desk.filter(func(p): return p["id"] in MICE):
		checks.append(1.0 if desk.any(func(kb): return kb["id"] in KEYBOARDS and adjacent(ms, kb, 60) and absf(ms.get("z", 0) - kb.get("z", 0)) <= 100) else 0.0)
	if desk.size() >= 3:   # 좌우 균형: 무게중심이 책상 가운데 1/4 안쪽이면 만점
		var mid := (AREA_X1 + AREA_X2) / 2.0
		var cx: float = desk.map(func(p): return center_x(p)).reduce(func(a, b): return a + b, 0.0) / desk.size()
		checks.append(clampf(1.0 - (absf(cx - mid) - (AREA_X2 - AREA_X1) / 8.0) / ((AREA_X2 - AREA_X1) / 4.0), 0.0, 1.0))
	return 1.0 if checks.is_empty() else checks.reduce(func(a, b): return a + b, 0.0) / checks.size()


static func synergies(placed: Array, pc: PCBuild) -> Array:
	var ids := placed.map(func(p): return p["id"])
	var tags := []
	for i in ids:
		tags += DB.ITEMS[i]["tags"]
	var pc_case = pc.parts.get("CASE", "")
	var found := []
	var lamps := placed.filter(func(p): return p["id"] in ["lamp_warm", "lamp_cool"])
	var books := placed.filter(func(p): return p["id"] == "book")
	if lamps.any(func(l): return books.any(func(b): return adjacent(l, b))):
		found.append("독서 콤보")
	var colors := placed.map(func(p): return p.get("color", 0)).filter(func(c): return c > 0)
	if colors.any(func(c): return colors.count(c) >= 3):
		found.append("톤 온 톤")   # 색을 바꾼 소품 3개를 같은 색으로
	if tags.count("plant") >= 3:
		found.append("플랜테리어")
	if pc_case == "case3" and "rgb_bar" in ids and "gaming_kb" in ids:
		found.append("풀 RGB 셋업")
	if pc_case == "case2" and tags.count("minimal") >= 3:
		found.append("화이트 셋업")
	var on_desk := placed.filter(func(p): return p["layer"] == "desk").size()
	if on_desk >= 1 and on_desk <= 3:
		found.append("미니멀리즘")
	if "wall_light" in ids and not lamps.is_empty():
		found.append("균형 조명")
	var mons := placed.filter(func(p): return is_monitor(p["id"]))
	if not mons.is_empty() and mons.all(func(h): return placed.any(func(a): return mount_of(a["id"]) == "arm" and is_same(a.get("host"), h))):
		found.append("모니터 암 정리")
	if "headphone_stand" in ids and ("headphones" in ids or "headset" in ids):
		found.append("헤드폰 정리")
	if "stream_deck" in ids and ("mic" in ids or "mic_desk" in ids) and ("webcam" in ids or "acoustic" in ids):
		found.append("방송 세트")
	return found


static func _hits(tags: Array, theme: Array) -> bool:
	return tags.any(func(t): return t in theme)


static func score(req: Dictionary, placed: Array, pc: PCBuild, cables: Array) -> Dictionary:
	var ids := placed.map(func(p): return p["id"])
	var objects := ids.map(func(i): return DB.ITEMS[i]["tags"])
	if pc.has("CASE"):
		objects.append(pc.spec("CASE")["tags"])
	var theme_s := 0.0
	if not objects.is_empty():
		theme_s = 25.0 * objects.filter(func(t): return _hits(t, req["theme"])).size() / objects.size()

	var req_s := 25.0
	var n_req: int = req["required"].size() + (1 if req.has("twist") else 0)   # 특이 조건도 '꼭 필요' 하나로 침
	if n_req > 0:
		var met := 0.0
		for r in req["required"]:
			var have := 0
			for i in r["any"]:
				have += ids.count(i)
			if "monitor" in r["any"]:   # '모니터'는 어떤 모니터든
				have = ids.filter(is_monitor).size()
			met += min(1.0, float(have) / r["count"])
		if req.has("twist"):
			met += 1.0 if twist_ok(req["twist"], placed) else 0.0
		req_s = 25.0 * met / n_req
	for f in req["forbidden"]:
		req_s -= 12.5 * ids.count(f)
	req_s = max(0.0, req_s)
	var used_bad: bool = req.get("used", "") == "new" and pc.used.values().any(func(e): return e["paid"] > 0)   # '새 제품만' 손님인데 중고를 넣음
	if used_bad:
		req_s = 0.0

	var post := pc.post()
	var boot: String = "ok" if post[0] == 4 else post[1]
	if boot == "ok" and "GPU" in pc.loose():   # 고정 나사 없이 배송하면 덜컹
		boot = "배송 중에 그래픽카드가 빠졌어요 (고정 나사)"
	var pc_s: float = 0.0
	if boot == "ok":   # 손님 용도(FPS · 렌더 · 빌드 · 조용함) 목표 달성률
		pc_s = Bench.run(Bench.parts_of(pc), req["use"])["points"] if req.has("use") else max(0.0, 20.0 - 8 * max(0, req["perf"] - pc.stars()))
	var syn := synergies(placed, pc)
	var wire := wiring_score(cables, placed)

	if req.has("repair"):   # 수리: 증상이 사라졌는지(성능 테스트 통과) + 성능만 본다
		var b := Bench.run(Bench.parts_of(pc), req["use"]) if boot == "ok" else {"ok": false}
		var rp := {"증상 해결": 50.0 if b["ok"] and pc.faults.is_empty() and pc.picture() else 0.0, "성능": pc_s * 2.5}
		return _total(rp, {"증상 해결": 50, "성능": 50}, [], boot, 0)
	if req.has("upgrade"):   # 업그레이드: 목표 달성 60 + 아낀 돈 40 (목표를 넘겨야 아낀 돈도 인정) → 다 갈아엎기보다 딱 필요한 것만
		var ub := Bench.run(Bench.parts_of(pc), req["use"]) if boot == "ok" else {"ok": false}
		var save: float = clampf(1.0 - float(Game.spent()) / req["budget"], 0.0, 1.0) if ub["ok"] else 0.0
		return _total({"목표 달성": 60.0 if ub["ok"] else pc_s * 2.0, "아낀 돈": 40.0 * save}, {"목표 달성": 60, "아낀 돈": 40}, [], boot, 0)
	if req.get("type") == "pc":   # PC 조립만 (본체만): 성능 + 조립 마감(나사)만 본다
		var fin1 := 1.0 if pc.loose().is_empty() and pc.has("CASE") else 0.0
		var pr := _total({"PC 성능": pc_s / 20.0 * 70.0, "조립 마감": fin1 * 30.0}, {"PC 성능": 70, "조립 마감": 30}, [], boot, 0)
		if used_bad and boot == "ok":
			pr["line"] = "새 제품만 부탁드렸는데… 중고 부품이 들어갔네요."
		return pr
	# PC + 데스크 의뢰: PC도 맞추고 책상도 꾸밈 (성능 · 분위기 · 소품 · 모니터 · 배선)
	var fin := 1.0 if pc.loose().is_empty() and pc.has("CASE") else 0.0   # 나사를 다 조였는지
	var fr := {"PC 성능": pc_s / 20.0, "조립 마감": fin, "모니터": screen_fit(placed, req.get("use", {})), "필수 · 금지": req_s / 25.0,
		"테마 일치": theme_s / 25.0, "조합 시너지": minf(1.0, syn.size() / 2.0), "배치": layout_score(placed)}
	var w := {"PC 성능": 30, "조립 마감": 5, "모니터": 10, "테마 일치": 15, "필수 · 금지": 15, "조합 시너지": 10, "배치": 15}
	var pp := {}
	for k in w:
		pp[k] = fr[k] * w[k]
	var res := _total(pp, w, syn, boot, wire[1])
	if used_bad and boot == "ok":
		res["line"] = "새 제품만 부탁드렸는데… 중고 부품이 들어갔네요."
	return res


static func _total(parts: Dictionary, mx: Dictionary, syn: Array, boot: String, unplugged: int) -> Dictionary:
	var total := 0.0
	for k in parts:
		total += parts[k]
	var t := int(round(total))
	return {"parts": parts, "max": mx, "total": t, "stars": 3 if t >= 90 else 2 if t >= 75 else 1 if t >= 60 else 0,
		"synergies": syn, "boot": boot, "line": _reaction(parts, mx, boot, unplugged)}


## 의뢰 종류: repair(고장 수리) · pc(PC 조립만) · upgrade(업그레이드) · full(PC 조립 + 데스크테리어)
static func kind_of(req: Dictionary) -> String:
	return "repair" if req.has("repair") else req["type"] if req.get("type") in ["pc", "upgrade"] else "full"


const RES_RANK := {"1080p": 0, "1440p": 1, "UW1440": 1, "4K": 2}


## 책상 위 화면(모니터 · 노트북) 중 가장 좋은 [Hz, 해상도 등급]. 없으면 [0, -1]
static func best_screen(placed: Array) -> Array:
	var hz := 0
	var rk := -1
	for p in placed:
		var it: Dictionary = DB.ITEMS[p["id"]]
		if it.has("hz"):
			hz = maxi(hz, it["hz"])
			rk = maxi(rk, RES_RANK.get(it.get("res", "1080p"), 0))
	return [hz, rk]


## 모니터가 손님 용도에 맞는지 0~1: 게임은 목표 fps만큼 Hz가 나와야 보이고, 해상도도 맞아야 함
static func screen_fit(placed: Array, use: Dictionary) -> float:
	var b := best_screen(placed)
	if b[0] == 0:
		return 0.0
	var f := 1.0
	if use.get("kind", "") == "game":
		if b[0] < use["fps"]:
			f *= 0.4
		if b[1] < RES_RANK.get(use["res"], 0):
			f *= 0.6
	elif use.get("kind", "") == "render" and b[1] < 1:
		f *= 0.8
	return f


static func _reaction(parts: Dictionary, mx: Dictionary, boot: String, unplugged: int) -> String:
	if boot != "ok":
		return "PC가 안 켜져요… (%s)" % boot
	if unplugged > 0:
		return "기기 %d개가 안 켜져요. 케이블이 안 꽂혀 있어요!" % unplugged
	var worst: String = parts.keys()[0]
	for k in parts:
		if parts[k] / mx[k] < parts[worst] / mx[worst]:
			worst = k
	return "상상한 그대로예요! 단골 할게요." if parts[worst] / mx[worst] >= 0.8 else LINES[worst]
