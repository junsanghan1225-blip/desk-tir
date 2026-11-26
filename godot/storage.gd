extends Mode
## 창고 (영업 마감 · 일시정지에서 들어옴): 재고 상자 선반 + 완성 PC 진열대(2단, 옆모습).
## '내 책상' 탭 = 손님 의뢰와 똑같은 쇼핑 · 책상 · 조립 · 배선 화면으로 내 책상 꾸미기 (영업 마감 때, 테마만 내 방).
## 진열대 PC: 주문 중이면 조립대로 꺼내기, 아니면 내 책상 PC로.

const BTN_BACK := [880, 656, 1130, 706]
const VIEWS := [["storage", "창고"], ["desk", "내 책상"]]
const BTN_PREV := [20, 100, 80, 144]
const BTN_NEXT := [400, 100, 460, 144]
const COLS := 5
const PER := 15
const SHOW := [492, 140, 1262, 610]   # 완성 PC 진열대: 2단 × 3대
const ROWS := [410, 170]              # 두 단의 판 높이
const PC_W := 168   # 옆모습 그림 196:210 비율
const PC_H := 180
var page := 0
var toast := ""


func enter() -> void:
	page = 0
	toast = ""


func view_rect(i: int) -> Array:
	return [20 + i * 190, 652, 200 + i * 190, 706]


func ids() -> Array:
	var out := Game.stock.keys().filter(func(i): return Game.stock[i] > 0 and (DB.ITEMS.has(i) or DB.PARTS.has(i)))
	out.sort_custom(func(a, b): return int(DB.PARTS.has(a)) < int(DB.PARTS.has(b)) or DB.PARTS.has(a) == DB.PARTS.has(b) and a < b)   # 소품 먼저
	return out


func box_rect(i: int) -> Array:
	var x := 30 + (i % COLS) * 88
	var y := 470 - (i / COLS) * 150   # 선반 세 단
	return [x, y, x + 80, y + 96]


func rack_rect(i: int) -> Array:
	var x := SHOW[0] + 50 + (i % 3) * 245
	var y: int = ROWS[i / 3]
	return [x, y, x + PC_W, y + PC_H]


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
	if inside(x, y, view_rect(1)):   # 내 책상 꾸미기 (손님 책상과 같은 화면들)
		if Game.mine:
			toast = "지금 내 책상을 꾸미는 중이에요 (창고로 버튼)"
		elif in_order():
			toast = "내 책상은 영업 마감 때 꾸며요"
		else:
			sfx("click")
			Game.enter_mine()
			m.go("desk")
			return
		sfx("error")
		return
	down_storage(x, y)


func down_storage(x: float, y: float) -> void:
	var all := ids()
	if inside(x, y, BTN_PREV) or inside(x, y, BTN_NEXT):
		page = clampi(page + (-1 if inside(x, y, BTN_PREV) else 1), 0, maxi(0, (all.size() - 1) / PER))
		sfx("click")
		return
	var vis := all.slice(page * PER, (page + 1) * PER)
	for i in vis.size():
		if inside(x, y, box_rect(i)):
			var id: String = vis[i]
			if DB.PARTS.has(id):
				toast = "%s: 부품은 조립 때 꺼내 써요" % DB.PARTS[id]["name"]
				return
			toast = "%s ×%d · 내 책상 탭에서 끌어다 놓아요" % [DB.ITEMS[id]["name"], Game.stock[id]]
			return
	for i in Game.SHELF_MAX:
		if not inside(x, y, rack_rect(i)):
			continue
		if i >= Game.shelf.size():   # 빈 칸: 주문 중 조립대 PC 올리기
			toast = Game.shelve() if in_order() else "주문 중 조립한 PC를 여기 올려 둬요 (ll → 창고)"
			if toast == "":
				toast = "진열대에 보관! 조건 맞는 손님이 오면 바로 꺼내 써요 (하루 %d만)" % Game.SHELF_FEE
				sfx("place")
				saved()
		elif in_order() and not Game.mine:
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
const WOOD := Color8(128, 92, 64)
const METAL := Color8(64, 62, 78)


func plank(x0: float, x1: float, y: float) -> void:   # 원목 선반 판 (윗면 밝게 · 아래 그림자)
	box([x0, y - 12, x1, y], WOOD)
	box([x0, y - 3, x1, y], WOOD.lightened(0.2))
	box([x0 + 6, y - 20, x1 - 6, y - 12], Color(0, 0, 0, 0.25))


