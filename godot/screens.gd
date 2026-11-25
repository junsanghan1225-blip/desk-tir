## 단순한 화면들: 타이틀 · 하루 뉴스 · 손님 · 결과 · 영업 마감 · 상품 상세 · 영수증


class Title extends Mode:
	const BTN_CONTINUE := [124, 300, 524, 352]
	const BTN_NEW := [124, 230, 524, 282]
	const BTN_ALBUM := [544, 300, 704, 352]
	var saved := {}
	var message := ""

	func enter() -> void:
		saved = Game.peek()

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_ALBUM):
			sfx("click")
			m.push("album")
		elif not saved.is_empty() and inside(x, y, BTN_CONTINUE):
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
		button(BTN_ALBUM, "앨범", CYAN)
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
		sfx("door")

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
		if req.has("use"):
			text(420, 290, "용도 메모: " + Bench.describe(req["use"]), 22, CYAN)
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
		sfx("star" if result["stars"] else "sad")
		wanted = ["분위기: " + " · ".join(req["theme"].map(func(t): return DB.THEME_NAMES[t]))]   # 숨겨져 있던 조건 공개
		for r in req["required"]:
			wanted.append("꼭 필요: %s %d개" % ["/".join(r["any"].map(func(i): return DB.ITEMS[i]["name"])), r["count"]])
		if not req["forbidden"].is_empty():
			wanted.append("싫어함: " + ", ".join(req["forbidden"].map(func(i): return DB.ITEMS[i]["name"])))
		if req.has("use"):
			wanted.append("성능: " + Bench.short(Bench.run(Bench.parts_of(Game.pc), req["use"])) + "  (" + Bench.describe(req["use"]) + ")")
		else:
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
					sfx("buy")
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
			"CASE": rows = ["보드 %s까지 · 공기 흐름 %s" % [p["mb_max"], ["", "약함", "보통", "좋음"][p["airflow"]]], "그래픽카드 %dmm까지" % p["gpu_max"], "쿨러 높이 %dmm까지" % p["cooler_max"]]
			"MB": rows = ["소켓 %s · %s" % [p["socket"], p["size"]], "RAM 슬롯 %d개 · M.2 1개" % p["ram_slots"], "뒷면 USB %d개 · 오디오 2개" % p["usb"]]
			"CPU": rows = ["%d코어 · %.1fGHz · 소켓 %s" % [p["cores"], p["ghz"], p["socket"]], "게임 %dfps까지 · 멀티 점수 %d" % [p["game"], p["mt"]], "발열 %dW (쿨러가 버텨야 함)" % p["watt"]]
			"COOLER": rows = ["%dW까지 식힘 · 소음 +%ddB" % [p["tdp"], p["noise"]], "높이 %dmm" % p["height"]]
			"SSD": rows = ["용량 %s" % p["capacity"], "M.2 슬롯에 장착 · 없으면 부팅 불가"]
			"GPU": rows = ["1080p %dfps · VRAM %dGB" % [p["fps"], p["vram"]], "전력 %dW · 길이 %dmm · DP %d개" % [p["watt"], p["length"], p["dp"]], "보조 전원선 %d개 필요" % p["pcie"]]
			"RAM": rows = ["%dGB (게임은 16GB 이상)" % p["gb"], "같은 RAM 2장이면 듀얼 채널"]
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
				sfx("cart")
				m.pop()
			else:
				toast = "가게 업그레이드가 필요해요 (영업 마감 화면에서 구매)"
				sfx("error")
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


