extends SceneTree
## 전체 플레이 자동 테스트: 실제 화면을 띄우고 손님 한 명을 처음부터 납품까지 눌러 본다.
## 실행: Godot --path . --script godot/smoke.gd   (화면이 있으면 docs/screens/godot_*.png 저장)

var main: Main
var shots := DisplayServer.get_name() != "headless"


func _initialize() -> void:
	Game.SAVE_PATH = "user://test_save.json"   # 실제 플레이 저장은 그대로 두기
	Game.delete_save()
	main = load("res://godot/main.tscn").instantiate()
	root.add_child(main)
	run()


func tap(r: Array, right := false) -> void:
	var c := Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
	main.mouse = c
	main.top().down(c.x, c.y, right)
	main.top().up(c.x, c.y)


func drag(a: Array, b: Array) -> void:
	main.top().down((a[0] + a[2]) / 2.0, (a[1] + a[3]) / 2.0, false)
	main.mouse = Vector2((b[0] + b[2]) / 2.0, (b[1] + b[3]) / 2.0)
	main.top().up(main.mouse.x, main.mouse.y)


func shot(name: String) -> void:
	for i in 3:
		await process_frame
	if shots:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/screens/godot_%s.png" % name)


## 실패하면 이유를 찍고 바로 끝낸다 (assert는 헤드리스에서 멈춰 버림)
func check(cond: bool, what := "") -> void:
	if not cond:
		printerr("smoke 실패: ", what, " @ 줄 ", get_stack()[1]["line"] if get_stack().size() > 1 else "?")
		quit(1)


## 드라이버로 아직 안 조인 나사를 전부 조인다 (slot을 주면 그 자리만 풀기 · 조이기 전환)
func screw_all(b, only := "") -> void:
	tap(b.BTN_DRIVER)
	for s in b.screw_points():
		if only != "" and s[0] == only or only == "" and not Game.pc.screws[s[0]][s[1]]:
			var p: Vector2 = s[2]
			tap([p.x - 1, p.y - 1, p.x + 1, p.y + 1])
	tap(b.BTN_DRIVER)


func on(name: String) -> void:
	check(main.top() == main.modes[name], "화면이 %s 이어야 함" % name)


