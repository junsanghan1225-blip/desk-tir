extends Mode
## 쇼핑 탭 (데스크몰): 카테고리 → 상품 카드 → 누르면 상세 → 장바구니 → 결제 → 영수증. 두 번 누르기 = 바로 담기.
## 폰 기준: 글씨 22px 이상, 누르는 곳 높이 54px 이상.

const CATS := [["parts", "PC 부품"], ["screen", "화면"], ["input", "키보드"], ["light", "조명"], ["audio", "오디오"], ["plant", "식물"], ["decor", "소품"], ["wall", "벽"]]
const PART_TYPES := [["CASE", "케이스"], ["MB", "보드"], ["CPU", "CPU"], ["COOLER", "쿨러"], ["SSD", "SSD"], ["GPU", "그래픽"], ["RAM", "RAM"], ["PSU", "파워"]]
const PER := 6
const CART := [956, 76, 1276, 632]
const BTN_PAY := [968, 6, 1264, 70]
const BTN_PREV := [12, 6, 96, 64]
const BTN_NEXT := [232, 6, 316, 64]
const CART_ROWS := 5

var cat := "parts"
var part_type := "CASE"
var page := 0
var toast := ""
var pending := ""   # 중고 매물: 한 번 더 누르면 구매
var cart_top := 0   # 장바구니 스크롤: 맨 위에 보이는 줄
const BTN_CUP := [1180, 196, 1222, 236]
const BTN_CDOWN := [1226, 196, 1268, 236]


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
	if cat == "parts":   # 오늘의 중고 매물은 같은 종류 새 제품 뒤에 섞어서
		var os := Game.offers()
		for k in os.size():
			if DB.PARTS[os[k]["id"]]["type"] == part_type:
				ids.push_back("o%d" % k)
	return ids


func offer(key: String) -> Dictionary:
	return Game.offers()[int(key.substr(1))]


func pages() -> int:
	return max(1, ceili(products().size() / float(PER)))


func visible() -> Array:
	return products().slice(page * PER, (page + 1) * PER)


func grid_top() -> float:
	return 506.0 if cat == "parts" else 562.0


func card_rect(i: int) -> Array:
	var x := 12 + (i % 3) * 314
	var h: float = (grid_top() - 76) / 2.0
	var y2: float = grid_top() - (i / 3) * h
	return [x, y2 - h + 8, x + 302, y2]


func cat_rect(i: int) -> Array:
	return [12 + i * 101 + (14 if i >= 1 else 0), 572, 108 + i * 101 + (14 if i >= 1 else 0), 632]   # PC 부품 | 꾸미기


func sub_rect(i: int) -> Array:
	return [12 + i * 116, 516, 122 + i * 116, 566]


func cart_row(i: int) -> Array:
	var y2 := 568 - i * 66
	return [CART[0] + 10, y2 - 60, CART[2] - 10, y2]


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
			if shown[i].begins_with("o"):   # 중고: 바로 거래 (환불 없음)
				var o := offer(shown[i])
				if pending == o["key"]:
					var ok := Game.buy_offer(o)
					toast = "중고 %s 샀어요 → 조립 탭 재고" % DB.PARTS[o["id"]]["name"] if ok else "가게 돈이 모자라요"
					sfx("buy" if ok else "error")
					pending = ""
				else:
					pending = o["key"]
					toast = "한 번 더 누르면 %d만에 구매 (환불 안 돼요)" % o["price"]
				return
			if right:
				var added := Game.add_to_cart(shown[i])
				toast = "%s 담음" % DB.spec(shown[i])["name"] if added else "잠겨 있어요 → 눌러서 해금"
				sfx("cart" if added else "error")
			else:
				m.modes["product"].open(shown[i])
			return
	var ids := Game.cart.keys()
	if ids.size() > CART_ROWS and (inside(x, y, BTN_CUP) or inside(x, y, BTN_CDOWN)):
		scroll_cart(-1 if inside(x, y, BTN_CUP) else 1)
		sfx("click")
		return
	clamp_cart()
	for i in min(ids.size() - cart_top, CART_ROWS):
		if inside(x, y, cart_row(i)):
			Game.add_to_cart(ids[cart_top + i], -1 if right or x < cart_row(i)[0] + 56 else 1)   # 왼쪽 − 칸 = 하나 빼기
			return


func pay() -> void:
	if Game.cart.is_empty():
		toast = "장바구니가 비어 있어요"
		return
	var r := Game.checkout()
	if r.is_empty():
		toast = "가게 돈이 모자라요"
		sfx("error")
	else:
		sfx("buy")
		m.modes["receipt"].show(r)


