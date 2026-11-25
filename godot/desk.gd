extends Mode
## 책상 꾸미기: 창고 재고에서 끌어다 놓는다. 정면 뷰(벽 · 책상 위) ⇄ 탑뷰(책상을 위에서 크게, 앞뒤까지).
## 누르기 = 선택(색 바꾸기), 두 번 누르기(우클릭) = 창고로.

const SHOP_W := 270
const ROW_H := 31
const ROW_TOP := 600
const ROOM := [270, 0, 1280, 650]
const PC_RECT := [1076, 210, 1272, 420]   # 책상 오른쪽 PC (유리 옆판이 보이는 옆모습)
const BTN_POWER := [1238, 384, 1264, 410]
const CASE_BODY := {"case1": Color8(42, 35, 80), "case2": Color8(232, 230, 242), "case3": Color8(20, 16, 42), "case4": Color8(232, 230, 242), "case5": Color8(42, 35, 80)}
## 모니터 그림 속 화면 위치 [x1, y1, x2, y2, 그림 너비, 그림 높이] (위에서부터, 원래 그림 기준)
const SCREEN := {"monitor_22": [6, 6, 184, 110, 190, 172], "monitor_144": [6, 6, 202, 120, 208, 182], "monitor_240": [6, 6, 210, 124, 216, 190], "monitor_qhd165": [6, 6, 228, 134, 234, 196], "monitor_4k": [6, 6, 270, 156, 276, 222], "monitor_oled": [6, 6, 228, 134, 234, 212], "monitor_pivot": [6, 6, 104, 196, 110, 258], "monitor_portable": [6, 6, 134, 84, 140, 114], "monitor": [6, 6, 202, 116, 208, 176], "monitor_27": [6, 6, 202, 116, 208, 176], "monitor_white": [6, 6, 202, 116, 208, 176], "monitor_curve": [10, 16, 308, 112, 318, 176]}
const BTN_DONE := [1100, 10, 1270, 50]
const BTN_VIEW := [920, 10, 1090, 50]
const BTN_PHOTO := [800, 10, 910, 50]
const PER := 16
const BTN_PREV := [14, 66, 64, 96]
const BTN_NEXT := [206, 66, 256, 96]
# 탑뷰: 책상 x 300~1070 · 앞뒤 0~DESK_DEPTH 를 K배로 크게
const K := 1.2
const TOP_BACK := 590.0   # 책상 뒤쪽(벽) 가장자리 화면 높이

var top_view := false
var capturing := false   # 사진 찍는 프레임: 선택 표시 · 버튼 없이 방만
var held := ""       # 끌고 있는 소품 id
var moving = null    # 책상에서 집어 든 소품 (실패하면 제자리 그대로)
var origin := Vector2.ZERO
var selected = null
var toast := ""
var page := 0
var fail_t := -100000   # 전원이 안 켜졌을 때 LED 깜빡임


func enter() -> void:
	held = ""
	moving = null
	selected = null
	toast = ""


func art(p: Dictionary) -> String:
	return p["id"] + ("__c%d" % p["color"] if p.get("color", 0) else "")


## 위에서 본 그림 (top_<id>). 아직 없으면 ""
func top_art(name: String) -> String:
	return "top_" + name if ResourceLoader.exists("res://resource/top_%s.png" % name) else ""


func all_ids() -> Array:
	return DB.ITEMS.keys().filter(func(i): return Game.stock.get(i, 0) > 0 or (i == held and moving == null))


func rows() -> Array:
	return all_ids().slice(page * PER, (page + 1) * PER)


func row_rect(i: int) -> Array:
	var y := ROW_TOP - i * ROW_H
	return [10, y - ROW_H + 4, SHOP_W - 10, y]


# ---------- 탑뷰 좌표 ----------
func top_rect(id: String, x: float, z: float) -> Array:
	var f := Rules.foot_x(id, x)
	var sx: float = Rules.AREA_X1 + (f.x - Rules.AREA_X1) * K
	return [sx, TOP_BACK - (z + Rules.depth_of(id)) * K, sx + (f.y - f.x) * K, TOP_BACK - z * K]


func desk_rect() -> Array:
	return [Rules.AREA_X1 - 8, TOP_BACK - Rules.DESK_DEPTH * K - 8, Rules.AREA_X1 + (Rules.AREA_X2 - Rules.AREA_X1) * K + 8, TOP_BACK + 8]


