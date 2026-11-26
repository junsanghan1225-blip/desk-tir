extends "res://godot/smoke.gd"
## 마구 누르기 테스트: 날마다 조립 · 책상 · 배선 · 쇼핑을 무작위로 탭 · 드래그해서 오류가 안 나는지. 실행: Godot --path . --script godot/fuzz.gd

func run() -> void:
	await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	Game.new_game()
	Game.money = 9999
	for id in DB.PARTS:
		Game.stock[id] = 2
	for id in DB.ITEMS:
		Game.stock[id] = 1
	for k in 4:
		Game.used.append({"id": DB.PARTS.keys()[rng.randi() % DB.PARTS.size()], "cond": rng.randi_range(20, 100), "paid": 3, "known": false, "note": ""})
	for day in [1, 2, 3, 4, 5]:
		Game.day = day
		Game.order_index = Game.todays_requests().size() - 1
		Game.reset_order()
		for mode in ["build", "desk", "wire", "shop", "build"]:
			main.go(mode)
			for i in 400:
				var a := [rng.randf_range(0, 1280), rng.randf_range(0, 640)]
				var b := [rng.randf_range(0, 1280), rng.randf_range(0, 640)]
				if main.top() != main.modes[mode] and main.top() != main.modes["diag"] and main.top() != main.modes["bench"]:
					main.go(mode)
				var r := rng.randf()
				if r < 0.5:
					drag([a[0], a[1], a[0], a[1]], [b[0], b[1], b[0], b[1]])
				else:
					tap([a[0], a[1], a[0], a[1]], r > 0.85)
				if i % 50 == 0:
					await process_frame
			await process_frame
		for i in 300:   # 창고: 주문 중(일시정지 → 창고)에 마구 누르기
			if main.top() != main.modes["storage"]:
				main.go("build")
				main.push("storage")
			var px := rng.randf_range(0, 1280)
			var py := rng.randf_range(0, 720)
			tap([px, py, px, py])
			if i % 50 == 0:
				await process_frame
	print("fuzz2 done")
	quit(0)
