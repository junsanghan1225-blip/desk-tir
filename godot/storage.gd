extends Mode
## 창고: 철제 선반에 재고 상자 · 완성 PC 랙 · 남는 돈으로 꾸미는 내 책상 (영업 마감 · 일시정지에서 들어옴).
## 상자 누르기 = 내 책상에 전시 · 전시품 누르기 = 상자로. 랙 PC: 주문 중이면 조립대로 꺼내기, 아니면 내 책상에 올리기.

const BTN_BACK := [880, 656, 1130, 706]
const BTN_PREV := [20, 100, 80, 144]
const BTN_NEXT := [400, 100, 460, 144]
const BTN_DESK := [800, 26, 1260, 80]
const COLS := 5
const PER := 15
const RACK := [500, 150, 760, 610]
const DESK := [790, 150, 1260, 610]
var page := 0
var toast := ""


func enter() -> void:
	page = 0
	toast = ""


func ids() -> Array:
	var out := Game.stock.keys().filter(func(i): return Game.stock[i] > 0 and (DB.ITEMS.has(i) or DB.PARTS.has(i)))
	out.sort_custom(func(a, b): return int(DB.PARTS.has(a)) < int(DB.PARTS.has(b)) or DB.PARTS.has(a) == DB.PARTS.has(b) and a < b)   # 소품 먼저
	return out


func box_rect(i: int) -> Array:
	var x := 30 + (i % COLS) * 88
	var y := 470 - (i / COLS) * 150   # 선반 세 단
	return [x, y, x + 80, y + 96]


func rack_rect(i: int) -> Array:
	var y := 470 - i * 150
	return [RACK[0] + 14, y, RACK[2] - 14, y + 128]


## 전시 칸: 앞 4칸은 책상 위, 뒤 3칸은 벽 선반
func slot_rect(i: int) -> Array:
	if i < 4:
		var x := DESK[0] + 24 + i * 84
		return [x, 302, x + 76, 378]
	var wx := DESK[0] + 40 + (i - 4) * 100
	return [wx, 486, wx + 80, 566]


func my_pc_rect() -> Array:
	return [DESK[2] - 112, 302, DESK[2] - 16, 430]


func in_order() -> bool:
	return m.stack[0] in [m.modes["shop"], m.modes["desk"], m.modes["build"], m.modes["wire"]]


func saved() -> void:
	Game.save(m.modes.find_key(m.stack[0]))


func down(x: float, y: float, _right: bool) -> void:
	toast = ""
	if inside(x, y, BTN_BACK):
		sfx("click")
		m.pop()
		return
	var all := ids()
	if inside(x, y, BTN_PREV) or inside(x, y, BTN_NEXT):
		page = clampi(page + (-1 if inside(x, y, BTN_PREV) else 1), 0, maxi(0, (all.size() - 1) / PER))
		sfx("click")
		return
	if inside(x, y, BTN_DESK):
		toast = Game.upgrade_desk()
		if toast == "":
			toast = "%s 들여놨어요! 전시 칸 %d개" % [Game.DESKS[Game.desk_tier][0], Game.DESKS[Game.desk_tier][2]]
			sfx("buy")
			saved()
		else:
			sfx("error")
		return
	var vis := all.slice(page * PER, (page + 1) * PER)
	for i in vis.size():
		if inside(x, y, box_rect(i)):
			var id: String = vis[i]
			if DB.PARTS.has(id):
				toast = "%s: 부품은 조립 때 꺼내 써요" % DB.PARTS[id]["name"]
				return
			toast = Game.display(id)
			if toast == "":
				toast = "%s 전시!" % DB.ITEMS[id]["name"]
				sfx("place")
				saved()
			return
	for i in Game.showcase.size():
		if inside(x, y, slot_rect(i)):
			Game.undisplay(i)
			sfx("pick")
			saved()
			return
	if not Game.my_pc.is_empty() and inside(x, y, my_pc_rect()):
		toast = Game.pc_off_desk()
		if toast == "":
			toast = "내 PC를 랙으로 옮겼어요"
			saved()
		return
	for i in Game.SHELF_MAX:
		if not inside(x, y, rack_rect(i)):
			continue
		if i >= Game.shelf.size():   # 빈 칸: 주문 중 조립대 PC 올리기
			toast = Game.shelve() if in_order() else "주문 중 조립한 PC를 여기 올려 둬요 (ll → 창고)"
			if toast == "":
				toast = "랙에 보관! 조건이 맞는 손님이 오면 바로 꺼내 써요 (하루 %d만)" % Game.SHELF_FEE
				sfx("place")
				saved()
		elif in_order():
			toast = Game.unshelve(i)
			if toast == "":
				toast = "조립대로 꺼냈어요 → 배선만 하면 돼요"
				sfx("boot_ok")
				saved()
			else:
				sfx("error")
		else:
			Game.pc_to_desk(i)
			toast = "내 책상에 올렸어요"
			sfx("place")
			saved()
		return


