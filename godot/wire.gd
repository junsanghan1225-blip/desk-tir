extends Mode
## 배선 정리 (책상 뒤 시점): 기기를 끌어 같은 색 포트에 꽂는다. 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다.

const BTN_DONE := [1100, 10, 1270, 50]
const HINT := {"DP": "모니터는 DP 포트에", "USB": "USB 기기는 USB 포트에", "AUDIO": "스피커 · 헤드셋은 오디오 포트에"}
const DEV_Y := 480

var wiring = null   # 선을 끌고 있는 기기
var toast := ""


func enter() -> void:
	wiring = null
	toast = ""


func devices() -> Array:
	return Game.placed.filter(Rules.needs_cable)


func device_at(x: float, y: float):
	for p in devices():
		if abs(x - Rules.plug_pos(p).x) <= 60 and y >= Rules.PLUG_Y - 20 and y <= DEV_Y + 60:
			return p
	return null


func down(x: float, y: float, right: bool) -> void:
	if tabs(x, y):
		return
	if inside(x, y, BTN_DONE):
		m.go("result")
		return
	var port = Rules.port_at(x, y, Game.pc)
	var p = device_at(x, y)
	if right:   # 포트나 기기의 선 뽑기
		Game.cables = Game.cables.filter(func(c): return [c["type"], c["port"]] != port and not is_same(c["dev"], p))
	elif p != null:
		Game.cables = Game.cables.filter(func(c): return not is_same(c["dev"], p))
		wiring = p
		toast = ""


func up(x: float, y: float) -> void:
	if wiring == null:
		return
	var need: String = DB.ITEMS[wiring["id"]]["port"]
	var port = Rules.port_at(x, y, Game.pc)
	if port != null and port[0] != need:
		toast = HINT[need] + " 꽂아야 해요"
		sfx("error")
	elif port != null and Game.cables.any(func(c): return [c["type"], c["port"]] == port):
		toast = "이미 쓰고 있는 포트예요"
		sfx("error")
	elif port != null:
		Game.cables.append({"dev": wiring, "type": port[0], "port": port[1]})
		sfx("plug")
	wiring = null


## 처지는 선: a → b 3차 베지어
func cable(a: Vector2, b: Vector2, c: Color) -> void:
	var mid := Vector2(0, (a.y + b.y) / 2.0)
	var pts := []
	for i in 25:
		pts.append(a.bezier_interpolate(Vector2(a.x, mid.y), Vector2(b.x, mid.y), b, i / 24.0))
	polyline(pts, c, 5)


func dongle(x: float, y: float, owner: String) -> void:
	box([x - 10, y - 14, x + 10, y + 14], Color8(200, 200, 215))
	box([x - 7, y - 22, x + 7, y - 14], Color8(150, 150, 165))
	box([x - 4, y + 6, x + 4, y + 10], CYAN)
	text(x - 30, y + 30, owner.left(6), 11, CYAN)


func draw_ports() -> void:
	var pn: Array = Rules.PORT_PANEL
	panel(grow(pn, 8))
	text(pn[0], pn[3] + 16, "PC 후면 포트", 16, QUIET)
	for t in Rules.PORT_ORDER:
		var n := Rules.port_count(t, Game.pc)
		var col: Color = Rules.PORT_COLOR[t]
		for i in Rules.MAX_PORTS[t]:
			var pp := Rules.port_pos(t, i)
			var r := [pp.x - 28, pp.y - 18, pp.x + 28, pp.y + 18]
			var used: bool = Game.cables.any(func(c): return c["type"] == t and c["port"] == i)
			box(r, col if used else DARK)
			outline(r, col if i < n else Color8(60, 50, 90))
			box([pp.x - 12, pp.y - 5, pp.x + 12, pp.y + 5], Color8(14, 9, 30))
		var label: String = Rules.PORT_NAMES[t]
		if t == "DP":
			label += " %d개 · 그래픽카드" % n if n else " (GPU를 장착하세요)"
		elif t == "USB":
			label += " %d개 · 메인보드" % n if n else " (보드를 장착하세요)"
		text(Rules.port_pos(t, 0).x - 28, pn[1] + 16, label, 16, col)


func draw() -> void:
	Game.cables = Rules.prune(Game.cables, Game.placed, Game.pc)
	grid()
	for gx in range(0, 1280, 40):
		line(Vector2(gx, 0), Vector2(gx, 650), Color8(30, 22, 60), 1)
	top_bar("wire")
	text(40, 610, "배선 정리  ·  책상 뒤", 24, PINK)
	text(40, 578, "기기를 끌어 같은 색 포트에 꽂기 · 무선은 USB 동글 · 선이 엇갈리면 꼬임 감점", 16, QUIET)
	text(40, 40, "두 번 누르기(우클릭): 선 뽑기", 16, QUIET)
	var devs := devices()
	for p in devs:
		var pos := Rules.plug_pos(p)
		var it: Dictionary = DB.ITEMS[p["id"]]
		var col: Color = Rules.PORT_COLOR[it["port"]]
		var r := [pos.x - 62, DEV_Y - 58, pos.x + 62, DEV_Y + 58]
		panel(r, Game.cables.any(func(c): return is_same(c["dev"], p)))
		fit(p["id"], pos.x, DEV_Y + 6, 100, 90)
		text(pos.x - 56, DEV_Y - 46, it["name"], 13)
		if it.get("dongle", false):
			text(pos.x - 18, pos.y + 4, "무선", 13, col)
		else:
			circle(pos.x, pos.y, 9, col)
	if devs.is_empty():
		text(360, 520, "책상 위에 모니터 · 키보드 · 스피커 같은 기기를 먼저 놓으세요", 18, GOLD)
	draw_ports()
	for c in Game.cables:
		var pp := Rules.port_pos(c["type"], c["port"])
		if Rules.is_dongle(c):
			dongle(pp.x, pp.y + 28, DB.ITEMS[c["dev"]["id"]]["name"])
		else:
			cable(Rules.plug_pos(c["dev"]), pp, Rules.PORT_COLOR[c["type"]])
	if wiring != null:
		var it: Dictionary = DB.ITEMS[wiring["id"]]
		if it.get("dongle", false):
			dongle(m.mouse.x, m.mouse.y, it["name"])
		else:
			cable(Rules.plug_pos(wiring), m.mouse, Rules.PORT_COLOR[it["port"]])
	var w := Rules.wiring_score(Game.cables, Game.placed)
	var ok: bool = w[1] == 0 and w[2] == 0
	text(880, 610, "미연결 %d   꼬임 %d" % [w[1], w[2]], 22, GREEN if ok else GOLD)
	if ok and not devs.is_empty():
		text(880, 578, "깔끔해요! 배선 만점", 16, GREEN)
	if toast != "":
		text(40, 80, toast, 18, PINK)
	button(BTN_DONE, "납품하기", PINK)