class Boot extends Mode:
	## 부팅 연출 (조립 화면 위): 바이오스 글자가 한 줄씩 → 바탕화면. 눌러서 닫기.
	const SCREEN := [240, 110, 1040, 610]
	const STEP := 0.35
	var t0 := 0

	func _init() -> void:
		overlay = true

	func open() -> void:
		t0 = Time.get_ticks_msec()
		m.push("boot")

	func t() -> float:
		return (Time.get_ticks_msec() - t0) / 1000.0

	func lines() -> Array:
		var pc := Game.pc
		var ram := " + ".join(pc.ram.filter(func(r): return r != "").map(func(r): return DB.PARTS[r]["name"].replace("RAM ", "")))
		return ["DESK-BIOS v1.0", "CPU   %s ... OK" % pc.spec("CPU")["name"], "RAM   %s%s ... OK" % [ram, " (듀얼 채널)" if pc.dual_channel() else ""],
			"VGA   %s ... OK" % pc.spec("GPU")["name"], "M.2   %s ... OK" % pc.spec("SSD")["name"], "부팅 중 ..."]

	func down(_x: float, _y: float, _right: bool) -> void:
		if t() > 0.3:
			m.pop()

	func draw() -> void:
		var s := SCREEN
		dim()
		frame("ui_panel", grow(s, 18))   # 모니터 테두리
		box(s, Color8(4, 4, 10))
		var bios := lines()
		if t() < STEP * (bios.size() + 1.5):
			for i in min(bios.size(), int(t() / STEP) + 1):
				text(s[0] + 30, s[3] - 40 - i * 34, bios[i], 18, GREEN)
			return
		put("title_bg", s)   # 바탕화면
		var icons := [["내 PC", CYAN], ["게임", PINK], ["작업", GOLD]]
		for i in icons.size():
			frame("ui_button", [s[0] + 30, s[3] - 96 - i * 90, s[0] + 84, s[3] - 40 - i * 90], icons[i][1])
			text(s[0] + 26, s[3] - 110 - i * 90, icons[i][0], 16, Color.WHITE)
		box([s[0], s[1], s[2], s[1] + 36], Color8(18, 12, 38))
		var pc := Game.pc
		text(s[0] + 14, s[1] + 18, "성능 %s  ·  전력 %dW / %dW" % ["★".repeat(pc.stars()) if pc.stars() else "-", pc.watt(), pc.capacity()], 16)
		text(s[2] - 150, s[1] + 18, "눌러서 닫기", 16, QUIET)


class Pause extends Mode:
	## 일시정지 (ll 버튼 · ESC · 안드로이드 뒤로). 주문 중이면 손님이 한 말을 다시 보여 준다.
	const BOX := [340, 140, 940, 600]
	const BUTTONS := [["resume", "계속하기"], ["title", "타이틀로"], ["quit", "게임 종료"]]

	func _init() -> void:
		overlay = true

	func btn_rect(i: int) -> Array:
		var y := 330 - i * 64
		return [440, y - 46, 840, y]

	func in_order() -> bool:
		return m.stack.size() > 1 and m.stack[0] in [m.modes["shop"], m.modes["desk"], m.modes["build"], m.modes["wire"]]

	func down(x: float, y: float, _right: bool) -> void:
		for i in BUTTONS.size():
			if inside(x, y, btn_rect(i)):
				sfx("click")
				match BUTTONS[i][0]:
					"resume": m.pop()
					"title": m.go("title")
					_: m.get_tree().quit()

	func draw() -> void:
		dim()
		panel(BOX, true)
		text(BOX[0] + 30, BOX[3] - 40, "일시정지", 28, PINK)
		if in_order():
			var req := Game.request()
			text(BOX[0] + 30, BOX[3] - 84, "%s의 주문" % req["customer"], 16, QUIET)
			var lines := Game.lines()
			for i in lines.size():
				text(BOX[0] + 30, BOX[3] - 116 - i * 30, "\"%s\"" % lines[i], 17)
			text(BOX[0] + 30, BOX[3] - 116 - lines.size() * 30, "예산 %d만 원" % req["budget"], 16, GOLD)
			if req.has("use"):
				text(BOX[0] + 30, BOX[3] - 146 - lines.size() * 30, Bench.describe(req["use"]), 22, CYAN)
		for i in BUTTONS.size():
			button(btn_rect(i), BUTTONS[i][1], PINK if i == 0 else VIOLET)