## 지금 뷰에서 소품이 차지하는 화면 영역 (탑뷰에선 벽 장식이 안 보여서 [])
func shown_rect(p: Dictionary) -> Array:
	if not top_view:
		return Rules.rect_of(p)
	return top_rect(p["id"], p["x"], p.get("z", 0)) if p["layer"] == "desk" else []


## 그리는 순서 · 누르는 순서: 뒤(z 작은 것) → 앞, 같은 깊이면 모니터에 붙은 소품이 위
func depth_key(p: Dictionary) -> float:
	return p.get("z", 0) + (0.5 if Rules.is_mounted(p) else 0.0)


func hit(x: float, y: float):
	if not top_view:
		return Rules.item_at(Game.placed, x, y)
	var best = null   # 겹치면 앞에 있는 것(z 큰 것)
	for p in Game.placed:
		var r := shown_rect(p)
		if not r.is_empty() and inside(x, y, r) and (best == null or depth_key(p) > depth_key(best)):
			best = p
	return best


## 놓일 자리 {layer, x, y, z, ok}. 근처가 아니면 {}.
## 놓일 자리 {id, layer, x, y, z, ok, why?, host?, slot?}. 근처가 아니면 {}.
## 책상 위 소품은 자석처럼 제자리(짝 소품 옆 · 앞뒤 구역)로 끌려간다. 붙는 소품은 붙을 곳에만.
func target(id: String, x: float, y: float) -> Dictionary:
	var layer: String = DB.ITEMS[id]["layer"]
	if Rules.is_mounted({"id": id}):
		return mount_target(id, x, y)
	var keep: int = moving.get("z", 0) if moving != null else -1
	var s := DB.size_of(id)
	var bx: int
	var z := -1
	if top_view:
		if layer != "desk" or not inside(x, y, grow(desk_rect(), 40)):
			return {}
		var d := Rules.depth_of(id)
		var w: float = max(s.x, Rules.foot_of(id).x)
		bx = int(clamp(Rules.AREA_X1 + (x - Rules.AREA_X1) / K, Rules.AREA_X1 + w / 2.0, Rules.AREA_X2 - w / 2.0) - s.x / 2.0)
		z = int(clamp(snappedf((TOP_BACK - y) / K - d / 2.0, Rules.Z_STEP), 0, Rules.DESK_DEPTH - d))
	else:
		var t = Rules.drop_target(id, x, y)
		if t == null:
			return {}
		if layer == "wall":
			return {"id": id, "layer": layer, "x": t[1], "y": t[2], "z": 0, "ok": Rules.fits_at(Game.placed, id, layer, t[1], t[2], moving)}
		bx = t[1]
	for c in Rules.magnet(Game.placed, id, bx, z, moving):
		if Rules.fits_at(Game.placed, id, "desk", c[0], Rules.DESK_Y, moving, c[1]):
			return {"id": id, "layer": layer, "x": c[0], "y": Rules.DESK_Y, "z": c[1], "ok": true}
	if not top_view:   # 정면: 그 x에서 비어 있는 앞뒤 자리
		var fz := Rules.free_z(Game.placed, id, bx, moving, keep)
		if fz >= 0:
			return {"id": id, "layer": layer, "x": bx, "y": Rules.DESK_Y, "z": fz, "ok": true}
	var zone: String = DB.ITEMS[id].get("zone", "")
	for strict in [true, false]:   # 그 자리가 꽉 찼으면 가장 가까운 빈자리: 먼저 제 구역(뒤 · 앞) 안에서, 없으면 아무 데나
		for dx in range(10, 800, 10):
			for nx in [bx - dx, bx + dx]:
				var nz := Rules.free_z(Game.placed, id, nx, moving, z if z >= 0 else keep)
				var in_zone: bool = zone == "" or (nz + Rules.depth_of(id) / 2.0 < Rules.DESK_DEPTH / 2.0) == (zone == "back")
				if nz >= 0 and (in_zone or not strict) and Rules.fits_at(Game.placed, id, "desk", nx, Rules.DESK_Y, moving, nz):
					return {"id": id, "layer": layer, "x": nx, "y": Rules.DESK_Y, "z": nz, "ok": true}
	return {"id": id, "layer": layer, "x": bx, "y": Rules.DESK_Y, "z": max(z, 0), "ok": false,
		"why": "책상에 %s을(를) 놓을 자리가 없어요. 다른 소품을 치우거나 옮겨 주세요" % DB.ITEMS[id]["name"]}


