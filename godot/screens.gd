## 단순한 화면들: 타이틀 · 하루 뉴스 · 손님 · 결과 · 영업 마감 · 상품 상세 · 영수증


class Title extends Mode:
	const BTN_CONTINUE := [124, 300, 524, 352]
	const BTN_NEW := [124, 230, 524, 282]
	var saved := {}
	var message := ""

	func enter() -> void:
		saved = Game.peek()

	func down(x: float, y: float, _right: bool) -> void:
		if not saved.is_empty() and inside(x, y, BTN_CONTINUE):
			m.go(Game.load_save())
		elif inside(x, y, BTN_CONTINUE if saved.is_empty() else BTN_NEW):
			Game.delete_save()
			Game.new_game()
			m.go("news")

	func draw() -> void:
		spr("title_bg", 640, 360)
		text(120, 470, "데스크테리어 의뢰소", 64, PINK)
		text(124, 400, "손님의 애매한 주문을 읽고, 책상을 꾸미고 PC를 조립해 주세요", 22, Color8(200, 192, 240))
		if saved.is_empty():
			button(BTN_CONTINUE, "새 게임 시작", PINK)
		else:
			button(BTN_CONTINUE, "이어하기  ·  %d일차 · 가게 돈 %d만" % [saved["day"], saved["money"]], PINK)
			button(BTN_NEW, "새 게임 (저장 기록이 지워져요)", VIOLET)
		frame("ui_slot", [112, 176, 400, 216])
		text(124, 196, "진행은 자동으로 저장돼요", 15, Color8(200, 192, 240))
		if message != "":
			text(124, 610, message, 20, GREEN)


class News extends Mode:
	const WEATHER := {"rain": "비", "night": "맑은 밤", "sunset": "노을", "snow": "눈", "sunny": "맑음"}

	func enter() -> void:
		Game.start_day()

	func down(_x: float, _y: float, _right: bool) -> void:
		m.go("request")

	func draw() -> void:
		var d := Game.today()
		box([0, 0, 1280, H], BG)
		m.draw_texture_rect_region(DB.tex("room_bg_" + d["weather"]), Rect2(120, H - 603, 1040, 266), Rect2(28, 242, 744, 190))  # 창밖 풍경만 크게
		text(120, 660, "%d일차 아침  ·  오늘 날씨: %s" % [Game.day, WEATHER[d["weather"]]], 24, CYAN)
		panel([120, 180, 1160, 310], true)
		text(150, 270, d["news"], 22)
		text(150, 222, d["hint"], 17, GOLD)
		text(120, 130, "가게 돈 %d만 원  ·  가게 레벨 %d  ·  오늘 손님 %d명" % [Game.money, Game.level(), Game.todays_requests().size()], 17, QUIET)
		text(120, 80, "화면을 눌러 가게 열기", 18, DIM)


class Request extends Mode:
	func enter() -> void:
		Game.reset_order()

	func down(_x: float, _y: float, _right: bool) -> void:
		m.go("shop")

	func mood() -> String:
		var req := Game.request()
		if not req.get("returns", false):
			return "neutral"
		return "happy" if Game.history.get(req["customer"], 0) >= 2 else "sad"

	func draw() -> void:
		var req := Game.request()
		box([0, 0, 1280, H], BG)
		text(80, 650, "%d일차  ·  손님 %d/%d" % [Game.day, Game.order_index + 1, Game.todays_requests().size()], 20, CYAN)
		panel([68, 288, 372, 612], true)
		spr("face_%s_%s" % [req["face"], mood()], 220, 450)
		text(80, 260, req["customer"], 30)
		if req.get("returns", false):
			frame("ui_button", [76, 202, 200, 240], GOLD)
			text(92, 221, "단골 손님", 15, BG)
		panel([420, 330, 1200, 600])
		var lines := Game.lines()
		for i in lines.size():
			text(460, 550 - i * 56, "\"%s\"" % lines[i] if i == 0 else lines[i], 24)
		text(460, 380, "예산은 %d만 원 정도 생각하고 있어요." % req["budget"], 20, GOLD)
		text(420, 200, "무엇을 원하는지 말 속에서 찾아보세요.", 18, QUIET)
		text(420, 120, "화면을 눌러 주문 받기 → 쇼핑으로", 18, DIM)