# ---------- 그리기 ----------
func draw_room() -> void:
	box([0, 0, 1280, H], Color8(30, 32, 44))   # 벽
	for x in range(0, 1280, 40):   # 골함석 벽
		box([x, 170, x + 3, 640], Color8(40, 43, 58))
	box([0, 0, 1280, 160], Color8(52, 50, 54))   # 콘크리트 바닥
	for x in range(-200, 1280, 160):
		line(Vector2(x, 0), Vector2(x + 120, 160), Color8(60, 58, 62), 2)
	for x in range(0, 1280, 48):   # 노랑 · 검정 안전선
		poly([Vector2(x, 156), Vector2(x + 24, 156), Vector2(x + 34, 166), Vector2(x + 10, 166)], Color8(220, 180, 40))
	for lx in [240, 640, 1030]:   # 매달린 작업등 + 빛
		line(Vector2(lx, 640), Vector2(lx, 616), Color8(90, 90, 100), 3)
		poly([Vector2(lx - 22, 616), Vector2(lx + 22, 616), Vector2(lx + 30, 604), Vector2(lx - 30, 604)], Color8(70, 74, 86))
		poly([Vector2(lx - 30, 604), Vector2(lx + 30, 604), Vector2(lx + 190, 160), Vector2(lx - 190, 160)], Color(1, 0.92, 0.7, 0.05))
		circle(lx, 602, 6, Color8(255, 230, 160))


func rack_frame(r: Array, levels: Array) -> void:
	for lv in levels:   # 주황 가로대
		box([r[0], lv - 14, r[2], lv], Color8(220, 110, 40))
		box([r[0], lv - 14, r[2], lv - 10], Color8(150, 70, 30))
	for ux in [r[0], r[2] - 14]:   # 파란 기둥 (구멍 뚫린)
		box([ux, 120, ux + 14, r[3]], Color8(50, 90, 160))
		for hy in range(130, int(r[3]), 24):
			box([ux + 5, hy, ux + 9, hy + 8], Color8(20, 30, 60))


func cardboard(r: Array) -> void:
	box(r, Color8(176, 128, 78))
	box([r[0], r[3] - 18, r[2], r[3]], Color8(196, 148, 92))   # 뚜껑
	box([(r[0] + r[2]) / 2.0 - 6, r[3] - 18, (r[0] + r[2]) / 2.0 + 6, r[3]], Color8(210, 190, 150))   # 테이프
	outline(r, Color8(90, 60, 34), 2)


func draw_stock() -> void:
	rack_frame([16, 150, 474, 610], [460, 310, 160])
	var all := ids()
	var vis := all.slice(page * PER, (page + 1) * PER)
	for i in vis.size():
		var r := box_rect(i)
		cardboard(r)
		fit(icon_of(vis[i]), (r[0] + r[2]) / 2.0, r[1] + 44, 62, 56)
		var n := "×%d" % Game.stock[vis[i]]
		text(r[2] - text_w(n, 22) - 2, r[1] + 12, n, 22, INK)
		if inside(m.mouse.x, m.mouse.y, r):
			outline(grow(r, 2), CYAN, 2)
	for i in range(vis.size(), PER):   # 빈 칸엔 접어 둔 빈 상자 (창고 분위기)
		var r := box_rect(i)
		box([r[0] + 4, r[1], r[2] - 4, r[1] + 22], Color8(110, 82, 52))
		box([r[0] + 4, r[1] + 22, r[2] - 4, r[1] + 26], Color8(90, 66, 42))
	if all.is_empty():
		text(40, 400, "재고가 비었어요", 22, QUIET)
	var pages := maxi(1, ceili(all.size() / float(PER)))
	button(BTN_PREV, "◀", VIOLET)
	button(BTN_NEXT, "▶", VIOLET)
	text_c([80, 100, 400, 144], "재고 %d종 · %d/%d" % [all.size(), page + 1, pages], 22, INK)