## 붙는 소품: 모니터 윗면 / 책상 앞 가장자리 걸이 / 책상 뒤 가장자리 집게
func mount_target(id: String, x: float, y: float) -> Dictionary:
	var s := DB.size_of(id)
	var t := {"id": id, "layer": "desk", "x": int(x - s.x / 2.0), "y": Rules.DESK_Y, "z": 0, "ok": false}
	if Rules.mount_of(id) in ["monitor", "arm"]:
		var best = null
		var bd := 260.0
		for h in Game.placed:
			if Rules.is_monitor(h["id"]) and not shown_rect(h).is_empty():
				var dist := Vector2(x, y).distance_to(center(shown_rect(h)))
				if dist < bd:
					best = h
					bd = dist
		if best == null:
			t["why"] = "%s은(는) 모니터 위에 끼워요. 모니터 근처에 놓아 주세요" % DB.ITEMS[id]["name"]
			return t
		if Rules.mount_of(id) == "arm":   # 모니터 암: 한 모니터에 하나, 무게(인치) 한계
			if Rules.mounts_on(Game.placed, best).any(func(q): return Rules.mount_of(q["id"]) == "arm" and not is_same(q, moving)):
				t["why"] = "이 모니터엔 이미 모니터 암이 있어요"
				return t
			if DB.ITEMS[best["id"]].get("inch", 24) > DB.ITEMS[id]["max_inch"]:
				t["why"] = "%d인치는 이 암이 못 버텨요 (%d인치까지)" % [DB.ITEMS[best["id"]]["inch"], DB.ITEMS[id]["max_inch"]]
				return t
			t["host"] = best
			t.erase("x")
			Rules.mount_pos(t)
			t["ok"] = true
			return t
		var slot := Rules.free_slot(Game.placed, best, moving)
		if slot < 0:
			t["why"] = "이 모니터 위엔 더 끼울 자리가 없어요"
			return t
		t["host"] = best
		t["slot"] = slot
		Rules.mount_pos(t)
		t["ok"] = true
		return t
	var near: bool = inside(x, y, grow(desk_rect(), 60)) if top_view else (y > 40 and y < Rules.DESK_Y + 260)
	if not near:
		return {}
	t["x"] = int(clamp(Rules.AREA_X1 + (x - Rules.AREA_X1) / K - s.x / 2.0 if top_view else x - s.x / 2.0, Rules.AREA_X1, Rules.AREA_X2 - s.x))
	Rules.mount_pos(t)
	t["ok"] = Rules.edge_fits(Game.placed, id, t["x"], moving)
	if not t["ok"]:
		t["why"] = "그 자리엔 이미 걸이 · 집게가 있어요"
	return t


func preview_rect(id: String, t: Dictionary) -> Array:
	if top_view:
		return top_rect(id, t["x"], t["z"])
	var s := DB.size_of(id)
	return [t["x"], t["y"], t["x"] + s.x, t["y"] + s.y]


func chip_rect(p: Dictionary, k: int) -> Array:
	var r := shown_rect(p)
	var x: float = (r[0] + r[2]) / 2.0 - Rules.COLORS * 20 + k * 40
	var y: float = min(r[3] + 8, 610)
	return [x, y, x + 36, y + 36]


# ---------- 입력 ----------
func down(x: float, y: float, right: bool) -> void:
	if inside(x, y, BTN_PREV) or inside(x, y, BTN_NEXT):
		var last: int = max(0, (all_ids().size() - 1) / PER)
		page = max(0, page - 1) if inside(x, y, BTN_PREV) else min(last, page + 1)
		return
	if tabs(x, y):
		return
	if inside(x, y, BTN_DONE):
		m.deliver()
		return
	if inside(x, y, BTN_PHOTO):
		take_photo()
		return
	if not top_view and inside(x, y, grow(BTN_POWER, 10)) and Game.pc.has("CASE"):
		press_power()
		return
	if inside(x, y, BTN_VIEW):
		top_view = not top_view
		selected = null
		toast = ""
		return
	if selected != null and DB.ITEMS[selected["id"]].get("tint", false) and not right and not shown_rect(selected).is_empty():
		for k in Rules.COLORS:
			if inside(x, y, chip_rect(selected, k)):
				selected["color"] = k
				sfx("click")
				return
	var p = hit(x, y)
	if right:
		if p != null:
			for q in Rules.mounts_on(Game.placed, p) + [p]:   # 모니터를 빼면 위에 끼운 것도 같이 창고로
				Game.placed.erase(q)
				Game.give_back(q["id"])
			selected = null
		return
	var ids := rows()
	for i in ids.size():
		if inside(x, y, row_rect(i)):
			if DB.ITEMS[ids[i]]["price"] > Game.money_left():
				toast = "손님 예산을 넘어요!"
				sfx("error")
			else:
				sfx("pick")
				held = ids[i]
				moving = null
				selected = null
				toast = ""
			return
	if p != null:
		held = p["id"]
		moving = p
		origin = Vector2(x, y)
	else:
		selected = null
		if not top_view and inside(x, y, PC_RECT):
			m.go("build")


