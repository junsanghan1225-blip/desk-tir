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
		text(120, 150, "오늘의 목표: %s  (+%d만)" % [Game.daily()[0], Game.daily()[1]], 22, GREEN)
		text(120, 110, "가게 돈 %d만 원  ·  가게 레벨 %d  ·  오늘 손님 %d명" % [Game.money, Game.level(), Game.todays_requests().size()], 17, QUIET)
		text(120, 66, "화면을 눌러 가게 열기", 18, DIM)
		goal_line(self, 30)
		if Game.day == 1:   # 첫날 아침: 큰 목표 이야기
			box([120, 337, 1160, 603], Color(0.03, 0.02, 0.08, 0.82))
			var intro: Array = DB.STORY["intro"]
			for i in intro.size():
				text(150, 560 - i * 56, intro[i], 22 if i < intro.size() - 1 else 33, INK if i < intro.size() - 1 else GOLD)


	## 큰 목표 진행 막대 (아침 · 마감 화면 공통)
	static func goal_line(md: Mode, y: float, x := 700.0) -> void:
		var left: int = Game.last_day() - Game.day
		md.text(x, y, "가게 지키기  %d / %d만  ·  %s" % [Game.money, Game.goal(), "오늘이 마지막 날!" if left == 0 else "D-%d" % left], 22, GREEN if Game.goal_met() else Mode.GOLD)
		md.box([x, y - 32, x + 460, y - 24], Mode.DARK)
		md.box([x, y - 32, x + 460 * minf(1.0, float(Game.money) / Game.goal()), y - 24], Mode.GREEN if Game.goal_met() else Mode.GOLD)


class Request extends Mode:
	func enter() -> void:
		Game.reset_order()
		sfx("door")

	func down(_x: float, _y: float, _right: bool) -> void:
		var kind := Rules.kind_of(Game.request())
		m.modes["shop"].cat = "parts" if kind in ["pc", "full"] else "screen"
		m.go("build" if kind == "repair" else "shop")   # 수리는 맡긴 PC부터 열어 봄

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
		text(460, 380, ("수리비는 %d만 원 드릴게요." if req.has("repair") else "예산은 %d만 원 정도 생각하고 있어요.") % req["budget"], 20, GOLD)
		var kind := Rules.kind_of(req)
		var y := 290.0   # 조건은 숨기지 않고 다 보여 줌 (분위기만 손님 말로 짐작)
		if req.has("use") and kind != "desk":   # 데스크테리어는 손님 PC 그대로라 용도 메모 없음
			text(420, y, "용도 메모: " + Bench.describe(req["use"]), 22, CYAN)
			y -= 40
		var need := Game.need_text(req)
		if need != "":
			text(420, y, "꼭 필요: " + need, 22, GOLD)
			y -= 40
		if Game.dislike_text(req) != "":
			text(420, y, Game.dislike_text(req), 22, PINK)
			y -= 40
		if req.has("used"):   # 중고 정책
			var ok_used: bool = req["used"] == "ok"
			chip(420, y, "중고도 괜찮아요" if ok_used else "새 제품만", GREEN if ok_used else PINK)
		var lv := Game.difficulty(req)
		text(80, 170, "난이도 " + "★".repeat(lv) + "☆".repeat(3 - lv), 22, [GREEN, GOLD, PINK][lv - 1])
		var badge: Array = {"repair": ["수리 의뢰", PINK], "pc": ["PC 조립 의뢰", CYAN], "desk": ["데스크테리어 의뢰", GOLD], "full": ["PC + 데스크 의뢰", GREEN]}[kind]
		chip(76, 131, badge[0], badge[1])
		var info := []
		if req.has("repair"):
			info = ["맡긴 PC를 진단 화면에서 살펴보고 원인을 찾아요.", "손님 부품은 공짜, 새로 산 부품만 비용이에요."]
		elif kind == "pc":
			info = ["PC를 새로 맞춰요: 성능 · 조립 마감 · 모니터가 점수예요.", "분위기 소품은 점수에 안 들어가요."]
		elif kind == "full":
			info = ["PC도 맞추고 책상도 꾸며요: 성능 · 분위기 · 소품 · 모니터 모두 점수예요.", "예산 안에서 PC와 소품에 돈을 잘 나눠야 해요."]
		elif kind == "desk":
			info = ["책상을 꾸며요: 분위기 · 꼭 필요한 소품 · 조합 · 배선이 점수예요.", "PC는 손님이 쓰던 걸 그대로 써요 (조립 안 해도 돼요)."]
		for i in info.size():
			text(420, 150 - i * 30, info[i], 18, QUIET)
		text(420, 70, "화면을 눌러 주문 받기 → " + ("조립으로" if req.has("repair") else "쇼핑으로"), 18, DIM)


