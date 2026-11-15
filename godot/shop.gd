extends Mode
## 쇼핑 탭 (데스크몰): 카테고리 → 상품 카드 → 누르면 상세 → 장바구니 → 결제 → 영수증. 더블탭 = 바로 담기.

const CATS := [["screen", "화면"], ["input", "키보드"], ["light", "조명"], ["audio", "오디오"], ["plant", "식물"], ["decor", "소품"], ["wall", "벽 장식"], ["parts", "PC 부품"]]
const PART_TYPES := [["CASE", "케이스"], ["MB", "메인보드"], ["CPU", "CPU"], ["COOLER", "쿨러"], ["SSD", "SSD"], ["GPU", "그래픽카드"], ["RAM", "RAM"], ["PSU", "파워"]]
const PER := 8
const CART := [958, 70, 1270, 640]
const BTN_PAY := [978, 84, 1250, 130]
const BTN_PREV := [330, 14, 380, 50]
const BTN_NEXT := [560, 14, 610, 50]
const CART_ROWS := 9

var cat := "screen"
var part_type := "CASE"
var page := 0
var toast := ""


func enter() -> void:
	toast = ""


func _key(id: String) -> int:
	return (0 if Game.unlocked(DB.spec(id)) else 100000) + Game.price_of(id)   # 살 수 있는 것 먼저, 싼 순


func products() -> Array:
	var ids: Array
	if cat == "parts":
		ids = DB.PARTS.keys().filter(func(p): return DB.PARTS[p]["type"] == part_type)
	else:
		ids = DB.ITEMS.keys().filter(func(i): return DB.ITEMS[i]["cat"] == cat)
	ids.sort_custom(func(a, b): return _key(a) < _key(b))
	return ids


func pages() -> int:
	return max(1, ceili(products().size() / float(PER)))


func visible() -> Array:
	return products().slice(page * PER, (page + 1) * PER)


func card_rect(i: int) -> Array:
	var x := 20 + (i % 4) * 230
	var y2 := 548 - (i / 4) * 244
	return [x, y2 - 232, x + 218, y2]


func cat_rect(i: int) -> Array:
	return [20 + i * 114, 600, 128 + i * 114, 638]


func sub_rect(i: int) -> Array:
	return [20 + i * 100, 560, 114 + i * 100, 590]


func cart_row(i: int) -> Array:
	var y2 := 586 - i * 38
	return [CART[0] + 12, y2 - 34, CART[2] - 12, y2]


func down(x: float, y: float, right: bool) -> void:
	if tabs(x, y):
		return
	for i in CATS.size():
		if inside(x, y, cat_rect(i)):
			cat = CATS[i][0]
			page = 0
			toast = ""
			return
	if cat == "parts":
		for i in PART_TYPES.size():
			if inside(x, y, sub_rect(i)):
				part_type = PART_TYPES[i][0]
				page = 0
				return
	if inside(x, y, BTN_PREV):
		page = max(0, page - 1)
	elif inside(x, y, BTN_NEXT):
		page = min(pages() - 1, page + 1)
	elif inside(x, y, BTN_PAY):
		pay()
	var shown := visible()
	for i in shown.size():
		if inside(x, y, card_rect(i)):
			if right:
				toast = "%s 담음" % DB.spec(shown[i])["name"] if Game.add_to_cart(shown[i]) else "업그레이드가 필요해요"
			else:
				m.modes["product"].open(shown[i])
			return
	var ids := Game.cart.keys()
	for i in min(ids.size(), CART_ROWS):
		if inside(x, y, cart_row(i)):
			Game.add_to_cart(ids[i], -1 if right or x < cart_row(i)[0] + 40 else 1)
			return


func pay() -> void:
	if Game.cart.is_empty():
		toast = "장바구니가 비어 있어요"
		return
	var r := Game.checkout()
	if r.is_empty():
		toast = "가게 돈이 모자라요"
	else:
		m.modes["receipt"].show(r)


func short_spec(p: Dictionary) -> String:
	match p["type"]:
		"CASE": return "보드 %s · GPU %dmm" % [p["mb_max"], p["gpu_max"]]
		"MB": return "%s · %s · RAM %d · USB %d" % [p["socket"], p["size"], p["ram_slots"], p["usb"]]
		"CPU": return "%s · 성능 %d · %dW" % [p["socket"], p["perf"], p["watt"]]
		"COOLER": return "%dW까지 · 높이 %dmm" % [p["tdp"], p["height"]]
		"GPU": return "성능 %d · %dmm · DP %d" % [p["perf"], p["length"], p["dp"]]
		"RAM": return "성능 +%d" % p["perf"]
		"SSD": return "%s · M.2" % p["capacity"]
	return "%dW · GPU 전원선 %d" % [p["capacity"], p["pcie"]]