func cardboard(r: Array) -> void:
	box(r, Color8(176, 132, 88))
	box([r[0], r[3] - 16, r[2], r[3]], Color8(194, 150, 104))   # 뚜껑
	box([(r[0] + r[2]) / 2.0 - 5, r[3] - 16, (r[0] + r[2]) / 2.0 + 5, r[3]], Color8(214, 196, 160))   # 테이프
	outline(r, Color8(110, 78, 50), 1)


## 진짜 PC 옆모습: 책상 화면의 '완성 모습' 그리기를 빌려 씀 (유리 너머 실제 부품)
func draw_pc(d: Dictionary, r: Array) -> void:
	var keep := Game.pc
	Game.pc = PCBuild.from_dict(d)
	m.modes["desk"].draw_side(r, false)
	Game.pc = keep


func draw_stock() -> void:
	text(24, 615, "재고 선반", 22, CYAN)
	for ux in [18, 462]:   # 기둥
		box([ux, 150, ux + 10, 590], METAL)
	for lv in [470, 320, 170]:
		plank(18, 472, lv)
	var all := ids()
	var vis := all.slice(page * PER, (page + 1) * PER)
	for i in vis.size():
		var r := box_rect(i)
		cardboard(r)
		fit(icon_of(vis[i]), (r[0] + r[2]) / 2.0, r[1] + 42, 60, 54)
		var n := "×%d" % Game.stock[vis[i]]
		text(r[2] - text_w(n, 22) - 2, r[1] + 12, n, 22, INK)
		if inside(m.mouse.x, m.mouse.y, r):
			outline(grow(r, 2), CYAN, 2)
	if all.is_empty():
		text(40, 400, "재고가 비었어요", 22, QUIET)
	var pages := maxi(1, ceili(all.size() / float(PER)))
	button(BTN_PREV, "◀", VIOLET)
	button(BTN_NEXT, "▶", VIOLET)
	text_c([80, 100, 400, 144], "재고 %d종 · %d/%d" % [all.size(), page + 1, pages], 22, INK)


func draw_rack() -> void:
	text(SHOW[0] + 4, 615, "완성 PC 진열대  ·  %d/%d대" % [Game.shelf.size(), Game.SHELF_MAX], 22, CYAN)
	for k in 6:   # 진열대 위 은은한 조명
		box([SHOW[0] + k * 12, SHOW[1], SHOW[2] - k * 12, SHOW[3] - k * 8], Color(1, 0.9, 0.7, 0.015))
	for ux in [SHOW[0], SHOW[2] - 10]:   # 기둥
		box([ux, SHOW[1], ux + 10, 595], METAL)
	for lv in ROWS:
		plank(SHOW[0], SHOW[2], lv)
	var order := in_order() and Game.in_order()
	for i in Game.SHELF_MAX:
		var r := rack_rect(i)
		if i < Game.shelf.size():
			draw_pc(Game.shelf[i], r)
			var tag := ("맞음" if Game.shelf_fits(i) else "안 맞음") if order else "보관 %d만/일" % Game.SHELF_FEE
			var tw := text_w(tag, 22) + 24
			chip((r[0] + r[2] - tw) / 2.0, r[1] + 26, tag, (GREEN if Game.shelf_fits(i) else PINK) if order else QUIET)   # PC 아래쪽 위에 겹쳐 (단 사이를 안 가림)
		else:
			var hot: bool = order and Game.pc.has("CASE")
			outline([r[0] + 10, r[1] + 6, r[2] - 10, r[3] - 10], CYAN if hot else Color(1, 1, 1, 0.12), 2)
			text_c([r[0], r[1], r[2], r[3]], "+ 올리기" if hot else "빈 자리", 22, CYAN if hot else DIM)


func draw() -> void:
	box([0, 0, 1280, H], Color8(26, 22, 40))   # 벽
	box([0, 0, 1280, 140], Color8(40, 36, 52))   # 바닥
	box([0, 138, 1280, 142], Color8(60, 54, 78))
	for i in VIEWS.size():
		var q := press_frame(view_rect(i), PINK if i == 0 else Color8(80, 66, 140))
		text_c(q, VIEWS[i][1], 22, Color.WHITE if i == 0 else QUIET)
	text(420, 679, "가게 %d만" % Game.money, 22, GOLD)
	button(BTN_BACK, "돌아가기", VIOLET)
	draw_stock()
	draw_rack()
	var hint := "진열대 PC를 누르면 내 책상 PC로 · '내 책상' 탭에서 꾸미기"
	text(20, 50, clip(toast if toast != "" else hint, 760), 22, GOLD if toast != "" else QUIET)