class Result extends Mode:
	var result := {}
	var pay := 0
	var tip := 0
	var cost := 0
	var wanted: Array = []

	func enter() -> void:
		Game.cables = Rules.prune(Game.cables, Game.placed, Game.computer())
		var req := Game.request()
		cost = Game.spent()
		result = Rules.score(req, Game.placed, Game.computer(), Game.cables)
		var paid := Game.settle(result)
		pay = paid[0]
		tip = paid[1]
		sfx("star" if result["stars"] else "sad")
		wanted = ["분위기: " + " · ".join(req["theme"].map(func(t): return DB.THEME_NAMES[t]))]   # 숨겨져 있던 조건 공개
		for r in req["required"]:
			wanted.append("꼭 필요: %s %d개" % ["/".join(r["any"].map(func(i): return DB.ITEMS[i]["name"])), r["count"]])
		if not req["forbidden"].is_empty():
			wanted.append("싫어함: " + ", ".join(req["forbidden"].map(func(i): return DB.ITEMS[i]["name"])))
		if Rules.kind_of(req) == "desk":
			pass   # 데스크테리어: 손님 PC 그대로라 성능 얘기 없음
		elif req.has("use"):
			wanted.append("성능: " + Bench.short(Bench.run(Bench.parts_of(Game.computer()), req["use"])) + "  (" + Bench.describe(req["use"]) + ")")
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
			text(320, 490 - i * 40, "%d / %d" % [round(result["parts"][k]), result["max"][k]], 19, Color.WHITE)
			i += 1
		text(120, 290, "달성 시너지: " + (", ".join(result["synergies"]) if not result["synergies"].is_empty() else "없음"), 22, GREEN)
		var y := 250.0   # 정산 내역: 무엇 때문에 깎이고 더해졌는지
		var margin := 0
		for b in Game.bill:
			if b[0] == "손님 예산" or b[1] != 0:
				text(120, y, b[0], 22, QUIET)
				var amt := ("%d만" % b[1]) if b[0] == "손님 예산" else ("%+d만" % b[1])
				text(560 - text_w(amt, 22), y, amt, 22, INK if b[0] == "손님 예산" else GREEN if b[1] > 0 else PINK)
				y -= 30
			margin += b[1]
		box([120, y + 8, 560, y + 10], QUIET)
		text(120, y - 14, "이번 주문 마진", 22, INK)
		var ms := "%+d만" % margin
		text(560 - text_w(ms, 26), y - 14, ms, 26, GREEN if margin >= 0 else PINK)
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
		if not Game.new_achv.is_empty():
			text(640, 100, "업적 달성! " + ", ".join(Game.new_achv.map(func(k): return "%s +%d만" % [Game.ACHV[k][0], Game.ACHV[k][2]])), 22, GOLD)
		text(640, 40, "화면을 눌러 다음 손님 받기" if Game.order_index + 1 < Game.todays_requests().size() else "화면을 눌러 영업 마감", 18, DIM)


class DayEnd extends Mode:
	const BTN_NEXT := [900, 30, 1240, 76]
	var toast := ""

	func up_rect(i: int) -> Array:
		return [120 + i * 420, 110, 520 + i * 420, 200]

	var daily_paid := 0

	func enter() -> void:
		toast = ""
		daily_paid = Game.claim_daily()
		if daily_paid:
			sfx("star")

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_NEXT):
			if Game.day >= Game.last_day():   # 마지막 날: 엔딩
				m.go("ending")
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
				elif not Game.buy_upgrade(ids[i]):
					toast = "돈이 부족해요"
				else:
					toast = "%s 해금! 쇼핑몰에 새 상품이 들어와요" % up["name"]
					sfx("buy")
					Game.save("day_end")

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		text(120, 684, "%d일차 영업 마감" % Game.day, 34, PINK)
		News.goal_line(self, 630, 120)
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
		var dd := Game.daily()
		text(700, 222, ("✓ 오늘의 목표 달성 +%d만" % dd[1]) if Game.stats.has("daily%d" % Game.day) else "✗ 오늘의 목표: " + dd[0], 22, GREEN if Game.stats.has("daily%d" % Game.day) else QUIET)
		text(120, 222, "모은 돈으로 해금", 18, PINK)
		var ids := DB.UPGRADES.keys()
		for i in ids.size():
			var up: Dictionary = DB.UPGRADES[ids[i]]
			var r := up_rect(i)
			var owned: bool = Game.upgrades.has(ids[i])
			var locked := false   # 레벨 제한 없음: 모은 가게 돈으로 해금
			panel(r, owned)
			text(r[0] + 14, r[3] - 22, up["name"], 17, DIM if locked else INK)
			text(r[0] + 14, r[3] - 48, "해금 완료" if owned else "%d만 원 · 눌러서 해금" % up["price"], 14, GOLD)
			text(r[0] + 14, r[3] - 74, up["desc"].left(22), 12, QUIET)
		if toast != "":
			text(120, 60, toast, 16, PINK)
		button(BTN_NEXT, "엔딩 보기" if Game.day >= Game.last_day() else "다음 날 영업", PINK)