class Result extends Mode:
	var result := {}
	var pay := 0
	var tip := 0
	var cost := 0
	var wanted: Array = []

	func enter() -> void:
		Game.cables = Rules.prune(Game.cables, Game.placed, Game.pc)
		var req := Game.request()
		cost = Game.spent()
		result = Rules.score(req, Game.placed, Game.pc, Game.cables)
		var paid := Game.settle(result)
		pay = paid[0]
		tip = paid[1]
		wanted = ["분위기: " + " · ".join(req["theme"].map(func(t): return DB.THEME_NAMES[t]))]   # 숨겨져 있던 조건 공개
		for r in req["required"]:
			wanted.append("꼭 필요: %s %d개" % ["/".join(r["any"].map(func(i): return DB.ITEMS[i]["name"])), r["count"]])
		if not req["forbidden"].is_empty():
			wanted.append("싫어함: " + ", ".join(req["forbidden"].map(func(i): return DB.ITEMS[i]["name"])))
		wanted.append("PC 성능: " + "★".repeat(req["perf"]) + " 이상")

	func down(_x: float, _y: float, _right: bool) -> void:
		m.go("request" if Game.next_customer() else "day_end")

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		text(120, 640, Game.request()["customer"], 24, Color8(200, 192, 240))
		text(120, 575, "★".repeat(result["stars"]) + "☆".repeat(3 - result["stars"]), 60, GOLD)
		text(420, 575, "%d점" % result["total"], 48, Color.WHITE)
		var i := 0
		for k in result["parts"]:
			text(120, 490 - i * 40, k, 19, Color8(200, 192, 240))
			text(320, 490 - i * 40, "%d / %d" % [round(result["parts"][k]), Rules.MAX[k]], 19, Color.WHITE)
			i += 1
		text(120, 220, "달성 시너지: " + (", ".join(result["synergies"]) if not result["synergies"].is_empty() else "없음"), 17, GREEN)
		text(120, 180, "받은 돈  %d만 + 팁 %d만%s" % [pay, tip, "" if result["stars"] > 0 else "  (별 0개: 손님이 돈을 안 냄)"], 20, CYAN)
		var margin := pay + tip - cost
		text(120, 148, "물건 값 %d만  →  이번 주문 마진 %+d만" % [cost, margin], 18, GREEN if margin >= 0 else PINK)
		var mood := "happy" if result["stars"] == 3 else "neutral" if result["stars"] > 0 else "sad"
		panel([628, 458, 792, 632], true)
		put("face_%s_%s" % [Game.request()["face"], mood], [640, 470, 780, 620])
		panel([800, 470, 1250, 620], true)
		var rows := [""]
		for w in result["line"].split(" "):   # 말풍선 너비에 맞춰 줄바꿈
			if rows[-1].length() + w.length() > 20:
				rows.append("")
			rows[-1] = (rows[-1] + " " + w).strip_edges()
		for j in min(rows.size(), 4):
			text(820, 590 - j * 30, rows[j], 18)
		text(640, 430, "손님이 사실 원했던 것", 18, PINK)
		for j in wanted.size():
			text(640, 395 - j * 34, wanted[j], 17)
		text(120, 100, "화면을 눌러 다음 손님 받기" if Game.order_index + 1 < Game.todays_requests().size() else "화면을 눌러 영업 마감", 18, DIM)


