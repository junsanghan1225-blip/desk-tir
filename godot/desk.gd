extends Mode
## 책상 꾸미기: 창고 재고에서 끌어다 놓는다. 정면 뷰(벽 · 책상 위) ⇄ 탑뷰(책상을 위에서 크게, 앞뒤까지).
## 누르기 = 선택(색 바꾸기), 두 번 누르기(우클릭) = 창고로.

const SHOP_W := 270
const ROW_H := 31
const ROW_TOP := 600
const ROOM := [270, 0, 1280, 650]
const PC_RECT := [1095, 210, 1255, 470]
const BTN_DONE := [1100, 10, 1270, 50]
const BTN_VIEW := [920, 10, 1090, 50]
const PER := 16
const BTN_PREV := [14, 66, 64, 96]
const BTN_NEXT := [206, 66, 256, 96]
# 탑뷰: 책상 x 300~1070 · 앞뒤 0~DESK_DEPTH 를 K배로 크게
const K := 1.2
const TOP_BACK := 590.0   # 책상 뒤쪽(벽) 가장자리 화면 높이

var top_view := false
var held := ""       # 끌고 있는 소품 id
var moving = null    # 책상에서 집어 든 소품 (실패하면 제자리 그대로)
var origin := Vector2.ZERO
var selected = null
var toast := ""
var page := 0


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
	var sx: float = Rules.AREA_X1 + (x - Rules.AREA_X1) * K
	return [sx, TOP_BACK - (z + Rules.depth_of(id)) * K, sx + DB.size_of(id).x * K, TOP_BACK - z * K]


func desk_rect() -> Array:
	return [Rules.AREA_X1 - 8, TOP_BACK - Rules.DESK_DEPTH * K - 8, Rules.AREA_X1 + (Rules.AREA_X2 - Rules.AREA_X1) * K + 8, TOP_BACK + 8]


## 지금 뷰에서 소품이 차지하는 화면 영역 (탑뷰에선 벽 장식이 안 보여서 [])
func shown_rect(p: Dictionary) -> Array:
	if not top_view:
		return Rules.rect_of(p)
	return top_rect(p["id"], p["x"], p.get("z", 0)) if p["layer"] == "desk" else []


func hit(x: float, y: float):
	if not top_view:
		return Rules.item_at(Game.placed, x, y)
	var best = null   # 겹치면 앞에 있는 것(z 큰 것)
	for p in Game.placed:
		var r := shown_rect(p)
		if not r.is_empty() and inside(x, y, r) and (best == null or p.get("z", 0) > best.get("z", 0)):
			best = p
	return best


## 놓일 자리 {layer, x, y, z, ok}. 근처가 아니면 {}.
func target(id: String, x: float, y: float) -> Dictionary:
	var layer: String = DB.ITEMS[id]["layer"]
	var keep: int = moving.get("z", 0) if moving != null else -1
	if top_view:
		if layer != "desk" or not inside(x, y, grow(desk_rect(), 40)):
			return {}
		var s := DB.size_of(id)
		var d := Rules.depth_of(id)
		var bx := int(clamp(Rules.AREA_X1 + (x - Rules.AREA_X1) / K - s.x / 2.0, Rules.AREA_X1, Rules.AREA_X2 - s.x))
		var z := int(clamp(snappedf((TOP_BACK - y) / K - d / 2.0, Rules.Z_STEP), 0, Rules.DESK_DEPTH - d))
		return {"layer": layer, "x": bx, "y": Rules.DESK_Y, "z": z, "ok": Rules.fits_at(Game.placed, id, layer, bx, Rules.DESK_Y, moving, z)}
	var t = Rules.drop_target(id, x, y)
	if t == null:
		return {}
	if layer == "wall":
		return {"layer": layer, "x": t[1], "y": t[2], "z": 0, "ok": Rules.fits_at(Game.placed, id, layer, t[1], t[2], moving)}
	var fz := Rules.free_z(Game.placed, id, t[1], moving, keep)   # 정면에선 비어 있는 앞뒤 자리를 알아서 찾는다
	return {"layer": layer, "x": t[1], "y": t[2], "z": max(fz, 0), "ok": fz >= 0}


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
		m.go("result")
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
				return
	var p = hit(x, y)
	if right:
		if p != null:
			Game.placed.erase(p)
			Game.give_back(p["id"])
			selected = null
		return
	var ids := rows()
	for i in ids.size():
		if inside(x, y, row_rect(i)):
			if DB.ITEMS[ids[i]]["price"] > Game.money_left():
				toast = "손님 예산을 넘어요!"
			else:
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
		return
	var ok: bool = not t.is_empty() and t["ok"]
	if mv != null:
		if ok:
			mv["x"] = t["x"]
			mv["y"] = t["y"]
			mv["z"] = t["z"]
		else:
			toast = "그 자리엔 못 놓아서 원래 자리에 뒀어요"
	elif ok and Game.take(id):
		selected = {"id": id, "layer": t["layer"], "x": t["x"], "y": t["y"], "z": t["z"]}
		Game.placed.append(selected)
		toast = ""
	elif top_view and DB.ITEMS[id]["layer"] == "wall":
		toast = "벽 장식은 정면 뷰에서 걸어 주세요"
	elif not t.is_empty() or inside(x, y, ROOM):
		toast = "%s은(는) '%s'의 빈 곳에 놓아 주세요" % [DB.ITEMS[id]["name"], Rules.LAYER_NAMES[DB.ITEMS[id]["layer"]]]