class Product extends Mode:
	const BOX := [180, 90, 1100, 610]
	const BTN_MINUS := [640, 150, 690, 196]
	const BTN_PLUS := [770, 150, 820, 196]
	const BTN_ADD := [840, 150, 1080, 196]
	const BTN_CLOSE := [1030, 560, 1090, 600]
	const BTN_SELL := [640, 210, 820, 246]
	const TYPE_NAMES := {"CASE": "케이스", "MB": "메인보드", "CPU": "CPU", "COOLER": "쿨러", "SSD": "SSD", "GPU": "그래픽카드", "RAM": "RAM", "PSU": "파워"}
	const PORT_NAMES := {"HDMI": "HDMI 케이블", "DP": "DP 케이블", "USB": "USB 케이블", "AUDIO": "오디오 케이블"}
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
			"CASE": rows = ["보드 %s까지 · 공기 흐름 %s" % [p["mb_max"], ["", "약함", "보통", "좋음"][p["airflow"]]] + (" · 방음 -%ddB" % p["quiet"] if p.has("quiet") else ""), "그래픽카드 %dmm까지" % p["gpu_max"], "쿨러 높이 %dmm까지" % p["cooler_max"]]
			"MB": rows = ["소켓 %s · %s · RAM 슬롯 %d개" % [p["socket"], p["size"], p["ram_slots"]], "전원부(VRM) %dW까지 · USB %d개" % [p.get("vrm", 999), p["usb"]], "무선 Wi-Fi " + ("있음" if p.get("wifi", false) else "없음 (랜선 필요)")]
			"CPU": rows = ["%d코어 · %.1fGHz · 캐시 %dMB · 소켓 %s" % [p["cores"], p["ghz"], p.get("cache", 16), p["socket"]], "게임 %dfps까지 · 멀티 점수 %s" % [p["game"], str(p["mt"])], "발열 %dW · 내장 그래픽 %s" % [p["watt"], "있음" if p.get("igpu", 0) else "없음 (그래픽카드 필수)"]]
			"COOLER": rows = ["%dW까지 식힘 · 소음 +%ddB" % [p["tdp"], p["noise"]] + (" (팬 없음)" if p["noise"] == 0 else ""), "높이 %dmm (케이스 한계 확인)" % p["height"]]
			"SSD": rows = ["용량 %s · 읽기 %dMB/s" % [p["capacity"], p.get("read", 3500)], "느린 SSD는 부팅 · 빌드가 느려요" if p.get("read", 3500) < 1000 else "M.2 슬롯에 장착 · 없으면 부팅 불가"]
			"GPU": rows = ["1080p %dfps · VRAM %dGB" % [p["fps"], p["vram"]], "전력 %dW · 길이 %dmm · DP %d개" % [p["watt"], p["length"], p["dp"]], "보조 전원선 %d개 · 방송 인코더 %s" % [p["pcie"], "있음" if p.get("enc", false) else "없음"]]
			"RAM": rows = ["%dGB · %dMHz" % [p["gb"], p.get("mhz", 3200)], "같은 RAM 2장이면 듀얼 채널 · 섞으면 느린 쪽 속도"]
			_: rows = ["용량 %dW · 인증 %s" % [p["capacity"], p.get("grade", "없음")], "그래픽카드 전원선 %d개" % p["pcie"]]
		return ["종류  " + TYPE_NAMES[p["type"]]] + rows

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_CLOSE) or not inside(x, y, BOX):
			m.pop()
		elif inside(x, y, BTN_MINUS):
			qty = max(1, qty - 1)
		elif inside(x, y, BTN_PLUS):
			qty = min(9, qty + 1)
		elif inside(x, y, BTN_ADD):
			var line: String = DB.spec(id).get("line", "")
			if line != "" and not Game.upgrades.has(line):   # 잠긴 상품: 모은 가게 돈으로 그 라인을 바로 해금
				var up: Dictionary = DB.UPGRADES[line]
				if Game.buy_upgrade(line):
					toast = "%s 해금! 이제 담을 수 있어요 (-%d만)" % [up["name"], up["price"]]
					sfx("buy")
				else:
					toast = "가게 돈이 모자라요 (해금 %d만 · 지금 %d만)" % [up["price"], Game.money]
					sfx("error")
			elif Game.add_to_cart(id, qty):
				sfx("cart")
				m.pop()
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
		var y := 482.0   # 설명 · 사양을 상자 폭(440)에 맞춰 줄바꿈하고 줄 수만큼 아래로 밀기
		for l in wrap_text(p["desc"], 440):
			text(640, y, l, 22, Color8(200, 192, 240))
			y -= 28
		y -= 12
		for s in spec_lines():
			for l in wrap_text(s, 440):
				text(640, y, l, 22)
				y -= 28
		var have: int = Game.stock.get(id, 0)
		text(210, 230, "창고 보유 %d개  ·  장바구니 %d개" % [have, Game.cart.get(id, 0)], 15, CYAN)
		if have > 0:
			button(BTN_SELL, "반품 1개", VIOLET)
		button(BTN_MINUS, "−", VIOLET)
		text(722, 173, qty, 22)
		button(BTN_PLUS, "+", VIOLET)
		var locked := not Game.unlocked(p)
		if locked:   # 잠김: 가게 돈으로 해금하는 버튼으로 바뀜
			var up: Dictionary = DB.UPGRADES[p["line"]]
			button(BTN_ADD, "해금하기  %d만" % up["price"], GOLD if Game.money >= up["price"] else DIM)
			var ly := 196.0   # 무엇이 같이 풀리는지 (이미지 아래 빈칸에, 상자 안으로 줄바꿈)
			for ln in wrap_text("%s: %s" % [up["name"], up["desc"]], 400):
				text(210, ly, ln, 22, GOLD)
				ly -= 28
		else:
			button(BTN_ADD, "장바구니 담기  %d만" % (p["price"] * qty), PINK)
		button(BTN_CLOSE, "X", DIM)
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
		var ink := INK   # 흰 종이 + 검은 외곽선 글씨는 뭉개져서, 다른 창과 같은 어두운 바탕으로
		var quiet := QUIET
		dim()
		panel(BOX, true)
		text(430, 600, "데스크몰 영수증", 24, ink)
		text(430, 570, "%d일차 · %s 주문용" % [Game.day, Game.request()["customer"]], 14, quiet)
		var ids: Array = bought["items"].keys()
		for i in min(ids.size(), 10):
			var p := DB.spec(ids[i])
			var n: int = bought["items"][ids[i]]
			text(430, 530 - i * 30, "%s × %d" % [p["name"], n], 16, ink)
			text(770, 530 - i * 30, "%d만" % (p["price"] * n), 22, GOLD)
		if ids.size() > 10:
			text(430, 230, "외 %d개" % (ids.size() - 10), 22, quiet)
		box([430, 206, 850, 208], quiet)
		text(430, 186, "결제 금액  %d만 원" % bought["total"], 20, ink)
		text(430, 158, "남은 가게 돈  %d만 원" % Game.money, 22, quiet)
		text(670, 186, "창고로 배송 완료", 22, CYAN)
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
	## 일시정지 (ll 버튼 · 왼쪽 위 손님 이름 · ESC · 안드로이드 뒤로). 주문 중이면 왼쪽에 '의뢰 메모'(핵심만 크게).
	const BOX := [340, 140, 940, 600]
	const MEMO := [30, 40, 780, 620]
	const BUTTONS := [["resume", "계속하기"], ["dex", "도감 · 업적"], ["title", "타이틀로"], ["quit", "게임 종료"]]

	func _init() -> void:
		overlay = true

	func btn_rect(i: int) -> Array:
		var y := 360 - i * 56
		return [850, y - 46, 1230, y] if in_order() else [440, y - 46, 840, y]

	func in_order() -> bool:
		return m.stack.size() > 1 and m.stack[0] in [m.modes["shop"], m.modes["desk"], m.modes["build"], m.modes["wire"]]

	func down(x: float, y: float, _right: bool) -> void:
		for i in BUTTONS.size():
			if inside(x, y, btn_rect(i)):
				sfx("click")
				match BUTTONS[i][0]:
					"resume": m.pop()
					"dex": m.push("dex")
					"title": m.go("title")
					_: m.get_tree().quit()

	func row(y: float, label: String, value: String, c: Color) -> float:   # 이름표 + 값 (길면 줄바꿈). 다음 줄 y를 돌려줌
		text(MEMO[0] + 30, y, label, 22, QUIET)
		var lines: Array = wrap_text(value, MEMO[2] - MEMO[0] - 200, 33)
		for ln in lines:
			text(MEMO[0] + 170, y, ln, 33, c)
			y -= 44
		return y - 10

	func draw() -> void:
		dim()
		if not in_order():
			panel(BOX, true)
			text(BOX[0] + 30, BOX[3] - 40, "일시정지", 28, PINK)
		else:
			var req := Game.request()
			var kind := Rules.kind_of(req)
			panel(MEMO, true)
			text(MEMO[0] + 30, MEMO[3] - 38, "의뢰 메모  ·  " + req["customer"], 33, PINK)
			var y: float = MEMO[3] - 100
			var kinds := {"repair": "수리", "pc": "PC 조립", "desk": "데스크테리어", "full": "PC + 데스크"}
			y = row(y, "종류", kinds[kind], CYAN)
			if req.has("use") and kind != "desk":
				y = row(y, "용도", Bench.describe(req["use"]), GOLD)
			if Game.need_text(req) != "":
				y = row(y, "꼭 필요", Game.need_text(req), GOLD)
			if Game.dislike_text(req) != "":
				y = row(y, "싫어함", Game.dislike_text(req), PINK)
			if req.has("used"):
				y = row(y, "부품", "중고도 괜찮아요" if req["used"] == "ok" else "새 제품만!", GREEN if req["used"] == "ok" else PINK)
			y = row(y, "예산", "%d만 원  (남은 %d만)" % [req["budget"], Game.money_left()], INK if Game.money_left() >= 0 else PINK)
			text(MEMO[0] + 30, y - 6, "손님이 한 말", 22, QUIET)
			var lines := Game.lines()
			for i in lines.size():
				for ln in wrap_text("\"%s\"" % lines[i], MEMO[2] - MEMO[0] - 60):
					y -= 32
					text(MEMO[0] + 30, y - 6, ln, 22, INK)
			text(850, 410, "일시정지", 28, PINK)
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
	const GRAPH := [420, 330, 1210, 540]
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
		fixit = Bench.fix(Bench.parts_of(Game.pc), use, Game.unlocked) if not r["ok"] and not Game.request().has("repair") else {}   # 수리는 정답을 안 알려 줌
		pts = Bench.series(r, N) if r["kind"] == "game" and r["value"] > 0 else []
		for e in Game.pc.used.values():   # 테스트하면 꽂힌 중고 부품의 진짜 상태가 보임
			e["known"] = true
			if e["paid"] > 0 and e["cond"] < 40:
				Game.stats["scammed"] = 1
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

	func text_c_x(cx: float, s: String) -> float:
		return cx - text_w(s, 22) / 2.0

	## 렌더 · 빌드: 시간에 따른 진행률. 목표 시간(세로 점선)보다 먼저 100%에 닿으면 성공
	func draw_progress() -> void:
		var g := [GRAPH[0], 220, GRAPH[2], GRAPH[3]]
		box(g, Color8(14, 10, 32))
		outline(g, DIM)
		text(g[0] + 12, g[3] - 22, "진행률", 22, QUIET)
		var tmax: float = maxf(r["value"], r["target"]) * 1.25
		var xx := func(v: float) -> float: return g[0] + (g[2] - g[0]) * v / tmax
		var tx: float = xx.call(r["target"])
		for y in range(int(g[1]), int(g[3]), 24):
			box([tx - 1.5, y, tx + 1.5, y + 12], GOLD)
		var unit: String = {"render": "%d분", "code": "%d초"}[r["kind"]]
		text(tx + 8, g[3] - 22, "목표 " + unit % r["target"], 22, GOLD)
		var line_pts := []
		for i in maxi(2, int(N * k())):
			var tt: float = tmax * i / float(N - 1)
			line_pts.append(Vector2(xx.call(tt), g[1] + (g[3] - g[1]) * minf(1.0, tt / r["value"])))
		polyline(line_pts, GREEN if r["value"] <= r["target"] else PINK, 4)
		circle(line_pts[-1].x, line_pts[-1].y, 7, Color.WHITE)


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
		var why := "↓ 뚝 끊김 = RAM 부족" if r.get("ram_low", false) else "↘ 점점 느려짐 = 과열" if r.get("throttle", false) else ""
		text(g[0] + 12, g[1] + 22, why, 22, PINK)
		if r.has("low1"):   # 평균만 보면 모르는 '가끔 끊김'
			var bad: bool = r["low1"] < r["target"] * 0.5
			var lbl := "평균 %d · 1%% 최저 %dfps" % [roundi(r["value"]), r["low1"]]
			box([g[0] + 4, g[3] - 40, g[0] + 20 + text_w(lbl, 22), g[3] - 4], Color(0.05, 0.04, 0.12, 0.9))   # 그래프 선 위에서도 읽히게
			text(g[0] + 12, g[3] - 22, lbl, 22, PINK if bad else INK)

	func draw() -> void:
		dim()
		panel(BOX, true)
		var use: Dictionary = Game.request().get("use", {"kind": "office"})
		text(70, 646, "성능 테스트", 33, PINK)
		text(70, 606, "손님 요구: " + Bench.describe(use), 22, CYAN)
		button(BTN_CLOSE, "닫기", VIOLET)
		if not r.has("noise"):   # 부품이 모자라 테스트를 못 함
			for i in r["notes"].size():
				for ln in wrap_text(r["notes"][i], 1100):
					text(70, 520 - i * 50, ln, 33, PINK)
			return
		if r.get("shutdown", false):   # 테스트 중 꺼짐: 과열이면 빨간 온도계, 파워면 전력 막대
			var heat: bool = r["cpu_temp"] >= 100
			if heat:
				thermo(230, 150, 340, r["cpu_temp"] * k(), "CPU")
			else:
				box([200, 150, 260, 490], Color8(30, 22, 60))
				box([206, 156, 254, 156 + 328 * minf(1.0, k() * 1.15)], PINK)
				text(176, 120, "파워 부하", 22, INK)
			text(GRAPH[0], 460, "✗ 테스트 중 꺼졌어요", 33, PINK)
			text(GRAPH[0], 410, "CPU %d°C: 쿨러가 열을 못 따라가요" % r["cpu_temp"] if heat else r["notes"][0], 22, INK)
			if not fixit.is_empty():
				text(GRAPH[0], 360, "추천: 쿨러 → %s (%d만)" % [DB.PARTS[fixit["id"]]["name"], fixit["cost"]], 22, GOLD)
			return
		if r["value"] == 0.0 and r["kind"] != "office":
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
				hbar(238, "그래픽카드 한계" if Game.pc.has("GPU") else "내장 그래픽 한계", r["gpu_fps"], scale, r["limit"] != "CPU", "%dfps" % r["gpu_fps"] + ("  ← 발목" if r["limit"] != "CPU" else ""))
			"render", "code":
				draw_progress()
			_:
				text(GRAPH[0], 520, "켜지기만 하면 되는 손님이에요.", 22, INK)
				text(GRAPH[0], 480, "소음만 기준보다 조용하면 OK", 22, QUIET)
		# 3) 왼쪽 아래: 온도계 2개 + 소음 막대
		# 3) 왼쪽 아래: CPU · 그래픽 · 소음을 같은 폭 · 같은 높이로 (색은 조금씩만 다르게)
		thermo(96, 104, 100, r["cpu_temp"] * kk, "CPU", CYAN)
		thermo(206, 104, 100, r["gpu_temp"] * kk, "그래픽", Color8(90, 220, 170))
		var q2: float = use.get("quiet", 40)
		var loud: bool = r["noise"] > q2
		var nc: Color = PINK if loud else Color8(120, 190, 245)
		for i in 6:   # 소리 막대 (높을수록 시끄러움), 온도계와 같은 높이 100
			var on: bool = i < int(6 * minf(1.0, r["noise"] / 50.0) * kk + 0.5)
			box([280 + i * 12, 104, 288 + i * 12, 120 + i * 16.8], nc if on else Color8(30, 22, 60))
		var nv := "%ddB" % roundi(r["noise"] * kk)
		text(316 - text_w(nv, 22) / 2.0, 226, nv, 22, PINK if loud else INK)
		text(316 - text_w("소음", 22) / 2.0, 70, "소음", 22, INK)
		if kk < 1.0:
			text(GRAPH[0], 180, "테스트 중" + ".".repeat(int((Time.get_ticks_msec() - t0) / 250) % 4), 33, QUIET)
			return
		# 4) 판정 + 쉬운 말 + 가장 싼 해결책
		text(70, 262, "✓ 목표 달성!" if r["ok"] else "✗ 자꾸 끊겨요" if r.get("ram_low", false) and r["kind"] == "game" else "✗ 너무 시끄러워요" if r["ratio"] >= 1.0 else "✗ 목표 미달", 33, GREEN if r["ok"] else PINK)
		var ny: float = 430.0 if r["kind"] == "office" else 160.0   # 한 줄만: 고칠 방법, 없으면 원인
		var tip := ""
		if not fixit.is_empty():
			var p: Dictionary = DB.PARTS[fixit["id"]]
			var what: String = {"CPU": "CPU", "GPU": "그래픽카드", "RAM": "RAM", "COOLER": "쿨러", "CASE": "케이스"}[fixit["type"]]
			var with_mb: String = " + %s" % DB.PARTS[fixit["mb"]]["name"] if fixit.get("mb", "") != "" else ""
			tip = "추천: %s → %s%s%s (%d만)" % [what, p["name"], " ×2" if fixit["type"] == "RAM" else "", with_mb, fixit["cost"]]
		elif not r["ok"] and Game.request().has("repair"):
			tip = "원인은 진단 화면(조립 → 진단)에서 찾아보세요"
		elif not r["ok"]:
			tip = r["notes"][0].split(" →")[0] if not r["notes"].is_empty() else "빨간 막대(발목)부터 바꿔 보세요"
		for ln in wrap_text(tip, 800):
			text(GRAPH[0], ny, ln, 22, GOLD)
			ny -= 30


