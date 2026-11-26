extends Mode
## 배선 정리 (책상 뒤 시점): 기기를 끌어 같은 색 포트에 꽂는다. 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다.

const BTN_DONE := [1100, 10, 1270, 50]
const BTN_AUTO := [900, 10, 1090, 50]
const HINT := {"HDMI": "모니터는 HDMI · DP 포트에", "DP": "모니터는 HDMI · DP 포트에", "USB": "USB 기기는 USB 포트에", "AUDIO": "스피커 · 헤드셋은 오디오 포트에"}
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
		if abs(x - Rules.plug_pos(p, Game.placed).x) <= 60 and y >= Rules.PLUG_Y - 20 and y <= DEV_Y + 60:
			return p
	return null


func down(x: float, y: float, right: bool) -> void:
	if tabs(x, y):
		return
	if inside(x, y, BTN_DONE):
		m.done()
		return
	if inside(x, y, BTN_AUTO):
		var before := Game.cables.size()
		Game.cables = Rules.auto_plug(Game.cables, Game.placed, Game.computer())
		toast = "%d개 꽂았어요. 꼬인 선은 끌어서 다시 꽂으면 정리돼요" % (Game.cables.size() - before) if Game.cables.size() > before else "더 꽂을 게 없어요"
		sfx("plug" if Game.cables.size() > before else "click")
		return
	var port = Rules.port_at(x, y, Game.computer())
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
	var port = Rules.port_at(x, y, Game.computer())
	var video := ["HDMI", "DP"]   # 모니터는 보통 HDMI · DP 입력이 둘 다 있음 → 남는 쪽에 꽂으면 됨
	if port != null and port[0] != need and not (need in video and port[0] in video):
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


const SHELL := Color8(201, 204, 214)
const HOLE := Color8(14, 12, 22)


## 실제 단자 모양: HDMI(아래가 좁은 사다리꼴) · DP(한쪽 모서리만 깎임) · USB-A(파란 혀) · 오디오(동그란 잭)
func jack(t: String, c: Vector2, live: bool) -> void:
	var a := 1.0 if live else 0.35
	var sh := Color(SHELL, a)
	match t:
		"HDMI":
			poly([Vector2(c.x - 20, c.y + 8), Vector2(c.x + 20, c.y + 8), Vector2(c.x + 20, c.y - 2), Vector2(c.x + 14, c.y - 8), Vector2(c.x - 14, c.y - 8), Vector2(c.x - 20, c.y - 2)], sh)
			poly([Vector2(c.x - 17, c.y + 5), Vector2(c.x + 17, c.y + 5), Vector2(c.x + 17, c.y - 1), Vector2(c.x + 12, c.y - 5), Vector2(c.x - 12, c.y - 5), Vector2(c.x - 17, c.y - 1)], HOLE)
			box([c.x - 12, c.y, c.x + 12, c.y + 3], Color(GOLD, a))
		"DP":
			poly([Vector2(c.x - 19, c.y + 8), Vector2(c.x + 19, c.y + 8), Vector2(c.x + 19, c.y - 3), Vector2(c.x + 13, c.y - 8), Vector2(c.x - 19, c.y - 8)], sh)
			poly([Vector2(c.x - 16, c.y + 5), Vector2(c.x + 16, c.y + 5), Vector2(c.x + 16, c.y - 2), Vector2(c.x + 11, c.y - 5), Vector2(c.x - 16, c.y - 5)], HOLE)
			box([c.x - 12, c.y - 1, c.x + 10, c.y + 2], Color(GOLD, a))
		"USB":
			box([c.x - 16, c.y - 8, c.x + 16, c.y + 8], sh)
			box([c.x - 13, c.y - 5, c.x + 13, c.y + 5], HOLE)
			box([c.x - 13, c.y + 1, c.x + 13, c.y + 5], Color(Color8(31, 91, 209), a))   # USB 3.0 파란 혀
		_:
			circle(c.x, c.y, 11, Color(Color8(86, 176, 138) if c.x < Rules.port_pos("AUDIO", 1).x - 1 else Color8(255, 143, 180), a))   # 초록 = 스피커 · 분홍 = 마이크
			circle(c.x, c.y, 6, HOLE)


