extends Mode
## 책상 꾸미기: 창고 재고에서 끌어다 벽 · 책상 위에 자유 배치. 눌러서 선택(색 바꾸기), 더블탭 = 창고로.

const SHOP_W := 270
const ROW_H := 31
const ROW_TOP := 600
const ROOM := [270, 0, 1280, 650]
const PC_RECT := [1095, 210, 1255, 470]
const BTN_DONE := [1100, 10, 1270, 50]
const PER := 16
const BTN_PREV := [14, 66, 64, 96]
const BTN_NEXT := [206, 66, 256, 96]

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


func all_ids() -> Array:
	return DB.ITEMS.keys().filter(func(i): return Game.stock.get(i, 0) > 0 or (i == held and moving == null))


func rows() -> Array:
	return all_ids().slice(page * PER, (page + 1) * PER)


func row_rect(i: int) -> Array:
	var y := ROW_TOP - i * ROW_H
	return [10, y - ROW_H + 4, SHOP_W - 10, y]


func chip_rect(p: Dictionary, k: int) -> Array:
	var r := Rules.rect_of(p)
	var x: float = (r[0] + r[2]) / 2.0 - Rules.COLORS * 20 + k * 40
	var y: float = min(r[3] + 8, 610)
	return [x, y, x + 36, y + 36]


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
	if selected != null and DB.ITEMS[selected["id"]].get("tint", false) and not right:
		for k in Rules.COLORS:
			if inside(x, y, chip_rect(selected, k)):
				selected["color"] = k
				return
	var p = Rules.item_at(Game.placed, x, y)
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
		if inside(x, y, PC_RECT):
			m.go("build")


func up(x: float, y: float) -> void:
	if held == "":
		return
	var id := held
	var mv = moving
	held = ""
	moving = null
	if mv != null and abs(x - origin.x) + abs(y - origin.y) < 6:   # 움직이지 않은 누름 = 선택
		selected = null if is_same(selected, mv) else mv
		return
	var t = Rules.drop_target(id, x, y)
	var ok: bool = t != null and Rules.fits_at(Game.placed, id, t[0], t[1], t[2], mv)
	if mv != null:
		if ok:
			mv["x"] = t[1]
			mv["y"] = t[2]
		else:
			toast = "그 자리엔 못 놓아서 원래 자리에 뒀어요"
	elif ok and Game.take(id):
		selected = {"id": id, "layer": t[0], "x": t[1], "y": t[2]}
		Game.placed.append(selected)
		toast = ""
	elif t != null or inside(x, y, ROOM):
		toast = "%s은(는) '%s'의 빈 곳에 놓아 주세요" % [DB.ITEMS[id]["name"], Rules.LAYER_NAMES[DB.ITEMS[id]["layer"]]]


func draw_room() -> void:
	spr("room_bg_" + Game.today()["weather"], 775, 325)
	for layer in ["wall", "desk"]:   # 벽 먼저, 책상 위가 앞
		for p in Game.placed:
			if p["layer"] == layer and not is_same(p, moving):
				put(art(p), Rules.rect_of(p))
	var case_name: String = Game.pc.parts.get("CASE", "case_empty")
	var s := DB.size_of(case_name)
	put(case_name, [1175 - s.x / 2.0, PC_RECT[1], 1175 + s.x / 2.0, PC_RECT[1] + s.y])
	text(PC_RECT[0] + 20, PC_RECT[3] + 16, "부팅 OK" if Game.pc.boots() else "PC 조립 필요", 14, CYAN)
	if held != "":   # 놓일 자리 미리 보기
		var t = Rules.drop_target(held, m.mouse.x, m.mouse.y)
		if t != null:
			var hs := DB.size_of(held)
			outline([t[1], t[2], t[1] + hs.x, t[2] + hs.y], CYAN if Rules.fits_at(Game.placed, held, t[0], t[1], t[2], moving) else PINK, 2)
	if selected != null and Game.placed.has(selected):
		outline(Rules.rect_of(selected), GOLD, 2)
		if DB.ITEMS[selected["id"]].get("tint", false):
			for k in Rules.COLORS:
				var r := chip_rect(selected, k)
				frame("ui_button", r, GOLD if selected.get("color", 0) == k else Color8(80, 66, 140))
				fit(selected["id"] + ("__c%d" % k if k else ""), (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, 30, 30)
	if Time.get_ticks_msec() / 333 % 2:   # 케이블이 안 꽂힌 기기 위에 깜빡이는 점
		for p in Game.placed:
			if Rules.needs_cable(p) and not is_same(p, moving) and not Game.cables.any(func(c): return is_same(c["dev"], p)):
				var r := Rules.rect_of(p)
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
		fit(ids[i], r[0] + 14, cy, 28, 25)
		text(r[0] + 34, cy, it["name"], 15, DIM if it["price"] > left else INK)
		text(r[2] - 34, cy, "x%d" % Game.stock.get(ids[i], 0), 16, CYAN)


func draw() -> void:
	Game.cables = Rules.prune(Game.cables, Game.placed, Game.pc)   # 치운 기기 · 사라진 포트의 선은 자동으로 뽑힘
	draw_room()
	draw_stock()
	top_bar("desk")
	button(BTN_DONE, "납품하기", PINK)
	text(SHOP_W + 10, 30, "누르기: 선택 · 색 바꾸기   두 번 누르기(우클릭): 창고로", 14, QUIET)
	if toast != "":
		text(SHOP_W + 10, 62, toast, 16, PINK)
	if held != "":
		spr(art(moving) if moving != null else held, m.mouse.x, m.mouse.y)