class Trial extends Mode:
	## 납품: 손님 앞에서 전원을 켜고(부팅) → 손님 용도대로 써 보면서 성능 · 온도 · 소음 · 모니터 Hz까지 같이 확인 → 손님 반응.
	## 게임은 계산된 FPS(모니터 Hz까지만 보임)만큼 부드럽거나 끊기고, 렌더 · 빌드는 진행 막대, 사무는 화상회의.
	const SCREEN := [380, 170, 1240, 610]
	const BOOT := 2.6   # 부팅 연출 시간(초)
	var t0 := 0
	var r := {}
	var shown_r := {}   # 모니터 Hz로 잘린 '눈에 보이는' 결과
	var hz := 0
	var boot := true
	var beeped := false

	var desk_only := false
	var stars := 0
	var photo: Texture2D = null

	func enter() -> void:
		t0 = Time.get_ticks_msec()
		desk_only = Rules.kind_of(Game.request()) == "desk"
		if desk_only:   # 데스크테리어: 부팅 대신 손님이 완성된 책상을 보는 장면 (납품 때 찍은 사진)
			stars = Rules.score(Game.request(), Game.placed, Game.computer(), Game.cables)["stars"]
			var img := Image.load_from_file("%s/day%d_%d.png" % [Main.PHOTOS, Game.day, Game.order_index + 1]) if FileAccess.file_exists("%s/day%d_%d.png" % [Main.PHOTOS, Game.day, Game.order_index + 1]) else null
			photo = ImageTexture.create_from_image(img) if img else null
			return
		var use: Dictionary = Game.request().get("use", {"kind": "office"})
		var cp := Game.computer()
		boot = cp.picture() and "GPU" not in cp.loose()
		r = Bench.run(Bench.parts_of(cp), use)
		hz = Rules.best_screen(Game.placed)[0]
		shown_r = r.duplicate()
		if r["kind"] == "game" and hz > 0 and r["value"] > hz:   # 60Hz 모니터면 200fps도 60으로 보임
			shown_r["value"] = float(hz)
		t0 = Time.get_ticks_msec()
		beeped = false

	func t() -> float:
		return (Time.get_ticks_msec() - t0) / 1000.0

	func down(_x: float, _y: float, _right: bool) -> void:
		if t() > 1.0:
			m.go("result")

	func reaction() -> Array:   # [기분, 한마디]
		if not boot or r.get("shutdown", false):
			return ["sad", "어… 화면이 안 나와요?"]
		var bad: bool = r.get("ram_low", false) and r["kind"] == "game"
		if r["kind"] == "game" and hz > 0 and hz < r["target"] and r["ratio"] >= 1.0:
			return ["neutral", "PC는 빠르다는데… 모니터가 %dHz라 부드럽진 않네요." % hz]
		if r["kind"] == "game" and r.get("low1", 9999) < r["target"] * 0.5 and r["ratio"] >= 1.0:
			return ["neutral", "평균은 빠른데… 가끔 뚝뚝 끊겨요."]
		if r["ratio"] >= 1.0 and not r["ok"] and not bad:   # 성능은 되는데 소음 기준을 넘음
			return ["neutral", "빠른데… 좀 시끄럽네요."]
		match r["kind"]:
			"game":
				if r["ok"] and not bad: return ["happy", "와, 엄청 부드러워요!"] if r["ratio"] >= 1.3 else ["happy", "딱 원하던 느낌이에요."]
				return ["sad", "자꾸 멈칫해요…"] if bad else ["neutral" if r["ratio"] >= 0.75 else "sad", "음… 좀 버벅이네요."]
			"render", "code":
				return ["happy", "벌써 끝났어요?"] if r["ok"] else ["neutral", "기다리는 게 좀 길어요…"]
		if not r["ok"]:
			return ["neutral", "좀 시끄럽네요…"]
		return ["happy", "조용하고 좋네요."]

	## 부팅 화면: 삐 → 로고 → 바탕화면
	func draw_boot(sc: Array, tt: float) -> void:
		box(sc, Color8(4, 3, 10))
		if not boot:
			if tt > 0.8:
				text_c(sc, "신호 없음", 33, QUIET)
			return
		var c := center(sc)
		if tt < 0.6:
			return
		if tt < 1.7:
			for q in 4:
				box([c.x - 30 + (q % 2) * 32, c.y + 2 - (q / 2) * 32, c.x - 2 + (q % 2) * 32, c.y + 30 - (q / 2) * 32], CYAN)
			for d in 6:
				var a := tt * 6.0 + d * TAU / 6.0
				circle(c.x + cos(a) * 18, c.y - 70 + sin(a) * 18, 3.0 + d * 0.6, Color(1, 1, 1, 0.3 + d * 0.12))
			return
		m.draw_texture_rect(DB.tex("title_bg"), _rect(sc), false)
		box([sc[0], sc[1], sc[2], sc[1] + 34], Color(0.05, 0.03, 0.12, 0.92))
		text(sc[0] + 16, sc[1] + 17, "시작", 22, INK)

	## 데스크테리어 공개: 어두운 방에 불이 켜지듯 책상이 드러나고 → 손님 반응
	func draw_reveal() -> void:
		var req := Game.request()
		var tt := t()
		var sc := [380, 110, 1240, 610]
		box([0, 0, 1280, 720], BG)
		text(40, 670, "%s 님이 책상을 보는 중" % req["customer"], 33, PINK)
		frame("ui_panel", [sc[0] - 14, sc[1] - 14, sc[2] + 14, sc[3] + 14])
		if photo:
			m.draw_texture_rect(photo, _rect(sc), false)
		else:
			box(sc, Color8(30, 24, 50))
			text_c(sc, "책상 사진", 22, QUIET)
		box(sc, Color(0.02, 0.01, 0.05, clamp(1.0 - (tt - 0.3) / 1.2, 0.0, 1.0) * 0.92))   # 불 켜지기
		var shown := tt > 2.0
		var rx: Array = [["sad", "제가 말한 거랑 많이 달라요…"], ["neutral", "음… 뭔가 조금 아쉬워요."], ["happy", "분위기 좋네요! 여기서 일하고 싶어요."], ["happy", "와… 딱 제가 상상한 책상이에요!"]][stars]
		panel([40, 270, 340, 570], true)
		put("face_%s_%s" % [req["face"], rx[0] if shown else "neutral"], [60, 290, 320, 550])
		if shown:
			panel([40, 100, 340, 250], true)
			var y := 212.0
			for ln in wrap_text(rx[1], 270):
				text(56, y, ln, 22, INK)
				y -= 30
			text_c([380, 50, 1240, 100], "누르면 결과 보기", 22, QUIET)

	func draw() -> void:
		if desk_only:
			draw_reveal()
			return
		box([0, 0, 1280, 720], BG)
		var req := Game.request()
		var tt := t()
		if tt > 0.6 and not beeped and boot:
			beeped = true
			sfx("boot_ok")
		var run_t := tt - BOOT
		text(40, 670, "%s 님 앞에서 %s" % [req["customer"], "전원을 켜는 중" if run_t < 0 else "써 보는 중"], 33, PINK)
		text(40, 628, Bench.describe(req.get("use", {"kind": "office"})), 22, CYAN)
		if run_t < 0 or not boot or r.get("shutdown", false):
			frame("ui_panel", [SCREEN[0] - 14, SCREEN[1] - 14, SCREEN[2] + 14, SCREEN[3] + 14])
			draw_boot(SCREEN, tt)
			if boot and r.get("shutdown", false) and run_t > 1.0:   # 부하 걸리자 꺼짐
				box(SCREEN, Color8(4, 3, 10))
				text_c(SCREEN, "…갑자기 꺼졌어요", 33, PINK)
		elif r["kind"] == "office":
			frame("ui_panel", [SCREEN[0] - 14, SCREEN[1] - 14, SCREEN[2] + 14, SCREEN[3] + 14])
			draw_app(SCREEN, r, run_t)
		else:   # 나란히: 손님이 원한 성능 vs 지금 PC → 부드러움 · 속도 차이가 바로 보임
			var want := r.duplicate()
			want.merge({"value": r["target"], "ratio": 1.0, "ok": true, "ram_low": false, "throttle": false, "low1": r["target"], "vram_short": false}, true)
			var now_lbl := "지금 " + Bench.value_text(r) + (" → 화면 %dHz" % hz if shown_r["value"] < r["value"] else "")
			var sides := [[[380, 240, 800, 560], want, "손님이 원한 " + Bench.value_text(want), QUIET], [[820, 240, 1240, 560], shown_r, now_lbl, GREEN if r["ratio"] >= 1.0 and shown_r["value"] >= r["target"] else PINK]]
			for sd in sides:
				var sc: Array = sd[0]
				frame("ui_panel", [sc[0] - 10, sc[1] - 10, sc[2] + 10, sc[3] + 10], Color.WHITE if sd[1] == shown_r else Color8(110, 100, 160))
				draw_app(sc, sd[1], run_t, false)
				text_c([sc[0], sc[1] - 64, sc[2], sc[1] - 16], sd[2], 33 if text_w(sd[2], 33) < sc[2] - sc[0] else 22, sd[3])
		if run_t >= 0 and boot and r.has("noise"):   # 실시간 측정값
			var live := "CPU %d°C  ·  그래픽 %d°C  ·  소음 %ddB  ·  %dW  ·  모니터 %s" % [r["cpu_temp"], r["gpu_temp"], r["noise"], r.get("watt", 0), "%dHz" % hz if hz else "없음"]
			text_c([380, 116, 1240, 156], live, 22, INK)
		var rx := reaction()
		var shown: bool = run_t > 2.5 or (not boot and tt > 2.0)
		panel([40, 270, 340, 570], true)
		put("face_%s_%s" % [req["face"], rx[0] if shown else "neutral"], [60, 290, 320, 550])
		if shown:
			panel([40, 100, 340, 250], true)
			var y := 212.0
			for ln in wrap_text(rx[1], 270):
				text(56, y, ln, 22, INK)
				y -= 30
			text_c([380, 50, 1240, 100], "누르면 결과 보기", 22, QUIET)


