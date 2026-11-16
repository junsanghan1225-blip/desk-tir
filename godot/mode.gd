class_name Mode
## 화면 하나의 바탕. 그리기 도우미는 pico2d 버전과 같은 좌표(1280x720, y가 위로 커짐)를 받아 그릴 때만 뒤집는다.
## 사각형은 [x1, y1, x2, y2].

const H := 720
const MIN_TEXT := 16
const OUTLINE := Color8(5, 3, 12)
const INK := Color8(232, 226, 255)
const QUIET := Color8(170, 160, 220)
const DIM := Color8(90, 78, 130)
const CYAN := Color8(46, 230, 214)
const PINK := Color8(255, 77, 141)
const GOLD := Color8(255, 214, 92)
const GREEN := Color8(120, 255, 170)
const VIOLET := Color8(124, 92, 255)
const PANEL := Color8(34, 24, 70)
const BG := Color8(18, 12, 38)
const DARK := Color8(24, 16, 52)
const TABS := [["shop", "1 쇼핑"], ["desk", "2 책상"], ["build", "3 PC 조립"], ["wire", "4 배선"]]

var m: Main          # main.gd (그리기 대상 · 화면 전환)
var overlay := false    # true면 아래 화면 위에 겹쳐 그린다


func enter() -> void:
	pass


func sfx(n: String) -> void:
	m.sfx(n)


func draw() -> void:
	pass


## right = 우클릭 또는 더블탭 (터치에서는 더블탭이 '빼기')
func down(_x: float, _y: float, _right: bool) -> void:
	pass


func up(_x: float, _y: float) -> void:
	pass


func inside(x: float, y: float, r: Array) -> bool:
	return Rules.inside(x, y, r)


func grow(r: Array, k: float) -> Array:
	return [r[0] - k, r[1] - k, r[2] + k, r[3] + k]


func center(r: Array) -> Vector2:
	return Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)


func _rect(r: Array) -> Rect2:
	return Rect2(r[0], H - r[3], r[2] - r[0], r[3] - r[1])


func box(r: Array, c: Color) -> void:
	m.draw_rect(_rect(r), c)


func outline(r: Array, c := VIOLET, w := 1.0) -> void:
	m.draw_rect(_rect(r), c, false, w)


## (x, y) = 글자 왼쪽 · 세로 가운데. 폰에서 읽히도록 MIN_TEXT보다 작게는 안 그린다.
func text(x: float, y: float, s, size := 18, c := INK) -> void:
	size = max(size, MIN_TEXT)
	var pos := Vector2(x, H - y + (m.font.get_ascent(size) - m.font.get_descent(size)) / 2.0)   # 글자 세로 가운데
	m.draw_string_outline(m.font, pos, str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, OUTLINE)   # 픽셀 게임식 검은 외곽선
	m.draw_string(m.font, pos, str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 가운데 (cx, cy)에 원래 크기로
func spr(name: String, cx: float, cy: float) -> void:
	var t := DB.tex(name)
	m.draw_texture(t, Vector2(cx, H - cy) - t.get_size() / 2.0)


## 사각형에 꽉 맞춰
func put(name: String, r: Array) -> void:
	m.draw_texture_rect(DB.tex(name), _rect(r), false)


## 비율을 유지한 채 상자 안에 맞춰 (썸네일 · 아이콘)
func fit(name: String, cx: float, cy: float, mw: float, mh: float) -> void:
	var s := DB.tex(name).get_size()
	var k: float = min(mw / s.x, mh / s.y)
	put(name, [cx - s.x * k / 2, cy - s.y * k / 2, cx + s.x * k / 2, cy + s.y * k / 2])


static var _styles := {}


## 픽셀 테두리 판 (resource/ui_*.png, 9-slice). tint를 곱해서 색을 입힌다.
func frame(name: String, r: Array, tint := Color.WHITE) -> void:
	var key := name + tint.to_html()
	if not _styles.has(key):
		var sb := StyleBoxTexture.new()
		sb.texture = DB.tex(name)
		sb.set_texture_margin_all(12)
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.modulate_color = tint
		_styles[key] = sb
	m.draw_style_box(_styles[key], _rect(r))


func panel(r: Array, hot := false) -> void:
	frame("ui_panel_pink" if hot else "ui_panel", r)


## 두께 있는 버튼: 글자는 윗면 가운데
func button(r: Array, label: String, c := CYAN) -> void:
	frame("ui_button", r, c)
	text(r[0] + 14, (r[1] + r[3]) / 2.0 + 1, label, 18, Color.WHITE)


func line(a: Vector2, b: Vector2, c: Color, w := 2.0) -> void:
	m.draw_line(Vector2(a.x, H - a.y), Vector2(b.x, H - b.y), c, w)


func polyline(pts: Array, c: Color, w := 4.0) -> void:
	m.draw_polyline(PackedVector2Array(pts.map(func(p): return Vector2(p.x, H - p.y))), c, w)


func circle(x: float, y: float, radius: float, c: Color) -> void:
	m.draw_circle(Vector2(x, H - y), radius, c)


func dim() -> void:
	box([0, 0, 1280, H], Color(0.04, 0.02, 0.09, 0.65))


func icon_of(id: String) -> String:
	if DB.ITEMS.has(id) or DB.PARTS[id]["type"] == "CASE":
		return id
	return "part_" + DB.PARTS[id]["type"]


# ---------- 주문 작업 화면 공통: 상단 바 + 탭 ----------
func tab_rect(i: int) -> Array:
	var x := 560 + i * 118
	return [x, 656, x + 112, 690]


func tab_at(x: float, y: float) -> String:
	for i in TABS.size():
		if inside(x, y, tab_rect(i)):
			return TABS[i][0]
	return ""


func top_bar(current: String) -> void:
	var req := Game.request()
	frame("ui_panel", [-12, H - 74, 1292, H + 12])
	text(20, H - 24, "%d일차 손님 %d/%d  ·  %s" % [Game.day, Game.order_index + 1, Game.todays_requests().size(), req["customer"]], 20, CYAN)
	text(20, H - 52, "\"%s\"" % Game.lines()[0], 16, Color.WHITE)
	var left := Game.money_left()
	text(1080, H - 24, "손님 예산 %d만" % req["budget"], 16, QUIET)
	text(1080, H - 52, "남은 예산 %d만" % left, 18, CYAN if left >= 0 else PINK)
	var wire := Rules.wiring_score(Game.cables, Game.placed)
	for i in TABS.size():
		var r := tab_rect(i)
		var on: bool = TABS[i][0] == current
		frame("ui_button", r, PINK if on else Color8(80, 66, 140))
		text(r[0] + 12, (r[1] + r[3]) / 2.0 + 1, TABS[i][1], 16, Color.WHITE if on else QUIET)
		if TABS[i][0] == "wire" and (wire[1] > 0 or wire[2] > 0):
			box([r[2] - 16, r[3] - 16, r[2] - 6, r[3] - 6], PINK)  # 미연결 · 꼬임이 있으면 빨간 점


## 탭을 눌렀으면 그 화면으로 가고 true
func tabs(x: float, y: float) -> bool:
	var tab := tab_at(x, y)
	if tab != "":
		sfx("click")
		m.go(tab)
	return tab != ""


func grid() -> void:
	box([0, 0, 1280, H], BG)