func draw_pc(d: Dictionary, r: Array) -> void:
	fit(icon_of(d["parts"].get("CASE", "case1")), (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, r[2] - r[0], r[3] - r[1])


func draw_rack() -> void:
	rack_frame(RACK, [460, 310, 160])
	text(RACK[0] + 8, 630 - 10, "완성 PC 랙", 22, CYAN)
	var order := in_order() and Game.in_order()
	for i in Game.SHELF_MAX:
		var r := rack_rect(i)
		if i < Game.shelf.size():
			draw_pc(Game.shelf[i], [r[0], r[1] + 6, r[0] + 110, r[3]])
			if order:
				var ok := Game.shelf_fits(i)
				chip(r[0] + 112, r[1] + 80, "맞음" if ok else "안 맞음", GREEN if ok else PINK)
			text(r[0] + 116, r[1] + 30, "%d만/일" % Game.SHELF_FEE, 22, QUIET)
		else:
			outline([r[0] + 6, r[1] + 6, r[2] - 6, r[3]], DIM, 2)
			text_c([r[0], r[1], r[2], r[3]], "+ 올리기" if order and Game.pc.has("CASE") else "빈 칸", 22, CYAN if order and Game.pc.has("CASE") else DIM)


func draw_desk() -> void:
	var t := Game.desk_tier
	text(DESK[0], 630 - 10, "내 책상 · %s" % Game.DESKS[t][0], 22, GOLD)
	box([DESK[0] + 10, 400, DESK[2] - 10, 596], Color8(44, 40, 70) if t < 2 else Color8(40, 24, 70))   # 벽 패널
	if t == 2:
		box([DESK[0] + 10, 400, DESK[2] - 10, 406], PINK)
		box([DESK[0] + 10, 590, DESK[2] - 10, 596], CYAN)
	var top: Color = [Color8(150, 150, 160), Color8(150, 100, 60), Color8(30, 30, 40)][t]
	box([DESK[0] + 10, 280, DESK[2] - 10, 302], top)   # 상판
	box([DESK[0] + 30, 160, DESK[0] + 44, 280], top.darkened(0.3))   # 다리
	box([DESK[2] - 44, 160, DESK[2] - 30, 280], top.darkened(0.3))
	if t == 2:
		box([DESK[0] + 10, 276, DESK[2] - 10, 280], Color(CYAN, 0.9))   # LED 줄
		box([DESK[0] + 10, 160, DESK[2] - 10, 276], Color(CYAN, 0.06))
	if t >= 1:
		box([DESK[0] + 30, 474, DESK[2] - 30, 486], top.darkened(0.2))   # 벽 선반
	var slots: int = Game.DESKS[t][2]
	for i in slots:
		var r := slot_rect(i)
		if i < Game.showcase.size():
			fit(Game.showcase[i], (r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0, r[2] - r[0], r[3] - r[1])
		else:
			outline(r, Color(1, 1, 1, 0.15), 1)
	if not Game.my_pc.is_empty():
		draw_pc(Game.my_pc, my_pc_rect())
	text(DESK[0] + 10, 200, "전시 %d/%d · 모은 소품 %d종" % [Game.showcase.size(), slots, collected()], 22, INK)


func collected() -> int:
	var seen := {}
	for i in Game.showcase:
		seen[i] = true
	return seen.size()


func draw() -> void:
	draw_room()
	text(30, 684, "창고", 34, PINK)
	text(140, 684, "가게 %d만" % Game.money, 22, GOLD)
	button(BTN_BACK, "돌아가기", VIOLET)
	draw_stock()
	draw_rack()
	draw_desk()
	if Game.desk_tier + 1 < Game.DESKS.size():
		var nxt: Array = Game.DESKS[Game.desk_tier + 1]
		button(BTN_DESK, "%s로 바꾸기 · %d만" % [nxt[0], nxt[1]], PINK)
	if toast != "":
		text(20, 50, clip(toast, 760), 22, GOLD)
	else:
		text(20, 50, clip("상자 → 내 책상에 전시 · 전시품을 누르면 상자로", 760), 22, QUIET)
