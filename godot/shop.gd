extends Mode
## 쇼핑 탭 (데스크몰): 카테고리 → 상품 카드 → 누르면 상세 → 장바구니 → 결제 → 영수증. 두 번 누르기 = 바로 담기.
## 폰 기준: 글씨 22px 이상, 누르는 곳 높이 54px 이상.

const CATS := [["parts", "PC 부품"], ["used", "중고"], ["screen", "화면"], ["input", "키보드"], ["light", "조명"], ["audio", "오디오"], ["plant", "식물"], ["decor", "소품"], ["wall", "벽"]]
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


func enter() -> void:
	toast = ""


func _key(id: String) -> int:
	return (0 if Game.unlocked(DB.spec(id)) else 100000) + Game.price_of(id)   # 살 수 있는 것 먼저, 싼 순


func products() -> Array:
	var ids: Array
	if cat == "used":   # 오늘의 중고 매물 전부
		return range(Game.offers().size()).map(func(k): return "o%d" % k)
	if cat == "parts":
		ids = DB.PARTS.keys().filter(func(p): return DB.PARTS[p]["type"] == part_type)
	else:
		ids = DB.ITEMS.keys().filter(func(i): return DB.ITEMS[i]["cat"] == cat)
	ids.sort_custom(func(a, b): return _key(a) < _key(b))
	if cat == "parts":   # 오늘의 중고 매물을 맨 앞에
		var os := Game.offers()
		for k in os.size():
			if DB.PARTS[os[k]["id"]]["type"] == part_type:
				ids.push_front("o%d" % k)
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
	return [12 + i * 104, 572, 110 + i * 104, 632]


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
				toast = "%s 담음" % DB.spec(shown[i])["name"] if added else "업그레이드가 필요해요"
				sfx("cart" if added else "error")
			else:
				m.modes["product"].open(shown[i])
			return
	var ids := Game.cart.keys()
	for i in min(ids.size(), CART_ROWS):
		if inside(x, y, cart_row(i)):
			Game.add_to_cart(ids[i], -1 if right or x < cart_row(i)[0] + 56 else 1)   # 왼쪽 − 칸 = 하나 빼기
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


func draw_offer(i: int, key: String) -> void:
	var r := card_rect(i)
	var o := offer(key)
	var p: Dictionary = DB.PARTS[o["id"]]
	panel(r, pending == o["key"])
	var img := [r[0] + 10, r[1] + 10, r[0] + 120, r[3] - 10]
	frame("ui_slot", img, GOLD)
	fit(icon_of(o["id"]), (img[0] + img[2]) / 2.0, (img[1] + img[3]) / 2.0, 96, img[3] - img[1] - 16)
	box([img[0], img[3] - 34, img[0] + 64, img[3]], PINK)
	text(img[0] + 8, img[3] - 17, "중고", 22, Color.WHITE)
	var tx: float = r[0] + 132
	text(tx, r[3] - 26, wrap_text(p["name"], r[2] - tx - 10)[0], 22, INK)
	text(tx, r[3] - 58, "%d만 · 새 %d만" % [o["price"], p["price"]], 22, GOLD)
	text(tx, r[1] + 22, "환불 · 보증 없음", 22, PINK)   # 중고의 단점: 안 되면 끝
	for k in mini(2, wrap_text("\"%s\"" % o["claim"], r[2] - tx - 10).size()):
		text(tx, r[3] - 92 - k * 28, wrap_text("\"%s\"" % o["claim"], r[2] - tx - 10)[k], 22, QUIET)


func draw_card(i: int, id: String) -> void:
	if id.begins_with("o"):
		draw_offer(i, id)
		return
	var r := card_rect(i)
	var p := DB.spec(id)
	var locked := not Game.unlocked(p)
	panel(r, Game.cart.has(id))
	var img := [r[0] + 10, r[1] + 10, r[0] + 120, r[3] - 10]
	frame("ui_slot", img)
	fit(icon_of(id), (img[0] + img[2]) / 2.0, (img[1] + img[3]) / 2.0, 96, img[3] - img[1] - 16)
	var tx: float = r[0] + 132
	var name_lines: Array = wrap_text(p["name"], r[2] - tx - 10).slice(0, 2)
	for k in name_lines.size():
		text(tx, r[3] - 26 - k * 28, name_lines[k], 22, DIM if locked else INK)
	var y: float = r[3] - 30 - name_lines.size() * 28
	text(tx, y - 6, "%d만 원" % p["price"], 22, DIM if locked else GOLD)
	var spec_lines: Array = wrap_text(short_spec(id), r[2] - tx - 10)
	for k in mini(2, spec_lines.size()):   # 사양은 두 줄까지 (잘리지 않게)
		text(tx, y - 38 - k * 28, spec_lines[k], 22, QUIET)
	if locked:
		text(tx, r[1] + 22, "업그레이드 필요", 22, PINK)
	elif Game.cart.has(id):
		text(tx, r[1] + 22, "담음 %d" % Game.cart[id], 22, PINK)
	elif Game.stock.get(id, 0) > 0:
		text(tx, r[1] + 22, "창고 %d" % Game.stock[id], 22, CYAN)


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
	for i in min(ids.size(), CART_ROWS):
		var r := cart_row(i)
		var p := DB.spec(ids[i])
		frame("ui_slot", r)
		text_c([r[0], r[1], r[0] + 50, r[3]], "−", 22, PINK)
		text(r[0] + 54, r[3] - 18, wrap_text(p["name"], r[2] - r[0] - 60)[0], 22)
		text(r[0] + 54, r[1] + 18, "%d만 × %d" % [p["price"], Game.cart[ids[i]]], 22, GOLD)
	if ids.size() > CART_ROWS:
		text(CART[0] + 14, 216, "외 %d종" % (ids.size() - CART_ROWS), 22, QUIET)
	var total := Game.cart_total()
	text(CART[0] + 14, 172, "합계 %d만" % total, 22, GOLD)
	text(CART[0] + 14, 132, "가게 돈 %d만" % Game.money, 22, INK if Game.money >= total else PINK)
	button(BTN_PAY, "결제하기 %d만" % total if total else "결제하기", DIM if ids.is_empty() else PINK)


func draw() -> void:
	grid()
	for i in CATS.size():
		var on: bool = CATS[i][0] == cat
		frame("ui_button", cat_rect(i), CYAN if on else Color8(80, 66, 140))
		text_c(cat_rect(i), CATS[i][1], 22, Color.WHITE if on else QUIET)
	if cat == "parts":
		for i in PART_TYPES.size():
			var on: bool = PART_TYPES[i][0] == part_type
			frame("ui_button", sub_rect(i), GOLD if on else Color8(60, 50, 110))
			text_c(sub_rect(i), PART_TYPES[i][1], 22, Color.WHITE if on else QUIET)
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