func draw_card(i: int, id: String) -> void:
	var r := card_rect(i)
	var p := DB.spec(id)
	var locked := not Game.unlocked(p)
	panel(r, Game.cart.has(id))
	frame("ui_slot", [r[0] + 10, r[3] - 122, r[2] - 10, r[3] - 10])
	fit(icon_of(id), (r[0] + r[2]) / 2.0, r[3] - 65, 178, 96)
	text(r[0] + 12, r[3] - 140, p["name"], 15, DIM if locked else INK)
	text(r[0] + 12, r[3] - 166, "%d만 원" % p["price"], 18, DIM if locked else GOLD)
	text(r[0] + 12, r[3] - 190, " · ".join(p["tags"].map(func(t): return DB.THEME_NAMES[t])) if DB.ITEMS.has(id) else short_spec(p), 12, QUIET)
	if locked:
		text(r[0] + 12, r[1] + 14, "업그레이드 필요", 12, PINK)
	elif Game.stock.get(id, 0) > 0:
		text(r[0] + 12, r[1] + 14, "창고 %d" % Game.stock[id], 12, CYAN)
	if Game.cart.has(id):
		text(r[2] - 76, r[1] + 14, "담음 %d" % Game.cart[id], 12, PINK)


func draw_cart() -> void:
	panel(CART, true)
	var ids := Game.cart.keys()
	var count := 0
	for id in ids:
		count += Game.cart[id]
	text(CART[0] + 14, CART[3] - 22, "장바구니  %d개" % count, 18, PINK)
	if ids.is_empty():
		text(CART[0] + 14, CART[3] - 60, "상품을 눌러서 담으세요", 14, QUIET)
		text(CART[0] + 14, CART[3] - 84, "(두 번 누르면 바로 담기)", 13, DIM)
	for i in min(ids.size(), CART_ROWS):
		var r := cart_row(i)
		var p := DB.spec(ids[i])
		var cy: float = (r[1] + r[3]) / 2.0
		frame("ui_slot", r)
		text(r[0] + 8, cy, "−", 18, PINK)
		text(r[0] + 30, cy, p["name"], 16)
		text(r[2] - 90, cy, "×%d" % Game.cart[ids[i]], 16, QUIET)
		text(r[2] - 50, cy, "%d만" % (p["price"] * Game.cart[ids[i]]), 16, GOLD)
	if ids.size() > CART_ROWS:
		text(CART[0] + 14, 226, "외 %d종 (결제하면 영수증에 전부 표시)" % (ids.size() - CART_ROWS), 12, QUIET)
	var total := Game.cart_total()
	text(CART[0] + 14, 196, "합계  %d만 원" % total, 18, GOLD)
	text(CART[0] + 14, 166, "결제 후 가게 돈  %d만" % (Game.money - total), 14, INK if Game.money >= total else PINK)
	text(CART[0] + 14, 144, "이 주문 사용  %d만 / 예산 %d만" % [Game.spent(), Game.request()["budget"]], 12, QUIET)
	button(BTN_PAY, "결제하기", DIM if ids.is_empty() else PINK)


func draw() -> void:
	grid()
	for i in CATS.size():
		var on: bool = CATS[i][0] == cat
		frame("ui_button", cat_rect(i), CYAN if on else Color8(80, 66, 140))
		text(cat_rect(i)[0] + 12, 621, CATS[i][1], 16, Color.WHITE if on else QUIET)
	if cat == "parts":
		for i in PART_TYPES.size():
			var on: bool = PART_TYPES[i][0] == part_type
			frame("ui_button", sub_rect(i), GOLD if on else Color8(60, 50, 110))
			text(sub_rect(i)[0] + 10, 577, PART_TYPES[i][1], 16, Color.WHITE if on else QUIET)
	var shown := visible()
	for i in shown.size():
		draw_card(i, shown[i])
	button(BTN_PREV, "◀", VIOLET)
	button(BTN_NEXT, "▶", VIOLET)
	text(392, 32, "%d/%d · %d개" % [page + 1, pages(), products().size()], 14, QUIET)
	draw_cart()
	top_bar("shop")
	if toast != "":
		text(640, 32, toast, 15, PINK)
	text(640, 56, "가게 돈 %d만 원" % Game.money, 15, CYAN)