class Album extends Mode:
	## 앨범: 납품할 때 자동으로 찍힌 책상 사진 + 직접 찍은 사진 (user://photos)
	const COLS := 3
	const ROWS := 2
	const TW := 370
	const TH := 216
	const BTN_PREV := [500, 20, 560, 60]
	const BTN_NEXT := [720, 20, 780, 60]
	const BTN_BACK := [1060, 20, 1260, 60]
	var files: Array = []
	var page := 0
	var cache := {}

	func enter() -> void:
		page = 0
		files = Array(DirAccess.get_files_at(Main.PHOTOS)).filter(func(f): return f.ends_with(".png"))
		files.sort_custom(func(a, b): return FileAccess.get_modified_time(Main.PHOTOS + "/" + a) > FileAccess.get_modified_time(Main.PHOTOS + "/" + b))

	func pages() -> int:
		return max(1, ceili(files.size() / float(COLS * ROWS)))

	func thumb(i: int) -> Array:
		var x := 50 + (i % COLS) * (TW + 30)
		var y2 := 620 - (i / COLS) * (TH + 64)
		return [x, y2 - TH, x + TW, y2]

	func caption(f: String) -> String:
		var n := f.get_basename()
		if n.begins_with("day"):
			var p := n.substr(3).split("_")
			return "%s일차 손님 %s 납품" % [p[0], p[1]]
		return "직접 찍은 사진"

	func tex(f: String) -> Texture2D:
		if not cache.has(f):
			cache[f] = ImageTexture.create_from_image(Image.load_from_file(Main.PHOTOS + "/" + f))
		return cache[f]

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_BACK):
			m.pop()
		elif inside(x, y, BTN_PREV):
			page = max(0, page - 1)
		elif inside(x, y, BTN_NEXT):
			page = min(pages() - 1, page + 1)

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		text(50, 680, "앨범  ·  사진 %d장" % files.size(), 26, PINK)
		if files.is_empty():
			text(50, 600, "아직 사진이 없어요. 납품하면 자동으로 찍히고, 책상 화면의 '사진' 버튼으로 직접 찍을 수 있어요.", 17, QUIET)
		var per := COLS * ROWS
		var shown := files.slice(page * per, (page + 1) * per)
		for i in shown.size():
			var r := thumb(i)
			panel(grow(r, 10), true)
			m.draw_texture_rect(tex(shown[i]), _rect(r), false)
			text(r[0], r[1] - 26, caption(shown[i]), 16)
		button(BTN_PREV, "◀", VIOLET)
		button(BTN_NEXT, "▶", VIOLET)
		text(600, 40, "%d / %d" % [page + 1, pages()], 16, QUIET)
		button(BTN_BACK, "돌아가기", PINK)