## 꽂힌 플러그 머리 (단자 위로 튀어나온 커넥터 + 선)
func plug_head(t: String, c: Vector2, col: Color) -> void:
	var w: float = {"HDMI": 22.0, "DP": 21.0, "USB": 17.0}.get(t, 7.0)
	box([c.x - w, c.y + 6, c.x + w, c.y + 34], Color8(36, 34, 44))
	box([c.x - w, c.y + 6, c.x + w, c.y + 10], SHELL)
	if t == "DP":   # DP 걸쇠 버튼
		box([c.x - 6, c.y + 22, c.x + 6, c.y + 28], Color8(90, 88, 100))
	box([c.x - 4, c.y + 34, c.x + 4, c.y + 44], col)


func draw_ports() -> void:
	var pn: Array = Rules.PORT_PANEL
	panel(grow(pn, 8))
	text(pn[0], pn[3] + 16, "PC 후면 포트", 16, QUIET)
	for t in Rules.PORT_ORDER:
		var n := Rules.port_count(t, Game.computer())
		var col: Color = Rules.PORT_COLOR[t]
		for i in Rules.MAX_PORTS[t]:
			var pp := Rules.port_pos(t, i)
			var r := [pp.x - 30, pp.y - 18, pp.x + 30, pp.y + 18]
			box(r, Color8(40, 38, 52) if i < n else Color8(22, 18, 34))   # 뒷판
			outline(r, col if i < n else Color8(50, 42, 80))
			jack(t, pp, i < n)
		var label: String = Rules.PORT_NAMES[t]
		if t == "DP" or t == "HDMI":
			label += " %d" % n if n else " 없음"
		elif t == "USB":
			label += " %d개 · 메인보드" % n if n else " (보드를 장착하세요)"
		text(Rules.port_pos(t, 0).x - 28, pn[1] + 16, label, 16, col)


func draw() -> void:
	Game.cables = Rules.prune(Game.cables, Game.placed, Game.computer())
	grid()
	for gx in range(0, 1280, 40):
		line(Vector2(gx, 0), Vector2(gx, 650), Color8(30, 22, 60), 1)
	top_bar("wire")
	text(40, 610, "배선 정리  ·  책상 뒤", 24, PINK)
	text(40, 578, "기기를 끌어 포트에 꽂기 · 모니터는 HDMI · DP 아무 데나", 16, QUIET)
	text(40, 40, "두 번 누르기(우클릭): 선 뽑기 · 선이 엇갈리면 꼬임 감점", 16, QUIET)
	var devs := devices()
	for p in devs:
		var pos := Rules.plug_pos(p, Game.placed)
		var it: Dictionary = DB.ITEMS[p["id"]]
		var col: Color = Rules.PORT_COLOR[it["port"]]
		var r := [pos.x - 62, DEV_Y - 66, pos.x + 62, DEV_Y + 58]
		panel(r, Game.cables.any(func(c): return is_same(c["dev"], p)))
		fit(p["id"], pos.x, DEV_Y + 22, 100, 62)
		var nm: Array = wrap_text(it["name"], 104)   # 이웃 기기 이름과 겹치지 않게 두 줄까지
		for k in mini(2, nm.size()):
			text(pos.x - 52, DEV_Y - 24 - k * 24, nm[k], 13)
		if it.get("dongle", false):
			text(pos.x - 18, pos.y - 8, "무선", 13, col)
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
			cable(Rules.plug_pos(c["dev"], Game.placed), pp + Vector2(0, 44), Rules.PORT_COLOR[c["type"]])
			plug_head(c["type"], pp, Rules.PORT_COLOR[c["type"]])
	if wiring != null:
		var it: Dictionary = DB.ITEMS[wiring["id"]]
		if it.get("dongle", false):
			dongle(m.mouse.x, m.mouse.y, it["name"])
		else:
			cable(Rules.plug_pos(wiring, Game.placed), m.mouse, Rules.PORT_COLOR[it["port"]])
	var w := Rules.wiring_score(Game.cables, Game.placed)
	var ok: bool = w[1] == 0 and w[2] == 0
	text(880, 610, "미연결 %d   꼬임 %d" % [w[1], w[2]], 22, GREEN if ok else GOLD)
	if ok and not devs.is_empty():
		text(880, 578, "깔끔해요! 배선 만점", 16, GREEN)
	if toast != "":
		box([30, 62, 40 + text_w(toast, 22) + 20, 100], Color(0, 0, 0, 0.75))
		text(40, 81, toast, 22, PINK)
	button(BTN_AUTO, "한 번에 꽂기", VIOLET)
	button(BTN_DONE, "창고로" if Game.mine else "납품하기", PINK)
