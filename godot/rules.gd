class_name Rules
## 배치(room.py) · 배선(cables.py) · 채점(scorer.py) 규칙 이식. 좌표는 pico2d와 같은 1280x720, y가 위로 커지는 좌표.
## 놓인 소품 p = {"id", "layer", "x", "y", "color"?} · 케이블 c = {"dev": p, "type", "port"} · 사각형 = [x1, y1, x2, y2]

# ---------- 배치 ----------
const AREA_X1 := 300
const AREA_X2 := 1070      # 오른쪽은 PC 자리
const DESK_Y := 210        # 책상 상판 높이
const WALL_Y1 := 400
const WALL_Y2 := 640
const SLOT_X0 := 300
const SLOT_W := 110
const COLORS := 4
const UNIT := 5.5          # 책상 좌표 1cm. 책상 = 770 x 380 = 140 x 69cm
const DESK_DEPTH := 380   # 책상 앞뒤 깊이 (탑뷰). z = 0이 벽쪽, 클수록 앞
const Z_STEP := 10
const LAYER_NAMES := {"wall": "벽", "desk": "책상 위"}


static func inside(x: float, y: float, r: Array) -> bool:
	return r[0] <= x and x <= r[2] and r[1] <= y and y <= r[3]


static func rect_of(p: Dictionary) -> Array:
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
		if is_same(p, ignore) or p["layer"] != layer:
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
	for want in ["desk", "wall"]:  # 앞에 있는 책상 소품 먼저
		for p in placed:
			if p["layer"] == want and inside(x, y, rect_of(p)):
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


# ---------- 배선 ----------
const MAX_PORTS := {"DP": 3, "USB": 6, "AUDIO": 2}
const PORT_COLOR := {"DP": Color8(255, 77, 141), "USB": Color8(46, 230, 214), "AUDIO": Color8(255, 214, 92)}
const PORT_NAMES := {"DP": "DP", "USB": "USB", "AUDIO": "오디오"}
const PORT_ORDER := ["DP", "USB", "AUDIO"]   # 포트는 한 줄: 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다
const PORT_Y := 170
const PORT_X0 := 200
const PORT_GAP := 88
const SLOT_OFFSET := {"DP": 0, "USB": 3, "AUDIO": 9}
const PORT_PANEL := [150, 114, 1130, 214]
const PLUG_Y := 405


## DP는 그래픽카드, USB는 메인보드가 개수를 정한다.
static func port_count(t: String, pc: PCBuild) -> int:
	if t == "DP":
		return pc.spec("GPU")["dp"] if pc.has("GPU") else 0
	if t == "USB":
		return pc.spec("MB")["usb"] if pc.has("MB") else 0
	return 2


static func port_pos(t: String, i: int) -> Vector2:
	return Vector2(PORT_X0 + (SLOT_OFFSET[t] + i) * PORT_GAP, PORT_Y)


static func plug_pos(p: Dictionary) -> Vector2:
	var r := rect_of(p)
	return Vector2(150 + ((r[0] + r[2]) / 2.0 - SLOT_X0) / SLOT_W * 145, PLUG_Y)


static func port_at(x: float, y: float, pc: PCBuild):
	for t in PORT_ORDER:
		for i in port_count(t, pc):
			var pp := port_pos(t, i)
			if abs(x - pp.x) <= 30 and abs(y - pp.y) <= 22:
				return [t, i]
	return null


static func needs_cable(p: Dictionary) -> bool:
	return DB.ITEMS[p["id"]].has("port")


static func is_dongle(c: Dictionary) -> bool:
	return DB.ITEMS[c["dev"]["id"]].get("dongle", false)


## 사라진 기기 · 없어진 포트(그래픽카드 교체 등)에 꽂힌 선은 뽑는다.
static func prune(cables: Array, placed: Array, pc: PCBuild) -> Array:
	return cables.filter(func(c): return placed.any(func(p): return is_same(p, c["dev"])) and c["port"] < port_count(c["type"], pc))


static func _orient(p: Vector2, q: Vector2, r: Vector2) -> float:
	return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)


static func crossings(cables: Array) -> int:
	var segs := []
	for c in cables:
		if not is_dongle(c):  # 동글은 선이 없어 안 꼬인다
			segs.append([plug_pos(c["dev"]), port_pos(c["type"], c["port"])])
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
	var x := crossings(cables)
	return [max(0.0, 10.0 * connected / devices.size() - 2 * x), devices.size() - connected, x]


# ---------- 채점 ----------
## 손님 만족도: 테마 25 + 필수/금지 25 + PC 성능 20 + 시너지 15 + 배선 15. 예산은 점수가 아니라 가게 마진.
const MAX := {"테마 일치": 25, "필수 · 금지": 25, "PC 성능": 20, "조합 시너지": 15, "배선": 15}
const LINES := {
	"테마 일치": "음… 제가 말한 분위기랑은 좀 달라요.",
	"필수 · 금지": "부탁드린 게 빠졌거나, 싫다는 게 들어갔어요.",
	"PC 성능": "켜지긴 하는데 좀 느리네요…",
	"조합 시너지": "하나하나는 좋은데, 어울림이 아쉬워요.",
	"배선": "선이 너무 엉켜 있어요… 정리 좀 해 주세요.",
}


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
	if not req["required"].is_empty():
		var met := 0.0
		for r in req["required"]:
			var have := 0
			for i in r["any"]:
				have += ids.count(i)
			met += min(1.0, float(have) / r["count"])
		req_s = 25.0 * met / req["required"].size()
	for f in req["forbidden"]:
		req_s -= 12.5 * ids.count(f)
	req_s = max(0.0, req_s)

	var post := pc.post()
	var boot: String = "ok" if post[0] == 4 else post[1]
	var pc_s: float = 0.0 if boot != "ok" else max(0.0, 20.0 - 8 * max(0, req["perf"] - pc.stars()))
	var syn := synergies(placed, pc)
	var wire := wiring_score(cables, placed)

	var parts := {"테마 일치": theme_s, "필수 · 금지": req_s, "PC 성능": pc_s, "조합 시너지": min(15.0, 8.0 * syn.size()), "배선": wire[0] * 1.5}
	var total := 0.0
	for k in parts:
		total += parts[k]
	var t := int(round(total))
	return {"parts": parts, "total": t, "stars": 3 if t >= 90 else 2 if t >= 75 else 1 if t >= 60 else 0,
		"synergies": syn, "boot": boot, "line": _reaction(parts, boot, wire[1])}


static func _reaction(parts: Dictionary, boot: String, unplugged: int) -> String:
	if boot != "ok":
		return "PC가 안 켜져요… (%s)" % boot
	if unplugged > 0:
		return "기기 %d개가 안 켜져요. 케이블이 안 꽂혀 있어요!" % unplugged
	var worst: String = parts.keys()[0]
	for k in parts:
		if parts[k] / MAX[k] < parts[worst] / MAX[worst]:
			worst = k
	return "상상한 그대로예요! 단골 할게요." if parts[worst] / MAX[worst] >= 0.8 else LINES[worst]