class BenchView extends Mode:
	## 성능 테스트 (조립 화면 위): 숫자를 몰라도 한눈에 — 속도계 바늘, 시간에 따른 FPS 그래프, 발목(병목) 막대, 온도계, 소음계.
	const BOX := [40, 24, 1240, 680]
	const BTN_CLOSE := [1060, 596, 1224, 664]
	const GRAPH := [420, 336, 1210, 560]
	const N := 40
	var t0 := 0
	var r := {}
	var fixit := {}
	var pts := []

	func _init() -> void:
		overlay = true

	func open() -> void:
		var use: Dictionary = Game.request().get("use", {"kind": "office"})
		r = Bench.run(Bench.parts_of(Game.pc), use)
		fixit = Bench.fix(Bench.parts_of(Game.pc), use, Game.unlocked) if not r["ok"] and not r.get("shutdown", false) else {}
		pts = Bench.series(r, N) if r["kind"] == "game" and r["value"] > 0 else []
		t0 = Time.get_ticks_msec()
		m.push("bench")
		sfx("boot_ok" if r["ok"] else "click")

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_CLOSE) or not inside(x, y, BOX):
			m.pop()

	func k() -> float:   # 0 → 1: 테스트 진행 (2초)
		return clampf((Time.get_ticks_msec() - t0) / 2000.0, 0.0, 1.0)

	func hbar(y: float, label: String, v: float, scale: float, hot: bool, tag: String) -> void:
		text(GRAPH[0], y, label, 22, INK)
		var x0 := 700.0
		var w: float = GRAPH[2] - x0
		box([x0, y - 18, GRAPH[2], y + 18], Color8(30, 22, 60))
		box([x0, y - 18, x0 + w * minf(1.0, v / scale) * k(), y + 18], PINK if hot else CYAN)
		text(x0 + 10, y, tag, 22, Color.WHITE)

	func draw_graph() -> void:
		var g := GRAPH
		box(g, Color8(14, 10, 32))
		outline(g, DIM)
		var top: float = maxf(r["target"] * 1.3, pts.max() * 1.1)
		var yy := func(v: float) -> float: return g[1] + (g[3] - g[1]) * v / top
		var ty: float = yy.call(r["target"])
		for x in range(int(g[0]), int(g[2]), 24):   # 점선 목표선
			box([x, ty - 1.5, x + 12, ty + 1.5], GOLD)
		text(g[2] - text_w("목표 %d" % r["target"], 22) - 6, ty + 18, "목표 %d" % r["target"], 22, GOLD)
		var n: int = maxi(2, int(N * k()))
		var line_pts := []
		for i in n:
			line_pts.append(Vector2(g[0] + (g[2] - g[0]) * i / float(N - 1), yy.call(pts[i])))
		polyline(line_pts, GREEN if r["ok"] else PINK, 4)
		circle(line_pts[-1].x, line_pts[-1].y, 7, Color.WHITE)
		text(g[0], g[3] + 24, "FPS 변화 (게임 30초)", 22, QUIET)
		var why := "  ↓ 뚝 끊김 = RAM 부족" if r.get("ram_low", false) else "  ↘ 점점 느려짐 = 과열" if r.get("throttle", false) else ""
		text(g[0] + 260, g[3] + 24, why, 22, PINK)

	func draw() -> void:
		dim()
		panel(BOX, true)
		var use: Dictionary = Game.request().get("use", {"kind": "office"})
		text(70, 646, "성능 테스트", 33, PINK)
		text(70, 606, "손님 요구: " + Bench.describe(use), 22, CYAN)
		button(BTN_CLOSE, "닫기", VIOLET)
		if r.get("shutdown", false) or r["value"] == 0.0 and r["kind"] != "office":
			var y := 520.0
			for ln in wrap_text(r["notes"][0] if not r["notes"].is_empty() else "", 1100):
				text(70, y, ln, 33, PINK)
				y -= 44
			return
		var kk := k()
		# 1) 속도계: 게임은 클수록, 시간은 작을수록 좋음. 사무용은 소음계.
		match r["kind"]:
			"game": gauge(230, 400, 120, r["value"] / (r["target"] * 1.6) * kk, 1 / 1.6, true, "%d" % roundi(r["value"] * kk), "FPS", "목표 %d" % r["target"])
			"render": gauge(230, 400, 120, r["value"] / (r["target"] * 2.0) * kk, 0.5, false, "%.1f" % (r["value"] * kk), "분 걸림", "목표 %d분" % r["target"])
			"code": gauge(230, 400, 120, r["value"] / (r["target"] * 2.0) * kk, 0.5, false, "%d" % roundi(r["value"] * kk), "초 걸림", "목표 %d초" % r["target"])
			_:
				var q: float = use.get("quiet", 40)
				gauge(230, 400, 120, r["noise"] / (q * 1.6) * kk, 1 / 1.6, false, "%d" % roundi(r["noise"] * kk), "dB 소음", "기준 %d" % q)
		# 2) 오른쪽: 게임은 FPS 그래프 + 발목 막대, 시간 작업은 목표 대비 막대
		match r["kind"]:
			"game":
				draw_graph()
				var scale: float = maxf(r["target"] * 1.4, maxf(r["cpu_fps"], r["gpu_fps"]))
				hbar(284, "CPU 한계", r["cpu_fps"], scale, r["limit"] == "CPU", "%dfps" % r["cpu_fps"] + ("  ← 발목" if r["limit"] == "CPU" else ""))
				hbar(238, "그래픽카드 한계", r["gpu_fps"], scale, r["limit"] != "CPU", "%dfps" % r["gpu_fps"] + ("  ← 발목" if r["limit"] != "CPU" else ""))
			"render", "code":
				var scale: float = maxf(r["value"], r["target"]) * 1.3
				hbar(500, "걸리는 시간", r["value"], scale, r["value"] > r["target"], Bench.value_text(r))
				hbar(440, "손님 목표", r["target"], scale, false, {"render": "%d분", "code": "%d초"}[r["kind"]] % r["target"])
				text(GRAPH[0], 380, "CPU 코어가 많을수록 짧아져요 (지금 %d코어)" % DB.PARTS[Game.pc.parts["CPU"]].get("cores", 0), 22, QUIET)
			_:
				text(GRAPH[0], 500, "켜지기만 하면 되는 손님이에요.", 22, INK)
				text(GRAPH[0], 460, "소음만 기준보다 조용하면 OK", 22, QUIET)
		# 3) 왼쪽 아래: 온도계 2개 + 소음 막대
		thermo(90, 70, 120, r["cpu_temp"] * kk, "CPU")
		thermo(200, 70, 120, r["gpu_temp"] * kk, "그래픽")
		var q2: float = use.get("quiet", 40)
		var loud: bool = r["noise"] > q2
		text(286, 36, "소음", 22, INK)
		for i in 6:   # 소리 막대 (높을수록 시끄러움)
			var on: bool = i < int(6 * minf(1.0, r["noise"] / 50.0) * kk + 0.5)
			box([290 + i * 18, 70, 302 + i * 18, 82 + i * 18], (PINK if loud else CYAN) if on else Color8(30, 22, 60))
		text(286, 200, "%ddB" % r["noise"], 22, PINK if loud else INK)
		if kk < 1.0:
			text(GRAPH[0], 180, "테스트 중" + ".".repeat(int((Time.get_ticks_msec() - t0) / 250) % 4), 33, QUIET)
			return
		# 4) 판정 + 쉬운 말 + 가장 싼 해결책
		text(70, 240, "✓ 목표 달성!" if r["ok"] else "✗ 못 미쳐요", 33, GREEN if r["ok"] else PINK)
		var ny := 186.0
		for n in r["notes"].slice(0, 3):
			for ln in wrap_text("· " + n, 800):
				text(GRAPH[0], ny, ln, 22, QUIET)
				ny -= 30
		var tip := ""
		if not fixit.is_empty():
			var p: Dictionary = DB.PARTS[fixit["id"]]
			var what: String = {"CPU": "CPU", "GPU": "그래픽카드", "RAM": "RAM", "COOLER": "쿨러", "CASE": "케이스"}[fixit["type"]]
			var with_mb: String = " + %s" % DB.PARTS[fixit["mb"]]["name"] if fixit.get("mb", "") != "" else ""
			tip = "추천: %s → %s%s(%d만)면 %s, 목표 달성" % [what, p["name"], with_mb, fixit["cost"], Bench.value_text({"kind": r["kind"], "value": fixit["value"]})]
		elif not r["ok"]:
			tip = "한 부품만 바꿔선 어려워요. 빨간 막대(발목)부터 바꿔 보세요."
		for ln in wrap_text(tip, 800):
			text(GRAPH[0], ny - 6, ln, 22, GOLD)
			ny -= 30