class DayEnd extends Mode:
	const BTN_NEXT := [900, 30, 1240, 76]
	var toast := ""

	func up_rect(i: int) -> Array:
		return [120 + i * 420, 110, 520 + i * 420, 200]

	func enter() -> void:
		toast = ""

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_NEXT):
			if Game.day >= Game.last_day():
				m.modes["title"].message = "영업 %d일 완료! 최종 가게 돈 %d만 원" % [Game.last_day(), Game.money]
				Game.delete_save()
				m.go("title")
			else:
				Game.day += 1
				m.go("news")
			return
		var ids := DB.UPGRADES.keys()
		for i in ids.size():
			if inside(x, y, up_rect(i)):
				var up: Dictionary = DB.UPGRADES[ids[i]]
				if Game.upgrades.has(ids[i]):
					toast = "이미 들여놨어요"
				elif Game.level() < up["level"]:
					toast = "가게 레벨 %d부터 살 수 있어요" % up["level"]
				elif not Game.buy_upgrade(ids[i]):
					toast = "돈이 부족해요"
				else:
					toast = "%s 완료! 내일부터 쇼핑몰에 새 상품이 들어와요" % up["name"]
					Game.save("day_end")

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		text(120, 670, "%d일차 영업 마감" % Game.day, 34, PINK)
		var lv := Game.level()
		text(700, 680, "가게 레벨 %d" % lv, 22, CYAN)
		frame("ui_slot", [692, 632, 1168, 668])
		if lv < Game.LEVELS.size():
			var prev: int = Game.LEVELS[lv - 1]
			var need: int = Game.LEVELS[lv]
			box([700, 640, 700 + 460.0 * (Game.stars_total - prev) / (need - prev), 660], CYAN)
			text(700, 622, "별 %d / %d  ·  팁 %d%% → %d%%" % [Game.stars_total, need, Game.TIP_RATE[lv - 1], Game.TIP_RATE[lv]], 14, QUIET)
		else:
			box([700, 640, 1160, 660], CYAN)
			text(700, 622, "최고 레벨 · 팁 %d%%" % Game.TIP_RATE[lv - 1], 14, QUIET)
		panel([120, 250, 1160, 600])
		var heads := [[160, "손님"], [500, "별점"], [650, "받은 돈"], [820, "물건 값"], [990, "마진"]]
		for h in heads:
			text(h[0], 570, h[1], 17, QUIET)
		var total := 0
		for i in Game.ledger.size():
			var row: Dictionary = Game.ledger[i]
			var y := 520 - i * 52
			var mg: int = row["pay"] + row["tip"] - row["cost"]
			total += mg
			text(160, y, row["customer"], 20)
			text(500, y, "★".repeat(row["stars"]) + "☆".repeat(3 - row["stars"]), 20, GOLD)
			text(650, y, "%d만" % (row["pay"] + row["tip"]), 20)
			text(820, y, "%d만" % row["cost"], 20, Color8(200, 192, 240))
			text(990, y, "%+d만" % mg, 20, GREEN if mg >= 0 else PINK)
		text(160, 285, "오늘 마진 %+d만 원   ·   가게 돈 %d만 원" % [total, Game.money], 22, CYAN)
		text(120, 222, "가게 업그레이드", 18, PINK)
		var ids := DB.UPGRADES.keys()
		for i in ids.size():
			var up: Dictionary = DB.UPGRADES[ids[i]]
			var r := up_rect(i)
			var owned: bool = Game.upgrades.has(ids[i])
			var locked: bool = Game.level() < up["level"]
			panel(r, owned)
			text(r[0] + 14, r[3] - 22, up["name"], 17, DIM if locked else INK)
			text(r[0] + 14, r[3] - 48, "보유 중" if owned else ("레벨 %d 필요" % up["level"] if locked else "%d만 원 · 눌러서 구매" % up["price"]), 14, GOLD)
			text(r[0] + 14, r[3] - 74, up["desc"].left(22), 12, QUIET)
		if toast != "":
			text(120, 60, toast, 16, PINK)
		button(BTN_NEXT, "타이틀로" if Game.day >= Game.last_day() else "다음 날 영업", PINK)


