extends "res://godot/smoke.gd"

func run() -> void:
	await process_frame
	Game.day = 3
	Game.order_index = 0
	main.go("request")
	main.go("shop")
	var s = main.modes["shop"]
	s.cat = "plant"
	await shot("props_shop")
	Game.placed = []
	var i := 0
	for id in ["monitor", "bonsai", "salt_lamp", "book_stack", "stream_deck", "tumbler", "headphone_stand", "rgb_cube", "lucky_cat", "humidifier"]:
		Rules.place_slot(Game.placed, id, "desk", i)
		i += 1
	var j := 0
	for id in ["hex_light", "acoustic", "neon_gg", "vinyl_frame"]:
		Rules.place_slot(Game.placed, id, "wall", j)
		j += 1
	main.go("desk")
	await shot("props_desk")
	quit(0)