class Trial extends Mode:
	## 납품 직후: 손님이 직접 PC를 써 본다. 게임은 계산된 FPS만큼 부드럽거나 끊기고, 렌더 · 빌드는 진행 막대, 사무는 화상회의.
	const SCREEN := [380, 170, 1240, 610]
	var t0 := 0
	var r := {}
	var boot := true

	func enter() -> void:
		var use: Dictionary = Game.request().get("use", {"kind": "office"})
		boot = Game.pc.post()[0] == 4
		r = Bench.run(Bench.parts_of(Game.pc), use)
		t0 = Time.get_ticks_msec()

	func t() -> float:
		return (Time.get_ticks_msec() - t0) / 1000.0

	func down(_x: float, _y: float, _right: bool) -> void:
		if t() > 1.0:
			m.go("result")

	func reaction() -> Array:   # [기분, 한마디]
		if not boot or r.get("shutdown", false):
			return ["sad", "어… 화면이 안 나와요?"]
		var bad: bool = r.get("ram_low", false) and r["kind"] == "game"
		match r["kind"]:
			"game":
				if r["ok"] and not bad: return ["happy", "와, 엄청 부드러워요!"] if r["ratio"] >= 1.3 else ["happy", "딱 원하던 느낌이에요."]
				return ["sad", "자꾸 멈칫해요…"] if bad else ["neutral" if r["ratio"] >= 0.75 else "sad", "음… 좀 버벅이네요."]
			"render", "code":
				return ["happy", "벌써 끝났어요?"] if r["ok"] else ["neutral", "기다리는 게 좀 길어요…"]
		if not r["ok"]:
			return ["neutral", "좀 시끄럽네요…"]
		return ["happy", "조용하고 좋네요."]

	func draw() -> void:
		box([0, 0, 1280, 720], BG)
		var req := Game.request()
		text(40, 670, "%s 님이 써 보는 중" % req["customer"], 33, PINK)
		text(40, 628, Bench.describe(req.get("use", {"kind": "office"})), 22, CYAN)
		frame("ui_panel", [SCREEN[0] - 14, SCREEN[1] - 14, SCREEN[2] + 14, SCREEN[3] + 14])
		if not boot or r.get("shutdown", false):
			box(SCREEN, Color8(6, 5, 12))
		else:
			draw_app(SCREEN, r, t())
		var rx := reaction()
		var shown: bool = t() > 2.5
		panel([40, 300, 340, 600], true)
		put("face_%s_%s" % [req["face"], rx[0] if shown else "neutral"], [60, 320, 320, 580])
		if shown:
			panel([40, 150, 340, 280], true)
			var y := 240.0
			for ln in wrap_text(rx[1], 270):
				text(56, y, ln, 22, INK)
				y -= 30
			text_c([0, 40, 1280, 110], "누르면 결과 보기", 22, QUIET)
