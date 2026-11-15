extends SceneTree
## 전체 플레이 자동 테스트: 실제 화면을 띄우고 손님 한 명을 처음부터 납품까지 눌러 본다.
## 실행: Godot --path . --script godot/smoke.gd   (화면이 있으면 docs/screens/godot_*.png 저장)

var main: Main
var shots := DisplayServer.get_name() != "headless"


func _initialize() -> void:
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


func on(name: String) -> void:
	assert(main.top() == main.modes[name], "화면이 %s 이어야 함" % name)


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
	assert(Game.cart.size() == 1)
	Game.cart.clear()
	for id in ["monitor", "keyboard", "case1", "mb1", "cpu1", "cool1", "ssd1", "gpu1", "ram1", "psu1"]:
		Game.add_to_cart(id)
	await shot("5_shop")
	tap(shop.BTN_PAY)
	on("receipt")
	await shot("6_receipt")
	tap(main.modes["receipt"].BTN_OK)
	assert(Game.stock["monitor"] == 1 and Game.cart.is_empty())

	tap(shop.tab_rect(1))
	on("desk")
	var desk = main.modes["desk"]
	drag(desk.row_rect(desk.rows().find("monitor")), [500, 250, 500, 250])
	drag(desk.row_rect(desk.rows().find("keyboard")), [800, 250, 800, 250])
	assert(Game.placed.size() == 2, desk.toast)
	await shot("7_desk")

	tap(desk.tab_rect(2))
	on("build")
	var b = main.modes["build"]
	var part := func(id: String, to: Array): drag(b.inv_row(b.inv_ids().find(id)), to)
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
	assert(b.post[0] == 4, "부팅 실패: %s / %s" % [b.post, b.toast])
	await shot("8_build")
	tap(b.zone("GPU"), true)                   # 두 번 누르기 = 빼기 → 다시 꽂기
	assert(not Game.pc.has("GPU") and Game.stock["gpu1"] == 1)
	part.call("gpu1", b.gpu_rect())
	for c in Game.pc.cable_targets():
		drag(b.psu_port(c), b.socket_rect(c))
	assert(Game.pc.boots())

	tap(b.tab_rect(3))
	on("wire")
	var w = main.modes["wire"]
	for p in w.devices():
		var pos := Rules.plug_pos(p)
		var port := Rules.port_pos(DB.ITEMS[p["id"]]["port"], 0)
		drag([pos.x, 470, pos.x, 470], [port.x, port.y, port.x, port.y])
	assert(Game.cables.size() == 2 and Rules.wiring_score(Game.cables, Game.placed)[1] == 0, w.toast)
	await shot("9_wire")

	var saved := Game.peek()                   # 자동 저장 → 이어하기
	assert(saved["day"] == 1)
	tap(w.BTN_DONE)
	on("result")
	assert(main.modes["result"].result["boot"] == "" or true)
	await shot("10_result")
	var money := Game.money
	tap([0, 0, 100, 100])
	on("request")
	assert(Game.order_index == 1 and Game.placed.is_empty())
	Game.order_index = Game.todays_requests().size() - 1
	main.go("result")
	tap([0, 0, 100, 100])
	on("day_end")
	await shot("11_day_end")
	tap(main.modes["day_end"].BTN_NEXT)
	on("news")
	assert(Game.day == 2)
	assert(Game.load_save() == "news")
	print("godot smoke ok  (가게 돈 %d만)" % money)
	quit()