## 카드에 한 줄로: 소품은 분위기, 부품은 핵심 사양
func short_spec(id: String) -> String:
	var p := DB.spec(id)
	if DB.ITEMS.has(id):
		return " · ".join(p["tags"].map(func(t): return DB.THEME_NAMES[t]))
	match p["type"]:
		"CASE": return "보드 %s까지" % p["mb_max"]
		"MB": return "%s · %s" % [p["socket"], p["size"]] + (" · Wi-Fi" if p.get("wifi", false) else "")
		"CPU": return "%d코어 %.1fGHz" % [p["cores"], p["ghz"]] + (" · 내장" if p.get("igpu", 0) else "")
		"COOLER": return "%dW · 소음 %d" % [p["tdp"], p["noise"]]
		"GPU": return "%dfps · %dGB" % [p["fps"], p["vram"]]
		"RAM": return "%dGB %dMHz" % [p["gb"], p.get("mhz", 3200)]
		"SSD": return "%s · %dMB/s" % [p["capacity"], p.get("read", 3500)]
	return "%dW · %s" % [p["capacity"], p.get("grade", "인증 없음")]


## 카드 공통: 위쪽 밝은 진열대에 큰 그림, 아래에 이름 · 한 줄 설명 · 큰 가격. 왼쪽 위 딱지(중고 · 담음 · 잠김)
func card_frame(r: Array, hot: bool, tint: Color) -> Array:
	frame("ui_panel", r, tint if hot else Color.WHITE)
	var img := [r[0] + 10, r[1] + 78, r[2] - 10, r[3] - 10]   # 아래 두 줄(이름+가격 / 설명) 자리 고정
	box(img, Color8(48, 38, 96))
	box([img[0], img[1], img[2], img[1] + 6], Color8(36, 28, 74))   # 진열대 그림자
	return img


func tag(x: float, y: float, s: String, c: Color) -> void:
	var w := text_w(s, 22) + 14   # 어두운 바탕 + 색 테두리 + 색 글씨 (진한 색 덩어리 대신)
	box([x, y - 14, x + w, y + 14], Color(0.08, 0.06, 0.16, 0.85))
	outline([x, y - 14, x + w, y + 14], c, 2.0)
	text(x + 7, y, s, 22, c)


func draw_offer(i: int, key: String) -> void:
	var r := card_rect(i)
	var o := offer(key)
	var p: Dictionary = DB.PARTS[o["id"]]
	var img := card_frame(r, pending == o["key"], GOLD)
	fit(icon_of(o["id"]), (img[0] + img[2]) / 2.0, (img[1] + img[3]) / 2.0, (img[2] - img[0]) * 0.55, (img[3] - img[1]) * 0.8)
	tag(img[0] + 6, img[3] - 20, "중고", PINK)
	var off := roundi(100 - 100.0 * o["price"] / p["price"])
	info(r, p["name"], "%d만" % o["price"], o["claim"], "-%d%%" % off, INK)


func draw_card(i: int, id: String) -> void:
	if id.begins_with("o"):
		draw_offer(i, id)
		return
	var r := card_rect(i)
	var p := DB.spec(id)
	var locked := not Game.unlocked(p)
	var img := card_frame(r, Game.cart.has(id), CYAN)
	if locked:
		box(img, Color8(24, 18, 44))
	fit(icon_of(id), (img[0] + img[2]) / 2.0, (img[1] + img[3]) / 2.0, (img[2] - img[0]) * 0.55, (img[3] - img[1]) * 0.8)
	if locked:
		box(img, Color(0.05, 0.03, 0.1, 0.6))
		tag(img[0] + 6, img[3] - 20, "잠김", Color8(120, 110, 160))
	elif Game.cart.has(id):
		tag(img[0] + 6, img[3] - 20, "담음 %d" % Game.cart[id], CYAN)
	elif Game.stock.get(id, 0) > 0:
		tag(img[0] + 6, img[3] - 20, "창고 %d" % Game.stock[id], Color8(150, 140, 190))
	info(r, p["name"], "%d만" % p["price"] if not locked else "", short_spec(id) if not locked else "해금 %d만" % DB.UPGRADES[p["line"]]["price"], "", DIM if locked else INK)


## 카드 아래 두 줄: [이름 ······ 가격] / [설명 ······ 할인]. 글자 크기 22~26으로 통일, 서로 안 겹치게 폭을 나눔
func info(r: Array, name: String, price: String, sub: String, badge: String, ink: Color) -> void:
	var w: float = r[2] - r[0] - 28
	var pw := text_w(price, 26) + 10 if price != "" else 0.0
	var low := text_w(name, 22) > w - pw   # 이름이 길면 가격을 아랫줄로 (글자 줄이기 대신)
	if low:
		badge = price
	elif price != "":
		text(r[2] - 14 - text_w(price, 26), r[1] + 54, price, 26, GOLD)
	text(r[0] + 14, r[1] + 54, wrap_text(name, w if low else w - pw)[0], 22, ink)
	var bs := 26 if low else 22
	var bw := text_w(badge, bs) + 10 if badge != "" else 0.0
	text(r[0] + 14, r[1] + 22, wrap_text(sub, w - bw)[0], 22, QUIET)
	if badge != "":
		text(r[2] - 14 - text_w(badge, bs), r[1] + 22, badge, bs, GOLD if low else PINK)