class Dex extends Mode:
	## 도감: 고친 고장(증상 · 단서 · 고치는 법), 납품에 써 본 부품, 업적
	const TABS3 := ["고장", "부품", "업적", "손님"]
	const BTN_BACK := [12, 648, 172, 714]
	var tab := 0
	var sel := 0

	func tab_r(i: int) -> Array:
		return [190 + i * 232, 648, 412 + i * 232, 714]

	func fault_row(i: int) -> Array:
		return [20, 572 - i * 56, 440, 622 - i * 56]

	func part_cell(i: int) -> Array:
		var x := 20 + (i % 8) * 155
		var y := 630 - (i / 8 + 1) * 102
		return [x, y + 4, x + 148, y + 100]

	func parts_all() -> Array:
		var ids := DB.PARTS.keys()
		ids.sort_custom(func(a, b): return DB.PARTS[a]["type"] + str(DB.PARTS[a]["price"]).pad_zeros(4) < DB.PARTS[b]["type"] + str(DB.PARTS[b]["price"]).pad_zeros(4))
		return ids

	func down(x: float, y: float, _right: bool) -> void:
		if inside(x, y, BTN_BACK):
			m.pop()
			return
		for i in 4:
			if inside(x, y, tab_r(i)):
				tab = i
				sel = 0
				sfx("click")
				return
		if tab == 0:
			for i in PCBuild.FAULTS.size():
				if inside(x, y, fault_row(i)):
					sel = i
		elif tab == 1:
			for i in parts_all().size():
				if inside(x, y, part_cell(i)):
					sel = i

	func count(prefix: String) -> int:
		return Game.dex.keys().filter(func(k): return k.begins_with(prefix)).size()

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		frame("ui_panel", [-12, BAR, 1292, H + 12])
		button(BTN_BACK, "◀ 닫기", VIOLET)
		var labels := ["고장 %d/%d" % [count("f:"), PCBuild.FAULTS.size()], "부품 %d/%d" % [count("p:"), DB.PARTS.size()], "업적 %d/%d" % [Game.achv.size(), Game.ACHV.size()], "손님 %d" % Game.visits.size()]
		for i in 4:
			frame("ui_button", tab_r(i), CYAN if i == tab else Color8(80, 66, 140))
			text_c(tab_r(i), labels[i], 22, Color.WHITE if i == tab else QUIET)
		match tab:
			0: draw_faults()
			1: draw_parts()
			2: draw_achv()
			3: draw_people()

	## 단골 수첩: 손님마다 방문 기록(별)과 지금 기분
	func draw_people() -> void:
		var names := Game.visits.keys()
		if names.is_empty():
			text(60, 560, "아직 만난 손님이 없어요", 33, QUIET)
		for i in mini(names.size(), 9):
			var v: Array = Game.visits[names[i]]
			var r := [40, 568 - i * 62, 1240, 622 - i * 62]
			frame("ui_slot", r)
			fit("face_%s_%s" % [face_of(names[i]), "happy" if v[-1] >= 2 else "sad"], r[0] + 32, r[1] + 27, 48, 48)
			text(r[0] + 70, r[1] + 27, names[i], 22, INK)
			text(r[0] + 330, r[1] + 27, "  ".join(v.map(func(s): return "★".repeat(s) + "☆".repeat(3 - s))), 22, GOLD)
			text(r[0] + 760, r[1] + 27, "또 오고 싶대요" if v[-1] >= 2 else "실망했어요…", 22, GREEN if v[-1] >= 2 else PINK)

	func face_of(name: String) -> String:
		for q in DB.REQUESTS:
			if q["customer"] == name:
				return q["face"]
		return "student"

	func draw_faults() -> void:
		var keys := PCBuild.FAULTS.keys()
		for i in keys.size():
			var on: bool = Game.dex.has("f:" + keys[i])
			frame("ui_button", fault_row(i), PINK if i == sel else Color8(60, 50, 110))
			text(fault_row(i)[0] + 16, fault_row(i)[1] + 25, (PCBuild.FAULT_INFO[keys[i]][0] if on else "???") + "  " + "★".repeat(PCBuild.FAULTS[keys[i]]), 22, INK if on else DIM)
		var k: String = keys[sel]
		panel([460, 20, 1260, 622], true)
		if not Game.dex.has("f:" + k):
			text(500, 560, "아직 고쳐 본 적 없는 고장이에요", 33, QUIET)
			text(500, 500, "수리 의뢰에서 고치면 기록돼요", 22, DIM)
			return
		var info: Array = PCBuild.FAULT_INFO[k]
		text(500, 570, info[0], 33, PINK)
		var y := 500.0
		for row in [["증상", info[1], INK], ["단서", info[2], CYAN], ["고치기", info[3], GOLD]]:
			text(500, y, row[0], 22, QUIET)
			for ln in wrap_text(row[1], 600):
				text(620, y, ln, 22, row[2])
				y -= 34
			y -= 24

	func draw_parts() -> void:
		var ids := parts_all()
		for i in ids.size():
			var r := part_cell(i)
			var on: bool = Game.dex.has("p:" + ids[i])
			frame("ui_slot", r, PINK if i == sel else Color.WHITE)
			if on:
				fit(icon_of(ids[i]), (r[0] + r[2]) / 2.0, r[1] + 58, 80, 56)
			else:
				text_c(r, "?", 33, DIM)
			text_c([r[0], r[1] + 2, r[2], r[1] + 30], clip(DB.PARTS[ids[i]]["name"], 140) if on else "", 22, QUIET)
		var p: Dictionary = DB.PARTS[ids[sel]]
		if Game.dex.has("p:" + ids[sel]):
			text(30, 70, "%s · %d만 원" % [p["name"], p["price"]], 22, GOLD)
			text(30, 36, clip(p.get("desc", ""), 1200), 22, INK)
		else:
			text(30, 52, "납품한 PC에 넣으면 기록돼요", 22, DIM)

	func draw_achv() -> void:
		var keys := Game.ACHV.keys()
		for i in keys.size():
			var a: Array = Game.ACHV[keys[i]]
			var on: bool = Game.achv.has(keys[i])
			var r := [40, 560 - i * 66, 1240, 618 - i * 66]
			frame("ui_slot", r, GOLD if on else Color.WHITE)
			text(r[0] + 20, r[1] + 29, "✓" if on else "○", 22, GREEN if on else DIM)
			text(r[0] + 70, r[1] + 29, a[0], 22, INK if on else QUIET)
			text(r[0] + 330, r[1] + 29, a[1], 22, QUIET)
			text(r[2] - 150, r[1] + 29, "+%d만" % a[2], 22, GOLD if on else DIM)