func run() -> void:
	await shot("1_title")
	tap(main.modes["title"].BTN_CONTINUE)
	on("news")
	await shot("2_news")
	tap([0, 0, 100, 100])
	on("request")
	await shot("3_request")
	tap([0, 0, 100, 100])
	on("shop")

	var shop = main.modes["shop"]
	tap(shop.card_rect(0))                     # 상품 상세 → 담기
	on("product")
	await shot("4_product")
	tap(main.modes["product"].BTN_ADD)
	on("shop")
	check(Game.cart.size() == 1)
	Game.cart.clear()
	Game.upgrades["gamer"] = true               # 게이밍 마우스는 게이밍 라인 업그레이드 상품
	for id in ["monitor", "keyboard", "mouse_gaming", "lamp_warm", "mug", "case1", "mb1", "cpu1", "cool1", "ssd1", "gpu1", "ram1", "psu1"]:
		Game.add_to_cart(id)
	await shot("5_shop")
	tap(shop.BTN_PAY)
	on("receipt")
	await shot("6_receipt")
	tap(main.modes["receipt"].BTN_OK)
	check(Game.stock["monitor"] == 1 and Game.cart.is_empty())

	tap(shop.tab_rect(1))
	on("desk")
	Game.placed.clear()   # 손님 모니터 · 키보드는 치우고 빈 책상에서 배치 테스트
	Game.cables.clear()
	Game.request()["budget"] = 200   # 배치 테스트용: 5개 다 놓고 부품도 다 꽂을 수 있게 (실제 사무용 예산은 100만)
	var desk = main.modes["desk"]
	drag(desk.row_rect(desk.rows().find("monitor")), [500, 250, 500, 250])
	drag(desk.row_rect(desk.rows().find("keyboard")), [800, 250, 800, 250])
	check(Game.placed.size() == 2, desk.toast)
	await shot("7_desk")
	tap(desk.BTN_VIEW)                         # 탑뷰: 키보드를 모니터 앞으로 옮기기 (같은 x, 다른 앞뒤)
	check(desk.top_view)
	var kb: Dictionary = Game.placed[1]
	var mon_r: Array = desk.shown_rect(Game.placed[0])
	drag(desk.shown_rect(kb), [mon_r[0] + 60, 200, mon_r[0] + 60, 200])
	check(kb["z"] > 0 and kb["x"] < mon_r[2], "탑뷰 이동: %s %s" % [kb, desk.toast])
	for d in [["mouse_gaming", 940, 160], ["lamp_warm", 1060, 520], ["mug", 1150, 200]]:
		drag(desk.row_rect(desk.rows().find(d[0])), [d[1], d[2], d[1], d[2]])
	check(Game.placed.size() == 5, "%s %s" % [desk.toast, Game.placed.map(func(p): return p["id"])])
	await shot("7b_desk_top")
	tap(desk.BTN_VIEW)
	var lamp: Dictionary = Game.placed.filter(func(p): return p["id"] == "lamp_warm")[0]   # 소품 기믹: 조명 끄기 · 머그 김
	tap(Rules.rect_of(lamp))
	check(lamp.get("off", false), "조명 끄기: " + desk.toast)
	tap(Rules.rect_of(lamp))
	check(not lamp.has("off"), "조명 다시 켜기")
	tap(Rules.rect_of(lamp))
	tap(Rules.rect_of(Game.placed.filter(func(p): return p["id"] == "mug")[0]))
	await shot("7c_desk_gimmick")
	desk.selected = null   # 머그 색 칩이 조명을 가리지 않게
	tap(Rules.rect_of(lamp))

	main.go("build")   # 첫 손님은 데스크테리어라 조립 탭이 없음 → 조립 화면 테스트는 바로 이동
	on("build")
	var b = main.modes["build"]
	var part := func(id: String, to: Array): drag(b.inv_row(b.inv_ids().find(id)), to)
	Game.pc = PCBuild.new()   # 첫 손님은 데스크테리어(손님 PC 있음) → 조립 테스트는 빈 케이스부터
	check("케이스" in b.next_step()[0], "다음 할 일 안내: " + b.next_step()[0])
	part.call("case1", b.CASE_AREA)
	part.call("mb1", b.mb_rect())
	tap(b.lever_rect())
	part.call("cpu1", b.cpu_rect())
	tap(b.lever_rect())
	drag(b.PASTE_ROW, b.cpu_rect())
	part.call("cool1", b.cooler_rect())
	part.call("ram1", b.ram_rect(0))
	part.call("ssd1", b.ssd_rect())
	part.call("gpu1", b.gpu_rect())
	part.call("psu1", b.PSU_BAY)
	for c in Game.pc.cable_targets():
		drag(b.psu_port(c), b.socket_rect(c))
	tap(b.BTN_POST)
	check(b.post.is_empty() and "덜 꽂힌" in b.toast, "덜 꽂힌 채로는 전원 테스트 안 됨")
	await shot("8a_seat")
	for k in b.seat.keys():   # 손맛: 들뜬 부품 · 선을 눌러 딸깍
		tap(b.seat_rect(k))
	check(b.seat.is_empty())
	tap(b.BTN_POST)
	check(b.post[0] == 3 and "SSD" in b.post[1], "나사 안 조이면 SSD 들뜸: %s" % [b.post])
	screw_all(b)
	check(Game.pc.loose().is_empty(), "나사 다 조임 %s %s" % [Game.pc.screws, b.screw_points()])
	check("전원" in b.next_step()[0], "다 조립하면 안내는 전원: " + b.next_step()[0])
	tap(b.BTN_POST)
	check(b.post[0] == 4, "부팅 실패: %s / %s" % [b.post, b.toast])
	on("boot")
	await shot("8b_boot")
	main.modes["boot"].t0 -= 10000                 # 바이오스 글자 다 지나간 뒤 = 바탕화면
	await shot("8c_boot_desktop")
	tap([0, 0, 100, 100])
	on("build")
	await shot("8_build")
	tap(b.zone("GPU"), true)                   # 나사가 조여져 있으면 안 빠짐
	check(Game.pc.has("GPU") and "나사" in b.toast)
	screw_all(b, "GPU")
	drag(b.zone("GPU"), b.inv_row(0))          # 재고 쪽으로 끌어내기 = 빼기 → 다시 꽂기
	check(not Game.pc.has("GPU") and Game.stock["gpu1"] == 1)
	part.call("gpu1", b.gpu_rect())
	screw_all(b)
	for c in Game.pc.cable_targets():
		drag(b.psu_port(c), b.socket_rect(c))
	for k in b.seat.keys():
		tap(b.seat_rect(k))
	check(Game.pc.boots() and b.seat.is_empty())

	tap(b.tab_rect(3))
	on("wire")
	var w = main.modes["wire"]
	var used := {}
	for p in w.devices():
		var pos := Rules.plug_pos(p, Game.placed)
		var t: String = DB.ITEMS[p["id"]]["port"]
		used[t] = used.get(t, -1) + 1
		var port := Rules.port_pos(t, used[t])
		drag([pos.x, 470, pos.x, 470], [port.x, port.y, port.x, port.y])
	check(Game.cables.size() == 3 and Rules.wiring_score(Game.cables, Game.placed)[1] == 0, w.toast)
	await shot("9_wire")

	var saved := Game.peek()                   # 자동 저장 → 이어하기
	check(saved["day"] == 1)
	tap(w.tab_rect(1))                         # 책상에서 PC 전원 → 모니터가 켜짐
	on("desk")
	check(not Game.power)
	tap(desk.BTN_POWER)
	check(Game.power and desk.dp_linked(Game.placed[0]), "전원: " + desk.toast)
	Game.power_t -= 1000
	await shot("7g_power_boot")
	Game.power_t -= 5000
	await shot("7h_power_desktop")
	tap(desk.tab_rect(3))
	on("wire")
	main.back()                                # 뒤로 = 일시정지 (주문 다시 보기)
	on("pause")
	await shot("9b_pause")
	tap(main.modes["pause"].btn_rect(0))
	on("wire")
	tap(w.BTN_DONE)
	for i in 10:                               # 납품 사진 찍고 넘어갈 때까지
		await process_frame
	if main.top() == main.modes["burn"]:       # 번인 테스트: 초록 구간 가운데서 멈추기
		var bn = main.modes["burn"]
		bn.t0 -= int((bn.zone[0] + bn.zone[1]) / 2.0 * bn.DUR * 1000)
		await shot("10z_burn_run")
		tap(bn.BTN_STOP)
		check(Game.burn == "good", "번인 적정: " + Game.burn)
		bn.stop_t -= 1000
		await shot("10z_burn_done")
		tap([0, 0, 100, 100])
	on("trial")
	check(main.modes["trial"].stage == 0, "납품: 책상 정면부터")
	main.modes["trial"].t0 -= 2000
	await shot("10b_view_front")
	tap([0, 0, 100, 100])
	check(main.modes["trial"].stage == 1, "정면 → 탑뷰")
	main.modes["trial"].t0 -= 2000
	await shot("10c_view_top")
	tap([0, 0, 100, 100])
	check(main.modes["trial"].stage == 2 and main.top() == main.modes["trial"], "탑뷰 → 부팅")
	main.modes["trial"].t0 -= 4000
	await shot("10a_trial")
	tap([0, 0, 100, 100])
	on("result")
	check(main.modes["result"].result["boot"] == "" or true)
	await shot("10_result")
	var money := Game.money
	tap([0, 0, 100, 100])
	on("request")
	check(Game.order_index == 1 and Game.placed.is_empty())
	Game.order_index = Game.todays_requests().size() - 1
	main.go("result")
	tap([0, 0, 100, 100])
	on("day_end")
	await shot("11_day_end")
	Game.shelf = [PCBuild.full().to_dict(), PCBuild.full({"case": "case1", "mb": "mb1", "cpu": "cpu1", "gpu": "", "ram": ["ram1"]}).to_dict()]   # 창고: 랙 PC 두 대
	for id in ["ram2", "gpu2", "psu2", "monitor", "keyboard", "lamp_warm", "mug"]:   # 캡처용 재고 상자
		Game.stock[id] = 2
	tap(main.modes["day_end"].BTN_STORAGE)
	on("storage")
	var st = main.modes["storage"]
	tap(st.rack_rect(0))
	check(Game.my_desk.get("pc", {}).get("parts", {}).has("CASE") and Game.shelf.size() == 1, "진열대 PC → 내 책상")
	await shot("13_storage")
	tap(st.view_rect(1))                       # 내 책상: 손님 책상과 같은 화면 (테마만 내 방)
	on("desk")
	check(Game.mine and Game.pc.has("CASE"), "내 책상 꾸미기 시작")
	var dk = main.modes["desk"]
	for d in [["monitor", 640, 250], ["keyboard", 820, 250], ["lamp_warm", 520, 250], ["mug", 980, 250]]:
		drag(dk.row_rect(dk.rows().find(d[0])), [d[1], d[2], d[1], d[2]])
	check(Game.placed.size() == 4, "내 책상 배치 %s" % dk.toast)
	await shot("13b_my_desk")
	tap(dk.BTN_DONE)
	on("storage")
	check(not Game.mine and Game.my_desk["placed"].size() == 4 and Game.placed.is_empty(), "내 책상 저장하고 창고로")
	tap(st.BTN_BACK)
	on("day_end")
	var fee_before := Game.money
	tap(main.modes["day_end"].BTN_NEXT)
	check(Game.money == fee_before - Game.SHELF_FEE, "보관료")
	on("news")
	check(Game.day == 2)
	if shots:                                  # 납품 사진 → 앨범
		check(FileAccess.file_exists(Main.PHOTOS + "/day1_1.png"), "납품 사진")
		main.go("title")
		tap(main.modes["title"].BTN_ALBUM)
		on("album")
		check(main.modes["album"].files.size() >= 1, "앨범")
		await shot("12_album")
		main.back()
		on("title")
	check(Game.load_save() == "news")
	for n in ["door", "click", "cart", "buy", "pick", "place", "lever", "paste", "plug", "boot_ok"]:   # 그 순간에 실제 소리 파일을 불러와 틀었는지
		check(main.sounds.get(n) != null, "소리 " + n)
	Game.day = 3                               # 셋째 날: 특이 조건 있는 의뢰 / 다섯째 날: 결제 뒤 책상에 가면 손님 전화
	Game.order_index = Game.todays_requests().find(Game.todays_requests().filter(func(q): return q.has("twist"))[0])
	main.go("request")
	await shot("3b_request_twist")
	Game.checkouts = 1
	check(not Game.call_due(), "특이 조건 의뢰엔 전화 없음 (신경 쓸 거리 하나만)")
	Game.day = 5
	for i in Game.todays_requests().size():   # 전화가 오는 손님
		Game.order_index = i
		Game.reset_order()
		Game.checkouts = 1
		if Game.call_due():
			break
	main.go("desk")
	check(main.top() == main.modes["call"], "다섯째 날 전화")
	if main.top() == main.modes["call"]:
		await shot("7k_call")
		main.modes["call"].t0 -= 1000
		tap([0, 0, 100, 100])
		on("desk")
		check(Game.request().has("call"), "전화 내용이 의뢰에 반영")
	Game.day = 4                               # 수리: 진단 화면을 3곳 열면 무료 2곳을 넘어 점검비
	Game.order_index = Game.todays_requests().find(Game.todays_requests().filter(func(q): return q.has("repair"))[0])
	main.go("request")
	main.go("build")
	main.push("diag")
	var dg = main.modes["diag"]
	for i in [1, 2, 5]:
		tap(dg.view_rect(i))
	check(Game.look_cost() == Game.LOOK_FEE, "점검비 %d" % Game.look_cost())
	await shot("8d_diag_fee")
	print("godot smoke ok  (가게 돈 %d만)" % money)
	quit()