# ---------- 그리기 ----------
func by_depth() -> Array:
	var desk := Game.placed.filter(func(p): return p["layer"] == "desk")
	desk.sort_custom(func(a, b): return a.get("z", 0) < b.get("z", 0))   # 벽쪽(뒤) 먼저, 앞이 위에
	return desk


func draw_front() -> void:
	spr("room_bg_" + Game.today()["weather"], 775, 325)
	for p in Game.placed.filter(func(p): return p["layer"] == "wall") + by_depth():
		if not is_same(p, moving):
			put(art(p), Rules.rect_of(p))
	var case_name: String = Game.pc.parts.get("CASE", "case_empty")
	var s := DB.size_of(case_name)
	put(case_name, [1175 - s.x / 2.0, PC_RECT[1], 1175 + s.x / 2.0, PC_RECT[1] + s.y])
	text(PC_RECT[0] + 20, PC_RECT[3] + 16, "부팅 OK" if Game.pc.boots() else "PC 조립 필요", 14, CYAN)


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
		if is_same(p, moving):
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
	if selected != null and Game.placed.has(selected) and not shown_rect(selected).is_empty():
		outline(shown_rect(selected), GOLD, 2)
		if DB.ITEMS[selected["id"]].get("tint", false):
			for k in Rules.COLORS:
				var r := chip_rect(selected, k)
				frame("ui_button", r, GOLD if selected.get("color", 0) == k else Color8(80, 66, 140))
				fit(selected["id"] + ("__c%d" % k if k else ""), (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0 + 2, 26, 26)
	if Time.get_ticks_msec() / 333 % 2:   # 케이블이 안 꽂힌 기기 위에 깜빡이는 점
		for p in Game.placed:
			if Rules.needs_cable(p) and not is_same(p, moving) and not shown_rect(p).is_empty() and not Game.cables.any(func(c): return is_same(c["dev"], p)):
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
	Game.cables = Rules.prune(Game.cables, Game.placed, Game.pc)   # 치운 기기 · 사라진 포트의 선은 자동으로 뽑힘
	draw_room()
	draw_stock()
	top_bar("desk")
	button(BTN_VIEW, "정면 뷰" if top_view else "탑뷰", VIOLET)
	button(BTN_DONE, "납품하기", PINK)
	text(SHOP_W + 10, 30, "탑뷰: 앞뒤로도 배치 · 두 번 누르기: 창고로" if top_view else "누르기: 선택 · 색   두 번 누르기: 창고로", 14, QUIET)
	if toast != "":
		text(SHOP_W + 10, 62, toast, 16, PINK)
	if held != "":
		var a: String = art(moving) if moving != null else held
		if top_view:
			var hs := DB.size_of(held)
			var w: float = hs.x * K
			var dd: float = Rules.depth_of(held) * K
			if top_art(a) != "":
				put(top_art(a), [m.mouse.x - w / 2, m.mouse.y - dd / 2, m.mouse.x + w / 2, m.mouse.y + dd / 2])
			else:
				fit(a, m.mouse.x, m.mouse.y, w, dd)
		else:
			spr(a, m.mouse.x, m.mouse.y)