func draw_cart() -> void:
	panel(CART, true)
	var ids := Game.cart.keys()
	var count := 0
	for id in ids:
		count += Game.cart[id]
	text(CART[0] + 14, CART[3] - 30, "장바구니 %d개" % count, 22, PINK)
	if ids.is_empty():
		text(CART[0] + 14, CART[3] - 76, "상품을 누르면", 22, QUIET)
		text(CART[0] + 14, CART[3] - 106, "자세히 보고 담아요", 22, QUIET)
		text(CART[0] + 14, CART[3] - 136, "두 번: 바로 담기", 22, DIM)
	clamp_cart()
	for i in min(ids.size() - cart_top, CART_ROWS):
		var r := cart_row(i)
		var id: String = ids[cart_top + i]
		var p := DB.spec(id)
		frame("ui_slot", r)
		box([r[0] + 6, r[1] + 8, r[0] + 40, r[3] - 8], Color8(90, 30, 60))
		text_c([r[0] + 6, r[1], r[0] + 40, r[3]], "−", 22, PINK)
		fit(icon_of(id), r[0] + 66, (r[1] + r[3]) / 2.0, 40, 40)
		text(r[0] + 92, r[3] - 18, wrap_text(p["name"], r[2] - r[0] - 100)[0], 22)
		text(r[0] + 92, r[1] + 18, "%d만 × %d" % [p["price"], Game.cart[id]], 22, GOLD)
	if ids.size() > CART_ROWS:   # 스크롤: ▲▼ 버튼 · 마우스 휠, 오른쪽에 위치 막대
		text(CART[0] + 14, 216, "%d~%d / %d종" % [cart_top + 1, cart_top + CART_ROWS, ids.size()], 22, QUIET)
		button(BTN_CUP, "▲", VIOLET if cart_top > 0 else DIM)
		button(BTN_CDOWN, "▼", VIOLET if cart_top < ids.size() - CART_ROWS else DIM)
		var top_y: float = cart_row(0)[3]
		var bot_y: float = cart_row(CART_ROWS - 1)[1]
		var h: float = (top_y - bot_y) * CART_ROWS / ids.size()
		var y0: float = top_y - (top_y - bot_y - h) * cart_top / (ids.size() - CART_ROWS) - h
		box([CART[2] - 8, bot_y, CART[2] - 4, top_y], Color8(40, 32, 70))
		box([CART[2] - 8, y0, CART[2] - 4, y0 + h], PINK)
	var total := Game.cart_total()
	text(CART[0] + 14, 172, "합계 %d만" % total, 22, GOLD)
	text(CART[0] + 14, 132, "가게 돈 %d만" % Game.money, 22, INK if Game.money >= total else PINK)
	button(BTN_PAY, "결제하기 %d만" % total if total else "결제하기", DIM if ids.is_empty() else PINK)


func draw() -> void:
	grid()
	for i in CATS.size():   # 고른 탭은 밝게 채우고, 나머지는 어둡게 (PC 쪽은 시안, 꾸미기는 분홍 계열)
		var on: bool = CATS[i][0] == cat
		var col: Color = CYAN if i < 1 else PINK
		var r := cat_rect(i)
		frame("ui_slot", r, Color8(110, 96, 170))
		if on:   # 고른 탭: 색 테두리 + 흰 글씨 + 밑줄 (채우기는 글씨가 묻혀서 안 씀)
			outline([r[0] + 2, r[1] + 2, r[2] - 2, r[3] - 2], col, 2.0)
			box([r[0] + 6, r[1] - 6, r[2] - 6, r[1] - 2], col)
		text_c(r, CATS[i][1], 22, INK if on else col.lerp(QUIET, 0.4))
	if cat == "parts":
		for i in PART_TYPES.size():
			var on: bool = PART_TYPES[i][0] == part_type
			var sr := sub_rect(i)
			frame("ui_slot", sr, Color8(90, 80, 140))
			if on:
				outline([sr[0] + 2, sr[1] + 2, sr[2] - 2, sr[3] - 2], GOLD, 2.0)
			text_c(sr, PART_TYPES[i][1], 22, GOLD if on else QUIET)
	var shown := visible()
	for i in shown.size():
		draw_card(i, shown[i])
	button(BTN_PREV, "◀", VIOLET)
	button(BTN_NEXT, "▶", VIOLET)
	text_c([96, 6, 232, 64], "%d / %d" % [page + 1, pages()], 22, QUIET)
	draw_cart()
	top_bar("shop")
	if toast != "":
		text(336, 36, toast, 22, PINK)


func clamp_cart() -> void:
	cart_top = clampi(cart_top, 0, maxi(0, Game.cart.size() - CART_ROWS))


func scroll_cart(d: int) -> void:
	cart_top += d
	clamp_cart()


## 마우스 휠: 장바구니 위에서 굴리면 스크롤
func wheel(x: float, y: float, d: int) -> void:
	if inside(x, y, CART):
		scroll_cart(d)