class Product extends Mode:
	const BOX := [180, 90, 1100, 610]
	const BTN_MINUS := [640, 150, 690, 196]
	const BTN_PLUS := [770, 150, 820, 196]
	const BTN_ADD := [840, 150, 1080, 196]
	const BTN_CLOSE := [1030, 560, 1090, 600]
	const BTN_SELL := [640, 210, 820, 246]
	const TYPE_NAMES := {"CASE": "케이스", "MB": "메인보드", "CPU": "CPU", "COOLER": "쿨러", "SSD": "SSD", "GPU": "그래픽카드", "RAM": "RAM", "PSU": "파워"}
	const PORT_NAMES := {"DP": "DP 케이블", "USB": "USB 케이블", "AUDIO": "오디오 케이블"}
	var id := ""
	var qty := 1
	var toast := ""

	func _init() -> void:
		overlay = true

	func open(thing: String) -> void:
		id = thing
		qty = 1
		toast = ""
		m.push("product")

	func spec_lines() -> Array:
		var p := DB.spec(id)
		if DB.ITEMS.has(id):
			var conn: String = "USB 동글 (무선)" if p.get("dongle", false) else PORT_NAMES.get(p.get("port", ""), "필요 없음")
			return ["놓는 곳  %s" % Rules.LAYER_NAMES[p["layer"]], "연결  " + conn, "분위기  " + " · ".join(p["tags"].map(func(t): return DB.THEME_NAMES[t]))]
		var rows: Array
		match p["type"]:
			"CASE": rows = ["보드 %s까지" % p["mb_max"], "그래픽카드 %dmm까지" % p["gpu_max"], "쿨러 높이 %dmm까지" % p["cooler_max"]]
			"MB": rows = ["소켓 %s · %s" % [p["socket"], p["size"]], "RAM 슬롯 %d개 · M.2 1개" % p["ram_slots"], "뒷면 USB %d개 · 오디오 2개" % p["usb"]]
			"CPU": rows = ["소켓 %s" % p["socket"], "성능 %d · 발열 %dW" % [p["perf"], p["watt"]]]
			"COOLER": rows = ["%dW까지 식힘" % p["tdp"], "높이 %dmm" % p["height"]]
			"SSD": rows = ["용량 %s" % p["capacity"], "M.2 슬롯에 장착 · 없으면 부팅 불가"]
			"GPU": rows = ["성능 %d · 전력 %dW" % [p["perf"], p["watt"]], "길이 %dmm · DP %d개" % [p["length"], p["dp"]], "보조 전원선 %d개 필요" % p["pcie"]]
			"RAM": rows = ["성능 +%d" % p["perf"], "같은 RAM 2장이면 듀얼 채널"]
			_: rows = ["용량 %dW" % p["capacity"], "그래픽카드 전원선 %d개" % p["pcie"]]
		return ["종류  " + TYPE_NAMES[p["type"]]] + rows

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_CLOSE) or not inside(x, y, BOX):
			m.pop()
		elif inside(x, y, BTN_MINUS):
			qty = max(1, qty - 1)
		elif inside(x, y, BTN_PLUS):
			qty = min(9, qty + 1)
		elif inside(x, y, BTN_ADD):
			if Game.add_to_cart(id, qty):
				m.pop()
			else:
				toast = "가게 업그레이드가 필요해요 (영업 마감 화면에서 구매)"
		elif inside(x, y, BTN_SELL):
			toast = "반품했어요 (산 값의 절반 환불)" if Game.sell_back(id) else "창고에 없어요"

	func draw() -> void:
		var p := DB.spec(id)
		dim()
		panel(BOX, true)
		frame("ui_slot", [210, 260, 600, 580])
		fit(icon_of(id), 405, 420, 340, 280)
		text(640, 560, p["name"], 28)
		text(640, 520, "%d만 원" % p["price"], 26, GOLD)
		text(640, 482, p["desc"], 15, Color8(200, 192, 240))
		var lines := spec_lines()
		for i in lines.size():
			text(640, 440 - i * 30, lines[i], 16)
		var have: int = Game.stock.get(id, 0)
		text(210, 230, "창고 보유 %d개  ·  장바구니 %d개" % [have, Game.cart.get(id, 0)], 15, CYAN)
		if have > 0:
			button(BTN_SELL, "반품 1개", VIOLET)
		button(BTN_MINUS, "−", VIOLET)
		text(722, 173, qty, 22)
		button(BTN_PLUS, "+", VIOLET)
		var locked := not Game.unlocked(p)
		button(BTN_ADD, "장바구니 담기  %d만" % (p["price"] * qty), DIM if locked else PINK)
		button(BTN_CLOSE, "X", DIM)
		if locked:
			text(840, 120, "업그레이드 필요", 14, PINK)
		if toast != "":
			text(210, 120, toast, 15, PINK)


class Receipt extends Mode:
	const BOX := [400, 80, 880, 640]
	const BTN_OK := [540, 100, 740, 146]
	var bought := {}

	func _init() -> void:
		overlay = true

	func show(r: Dictionary) -> void:
		bought = r
		m.push("receipt")

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_OK):
			m.pop()

	func draw() -> void:
		var ink := Color8(30, 24, 50)
		var quiet := Color8(110, 100, 140)
		dim()
		box(BOX, Color8(245, 242, 255))
		text(430, 600, "데스크몰 영수증", 24, ink)
		text(430, 570, "%d일차 · %s 주문용" % [Game.day, Game.request()["customer"]], 14, quiet)
		var ids: Array = bought["items"].keys()
		for i in min(ids.size(), 12):
			var p := DB.spec(ids[i])
			var n: int = bought["items"][ids[i]]
			text(430, 530 - i * 30, "%s × %d" % [p["name"], n], 16, ink)
			text(770, 530 - i * 30, "%d만" % (p["price"] * n), 16, ink)
		if ids.size() > 12:
			text(430, 230, "외 %d개" % (ids.size() - 12), 14, quiet)
		box([430, 206, 850, 208], quiet)
		text(430, 186, "결제 금액  %d만 원" % bought["total"], 20, ink)
		text(430, 160, "남은 가게 돈  %d만 원  ·  창고로 배송 완료" % Game.money, 14, quiet)
		button(BTN_OK, "확인", PINK)