class Ending extends Mode:
	## 마지막 날 마감 뒤: 가게를 지켰는지 + 손님마다 그 뒤 이야기
	var t0 := 0

	func enter() -> void:
		t0 = Time.get_ticks_msec()
		sfx("star" if Game.goal_met() else "sad")

	func down(_x: float, _y: float, _right: bool) -> void:
		if Time.get_ticks_msec() - t0 < 1500:
			return
		m.modes["title"].message = "엔딩: %s · 단골 %d명 · 고장 도감 %d/%d" % ["가게를 지켰어요" if Game.goal_met() else "가게 문을 닫았어요", happy(), Game.faults_known(), PCBuild.FAULTS.size()]
		Game.delete_save()
		m.go("title")

	func happy() -> int:
		return Game.history.values().filter(func(s): return s >= 2).size()

	func draw() -> void:
		box([0, 0, 1280, H], BG)
		var ok := Game.goal_met()
		text(80, 660, "가게를 지켰어요!" if ok else "가게 문을 닫았어요…", 44, GREEN if ok else PINK)
		text(80, 610, ("임대료를 내고도 %d만 원이 남았어요. 의뢰소는 내일도 문을 열어요." % (Game.money - Game.goal())) if ok else ("%d만 원이 모자랐어요. 건물주가 열쇠를 가져갔어요." % (Game.goal() - Game.money)), 22, INK)
		text(80, 560, "그 뒤 손님들은…", 22, GOLD)
		var names := Game.history.keys()
		var shown := mini(names.size(), int((Time.get_ticks_msec() - t0) / 400.0))   # 한 줄씩 떠오름
		for i in shown:
			var y := 510 - i * 40
			var good: bool = Game.history[names[i]] >= 2
			text(80, y, names[i], 22, CYAN if good else QUIET)
			text(380, y, Game.epilogue(names[i]), 22, INK if good else DIM)
		text(80, 30, "단골 %d명  ·  고장 도감 %d/%d  ·  업적 %d/%d     화면을 눌러 타이틀로" % [happy(), Game.faults_known(), PCBuild.FAULTS.size(), Game.achv.size(), Game.ACHV.size()], 22, QUIET)