## 케이스 전원 버튼: 부팅되면 켜지고(연결된 모니터가 켜짐), 안 되면 LED가 빨갛게 깜빡이며 이유를 알려 줌
func press_power() -> void:
	if Game.power:
		Game.power = false
		sfx("click")
		toast = "PC를 껐어요"
		return
	if not Game.pc.boots():
		fail_t = Time.get_ticks_msec()
		sfx("boot_fail")
		toast = "전원이 안 켜져요: " + Game.pc.post()[1]
		return
	Game.power = true
	Game.power_t = Time.get_ticks_msec()
	sfx("boot_ok")
	var shown := Game.placed.filter(func(q): return SCREEN.has(q["id"]) and dp_linked(q))
	toast = "" if not shown.is_empty() else "PC는 켜졌는데 모니터 선(HDMI · DP)이 안 꽂혔어요 (배선 탭)"


func dp_linked(p: Dictionary) -> bool:
	return Game.cables.any(func(c): return is_same(c["dev"], p) and c["type"] in ["DP", "HDMI", "USB"])   # 영상 선 (휴대용 모니터는 USB-C)


func take_photo() -> void:
	await m.photo(Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_").insert(0, "free_"))
	m.sfx("photo")
	toast = "사진을 찍었어요 (타이틀 → 앨범)"


func up(x: float, y: float) -> void:
	if held == "":
		return
	var id := held
	var mv = moving
	var t := target(id, x, y)
	held = ""
	moving = null
	if mv != null and abs(x - origin.x) + abs(y - origin.y) < 6:   # 움직이지 않은 누름 = 선택
		selected = null if is_same(selected, mv) else mv
		sfx("click")
		return
	var ok: bool = not t.is_empty() and t["ok"]
	sfx("place" if ok else "error")
	if mv != null:
		if ok:
			for k in ["x", "y", "z", "host", "slot"]:
				if t.has(k):
					mv[k] = t[k]
			toast = ""
		else:
			toast = t.get("why", "그 자리엔 못 놓아서 원래 자리에 뒀어요")
	elif ok and Game.take(id):
		selected = {}
		for k in ["id", "layer", "x", "y", "z", "host", "slot"]:
			if t.has(k):
				selected[k] = t[k]
		Game.placed.append(selected)
		toast = ""
	elif t.has("why"):
		toast = t["why"]
	elif top_view and DB.ITEMS[id]["layer"] == "wall":
		toast = "벽 장식은 정면 뷰에서 걸어 주세요"
	elif not t.is_empty() or inside(x, y, ROOM):
		toast = "%s은(는) '%s'의 빈 곳에 놓아 주세요" % [DB.ITEMS[id]["name"], Rules.LAYER_NAMES[DB.ITEMS[id]["layer"]]]


# ---------- 그리기 ----------
## 들고 있는 소품 (모니터를 들면 위에 끼운 것도 같이 들림)
func lifted(p: Dictionary) -> bool:
	return moving != null and (is_same(p, moving) or is_same(p.get("host"), moving))


func by_depth() -> Array:
	var desk := Game.placed.filter(func(p): return p["layer"] == "desk")
	desk.sort_custom(func(a, b): return depth_key(a) < depth_key(b))   # 벽쪽(뒤) 먼저, 앞이 위에
	return desk


func draw_front() -> void:
	spr("room_bg_" + Game.today()["weather"], 775, 325)
	for p in Game.placed.filter(func(p): return p["layer"] == "wall") + by_depth():
		if not lifted(p):
			if Rules.mount_of(p["id"]) == "arm":
				draw_arm(p, arm_target(p["host"]))
				continue
			if armed(p):   # 암에 달린 모니터는 받침대를 떼어 냄
				draw_without_stand(p)
			else:
				put(art(p), Rules.rect_of(p))
			if SCREEN.has(p["id"]):
				draw_screen(p)   # 앞에 놓인 소품이 화면을 가리도록 모니터 바로 다음에
	draw_pc()


## 모니터 암 ----------
func arm_of(h: Dictionary):
	for q in Game.placed:
		if Rules.mount_of(q["id"]) == "arm" and is_same(q.get("host"), h):
			return q
	return null


func armed(h: Dictionary) -> bool:
	return SCREEN.has(h["id"]) and arm_of(h) != null


## 받침대를 뺀 모니터 (그림 윗부분 = 화면 + 테두리만)
func draw_without_stand(p: Dictionary, r = null) -> void:
	if r == null:
		r = Rules.rect_of(p)
	var f: Array = SCREEN[p["id"]]
	var k: float = (f[3] + 8.0) / f[5]
	var t := DB.tex(art(p))
	m.draw_texture_rect_region(t, _rect([r[0], r[3] - (r[3] - r[1]) * k, r[2], r[3]]), Rect2(0, 0, t.get_width(), t.get_height() * k))


## 팔이 모니터 뒤 가운데를 잡는 점
func arm_target(h: Dictionary) -> Vector2:
	var r := Rules.rect_of(h)
	var f: Array = SCREEN.get(h["id"], [0, 0, 1, 1, 1, 1])
	return Vector2((r[0] + r[2]) / 2.0, r[3] - (r[3] - r[1]) * (f[3] * 0.5 / f[5]))


## 집게 → 기둥 → 관절 두 개 → 모니터. 모니터를 끌면 관절이 접혔다 펴지며 따라감
func draw_arm(a: Dictionary, target: Vector2) -> void:
	var gas: bool = a["id"] == "monitor_arm_gas"
	var c := Color8(154, 160, 180) if gas else Color8(42, 36, 64)
	var hi := Color8(232, 230, 242) if gas else Color8(90, 79, 160)
	var cx: float = a["x"]
	var base := Vector2(cx, Rules.DESK_Y)
	var top := Vector2(cx, Rules.DESK_Y + 64)
	box([cx - 16, Rules.DESK_Y - 16, cx + 16, Rules.DESK_Y + 6], c)   # 상판 뒤를 무는 집게
	box([cx - 10, Rules.DESK_Y - 24, cx - 4, Rules.DESK_Y - 16], c)
	line(base, top, c, 9)
	line(base + Vector2(-3, 0), top + Vector2(-3, 0), hi, 2)
	var reach := top.distance_to(target)
	var seg: float = maxf(reach / 2.0 + 4, 70.0)   # 팔 두 마디 길이 (모자라면 쭉 펴짐)
	var mid := (top + target) / 2.0
	var lift := sqrt(maxf(0.0, seg * seg - reach * reach / 4.0))
	var elbow := mid + Vector2(0, lift)
	line(top, elbow, c, 8)
	line(elbow, target, c, 7)
	if gas:
		line(top + Vector2(0, 10), elbow + Vector2(0, -6), hi, 2)   # 가스 스프링
	circle(top.x, top.y, 7, hi)
	circle(elbow.x, elbow.y, 6, hi)
	box([target.x - 12, target.y - 12, target.x + 12, target.y + 12], c)   # 모니터 뒤 VESA 판


## 조립한 PC: 유리 옆판 안에 조립 화면의 부품 배치를 그대로 줄여서 + 앞쪽 전원 버튼
func draw_pc() -> void:
	var pc := Game.pc
	var r := PC_RECT
	if not pc.has("CASE"):
		put("case_empty", r)
		text(r[0] + 30, r[3] + 18, "노트북 사용 중" if Game.computer() != pc else "PC 조립 필요", 16, CYAN)
		return
	var cid: String = pc.parts["CASE"]
	var t := Time.get_ticks_msec() / 1000.0
	var on: bool = Game.power
	# 유리창(그림 좌표 x 10~154, y 12~196) → 게임 좌표
	var g := [r[0] + 10, r[3] - 196, r[0] + 154, r[3] - 12]
	box(g, Color8(8, 6, 18))
	var b = m.modes["build"]
	var ca: Array = b.CASE_AREA
	var k: float = (g[3] - g[1] - 50.0) / (ca[3] - 200.0)   # 파워 칸(아래)을 뺀 부분을 덮개 위 공간에 꽉 (파워는 덮개 속, 오른쪽 넘친 곳은 앞판에 가려짐)
	m.draw_set_transform(Vector2(g[0] - ca[0] * k, (H - g[3]) - (H - ca[3]) * k), 0.0, Vector2(k, k))
	if pc.has("MB"):
		b.draw_board()
		b.draw_parts()
		b.draw_cables()
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var front_fans: bool = cid in ["case3", "case4", "case7"]
	for i in 3:   # 앞쪽 흡기 팬 3개 (켜지면 링이 빛남)
		if not front_fans:
			break
		var c := Vector2(g[2] - 12, g[3] - 34 - i * 40)
		circle(c.x, c.y, 15, Color8(20, 16, 34))
		var ring := Color.from_hsv(fmod(t * 0.15 + i * 0.12, 1.0), 0.75, 1.0) if on else Color8(70, 64, 96)
		m.draw_arc(Vector2(c.x, H - c.y), 13, 0, TAU, 24, ring, 3)
		if on:
			for q in 4:
				var a2 := t * 12.0 + q * TAU / 4
				line(c, c + Vector2(cos(a2), sin(a2)) * 10, Color(0.6, 0.6, 0.75, 0.6), 3)
	var shroud := [g[0], g[1], g[2], g[1] + 50]   # 파워 덮개 (아래 공간을 가려 깔끔하게)
	box(shroud, Color8(214, 212, 228) if cid in ["case2", "case4"] else Color8(26, 22, 44))
	box([shroud[0], shroud[3] - 3, shroud[2], shroud[3]], Color.from_hsv(fmod(t * 0.1, 1.0), 0.7, 1.0, 0.9) if on and cid in ["case3", "case7"] else Color8(60, 54, 90))
	if on:   # 켜지면 안쪽이 은은하게 물듦
		box(g, Color.from_hsv(fmod(t * 0.08, 1.0), 0.6, 1.0, 0.08))
	put("side_" + cid if ResourceLoader.exists("res://resource/side_%s.png" % cid) else "side_case1", r)
	poly([Vector2(g[0] + 8, g[3] - 6), Vector2(g[0] + 30, g[3] - 6), Vector2(g[0] + 80, g[1] + 6), Vector2(g[0] + 58, g[1] + 6)], Color(1, 1, 1, 0.06))   # 유리 반사
	var failing: bool = Time.get_ticks_msec() - fail_t < 1500
	var c2 := center(BTN_POWER)
	var led: Color = CYAN if on else (PINK if failing and int(t * 6) % 2 else (Color(GOLD, 0.5 + 0.5 * sin(t * 4)) if pc.boots() else Color8(70, 64, 96)))
	m.draw_arc(Vector2(c2.x, H - c2.y), 6, 0, TAU, 16, led, 2)
	if on:
		box([c2.x - 2, c2.y - 22, c2.x + 2, c2.y - 18], CYAN if fmod(t * 7, 2.0) < 1 else Color8(30, 60, 70))   # HDD 불빛


## 모니터 화면: 꺼짐 = 검정 / 켜짐 + DP 연결 = 부팅 로고 → 바탕화면 · 작업표시줄 · 창 / 켜졌는데 선 없음 = 신호 없음
func draw_screen(p: Dictionary) -> void:
	var f: Array = SCREEN[p["id"]]
	var r := Rules.rect_of(p)
	var w: float = r[2] - r[0]
	var h: float = r[3] - r[1]
	var fw := float(f[4])   # 정수끼리 나누면 0이 되므로 실수로
	var fh := float(f[5])
	var s := [r[0] + f[0] / fw * w, r[3] - f[3] / fh * h, r[0] + f[2] / fw * w, r[3] - f[1] / fh * h]
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	box(s, Color8(6, 5, 12))
	if not Game.power and Game.computer() == Game.pc:   # 노트북에 연결된 모니터는 늘 켜짐
		line(Vector2(s[0] + sw * 0.55, s[3] - 2), Vector2(s[0] + sw * 0.75, s[1] + 2), Color(1, 1, 1, 0.05), sw * 0.08)   # 꺼진 화면 반사
		box([s[2] - 8, s[1] - 7, s[2] - 4, s[1] - 4], Color8(255, 150, 60))   # 대기 LED
		return
	if not dp_linked(p) or Game.pc.faults.has("monitor_mb"):
		box([s[0] + sw * 0.3, s[1] + sh * 0.4, s[0] + sw * 0.7, s[1] + sh * 0.6], Color8(30, 30, 60))
		text(s[0] + sw * 0.3 + 8, s[1] + sh * 0.5, "신호 없음", 16, QUIET)
		return
	var t := (Time.get_ticks_msec() - Game.power_t) / 1000.0
	var cx: float = s[0] + sw / 2.0
	var cy: float = s[1] + sh / 2.0
	if t < 1.6:   # 부팅 로고 + 돌아가는 점
		for q in 4:
			box([cx - 13 + (q % 2) * 14, cy + 4 - (q / 2) * 14, cx - 1 + (q % 2) * 14, cy + 16 - (q / 2) * 14], CYAN)
		for d in 6:
			var a := t * 6.0 + d * TAU / 6.0
			circle(cx + cos(a) * 9, cy - 24 + sin(a) * 9, 2.0 if d else 3.0, Color(1, 1, 1, 0.3 + d * 0.12))
		return
	m.draw_texture_rect(DB.tex("title_bg"), _rect(s), false)   # 바탕화면
	var th: float = max(10.0, sh * 0.1)
	box([s[0], s[1], s[2], s[1] + th], Color(0.05, 0.03, 0.12, 0.92))   # 작업표시줄
	var ic: float = th * 0.55
	var icons := [CYAN, PINK, GOLD, VIOLET]
	for i in icons.size():
		var x0: float = cx - icons.size() * ic * 0.75 + i * ic * 1.5
		box([x0, s[1] + (th - ic) / 2.0, x0 + ic, s[1] + (th + ic) / 2.0], icons[i])
	if th >= 16:
		text(s[2] - 54, s[1] + th / 2.0, Time.get_time_string_from_system().left(5), 16)
	for i in 3:   # 바탕화면 아이콘
		box([s[0] + 6, s[3] - 8 - (i + 1) * ic * 1.6, s[0] + 6 + ic, s[3] - 8 - (i + 1) * ic * 1.6 + ic], [CYAN, GOLD, PINK][i])
	var win := [s[0] + sw * 0.24, s[1] + th + sh * 0.12, s[0] + sw * 0.84, s[3] - sh * 0.1]   # 열린 창 = 손님 용도 앱 (게임은 실제 FPS로)
	draw_app(win, Bench.run(Bench.parts_of(Game.pc), Game.request().get("use", {"kind": "office"})), t, false)

func draw_top() -> void:
	box(ROOM, Color8(14, 9, 30))
	var d := desk_rect()
	box([d[0], d[3], d[2], 640], Color8(40, 28, 74))   # 벽
	text(d[0] + 12, 618, "벽 (벽 장식은 정면 뷰에서)", 16, DIM)
	frame("ui_panel", d)                               # 책상 상판
	for i in range(1, 4):                              # 상판 나뭇결 대신 네온 격자
		var gy: float = TOP_BACK - Rules.DESK_DEPTH * K * i / 4.0
		line(Vector2(d[0] + 12, gy), Vector2(d[2] - 12, gy), Color8(60, 46, 110), 1)
	box([d[0], d[1] - 4, d[2], d[1]], PINK)            # 앞쪽 가장자리 네온
	text(d[0] + 12, d[1] - 20, "앞 (손님 자리)", 16, DIM)
	for p in by_depth():
		if lifted(p):
			continue
		var r := shown_rect(p)
		if top_art(art(p)) != "":
			put(top_art(art(p)), r)
		else:   # ponytail: 위에서 본 그림이 아직 없는 소품은 정면 그림을 칸에 넣어 임시로
			frame("ui_slot", r)
			fit(art(p), (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, r[2] - r[0] - 6, r[3] - r[1] - 6)


func draw_room() -> void:
	if top_view:
		draw_top()
	else:
		draw_front()
	if held != "":   # 놓일 자리 미리 보기
		var t := target(held, m.mouse.x, m.mouse.y)
		if not t.is_empty():
			outline(preview_rect(held, t), CYAN if t["ok"] else PINK, 2)
	if capturing:
		return
	if selected != null and Game.placed.has(selected) and not shown_rect(selected).is_empty():
		outline(shown_rect(selected), GOLD, 2)
		if DB.ITEMS[selected["id"]].get("tint", false):
			for k in Rules.COLORS:
				var r := chip_rect(selected, k)
				frame("ui_button", r, GOLD if selected.get("color", 0) == k else Color8(80, 66, 140))
				fit(selected["id"] + ("__c%d" % k if k else ""), (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0 + 2, 26, 26)
	if Time.get_ticks_msec() / 333 % 2:   # 케이블이 안 꽂힌 기기 위에 깜빡이는 점
		for p in Game.placed:
			if Rules.needs_cable(p) and not lifted(p) and not shown_rect(p).is_empty() and not Game.cables.any(func(c): return is_same(c["dev"], p)):
				var r := shown_rect(p)
				circle((r[0] + r[2]) / 2.0, r[1] + 8, 6, PINK)


func draw_stock() -> void:
	panel([-12, -12, SHOP_W, 650])
	text(14, ROW_TOP + 20, "창고 재고  (끌어서 배치)", 18)
	var ids := rows()
	if ids.is_empty():
		text(14, ROW_TOP - 20, "소품 재고가 없어요", 15, QUIET)
		text(14, ROW_TOP - 44, "쇼핑 탭에서 사 오세요", 13, DIM)
	var total := all_ids().size()
	if total > PER:
		button(BTN_PREV, "▲", VIOLET)
		button(BTN_NEXT, "▼", VIOLET)
		text(92, 81, "%d/%d" % [page + 1, (total - 1) / PER + 1], 13, QUIET)
	var left := Game.money_left()
	for i in ids.size():
		var it: Dictionary = DB.ITEMS[ids[i]]
		var r := row_rect(i)
		var cy: float = (r[1] + r[3]) / 2.0
		var dim_row: bool = it["price"] > left or (top_view and it["layer"] == "wall")
		fit(ids[i], r[0] + 14, cy, 28, 25)
		text(r[0] + 34, cy, it["name"], 15, DIM if dim_row else INK)
		text(r[2] - 34, cy, "x%d" % Game.stock.get(ids[i], 0), 16, CYAN)


func draw() -> void:
	Rules.sync_mounts(Game.placed)   # 옮긴 모니터를 따라 위에 끼운 것도 이동
	Game.cables = Rules.prune(Game.cables, Game.placed, Game.computer())   # 치운 기기 · 사라진 포트의 선은 자동으로 뽑힘
	draw_room()
	if capturing:
		return
	draw_stock()
	top_bar("desk")
	button(BTN_PHOTO, "사진", VIOLET)
	button(BTN_VIEW, "정면 뷰" if top_view else "탑뷰", VIOLET)
	button(BTN_DONE, "납품하기", PINK)
	text(SHOP_W + 10, 30, "탑뷰: 앞뒤로도 배치 · 두 번 누르기: 창고로" if top_view else "누르기: 선택 · 색   두 번 누르기: 창고로", 14, QUIET)
	if toast != "":
		text(SHOP_W + 10, 62, toast, 16, PINK)
	if held != "":
		var a: String = art(moving) if moving != null else held
		if top_view:
			var w: float = Rules.foot_of(held).x * K
			var dd: float = Rules.depth_of(held) * K
			if top_art(a) != "":
				put(top_art(a), [m.mouse.x - w / 2, m.mouse.y - dd / 2, m.mouse.x + w / 2, m.mouse.y + dd / 2])
			else:
				fit(a, m.mouse.x, m.mouse.y, w, dd)
		elif moving != null and armed(moving):   # 암에 달린 모니터를 끌면 팔이 따라 늘어남
			var sz := DB.size_of(a)
			var rr := [m.mouse.x - sz.x / 2.0, m.mouse.y - sz.y / 2.0, m.mouse.x + sz.x / 2.0, m.mouse.y + sz.y / 2.0]
			var f: Array = SCREEN[moving["id"]]
			draw_arm(arm_of(moving), Vector2(m.mouse.x, rr[3] - sz.y * (f[3] * 0.5 / f[5])))
			draw_without_stand(moving, rr)
		else:
			spr(a, m.mouse.x, m.mouse.y)
