class_name Mode
## 화면 하나의 바탕. 그리기 도우미는 pico2d 버전과 같은 좌표(1280x720, y가 위로 커짐)를 받아 그릴 때만 뒤집는다.
## 사각형은 [x1, y1, x2, y2].

const H := 720
const MIN_TEXT := 22   # 폰에서 읽히는 최소 크기 (갈무리 글꼴은 11의 배수에서 가장 또렷함)
const BAR := 640      # 위쪽 바 아래 경계: 화면 작업 영역은 0 ~ BAR
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
const TABS := [["shop", "쇼핑"], ["desk", "책상"], ["build", "조립"], ["wire", "배선"]]

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
func button(r: Array, label: String, c := CYAN, size := 22) -> void:
	frame("ui_button", r, c)
	text_c(r, label, size, Color.WHITE)


func text_w(s: String, size: int) -> float:
	return m.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, max(size, MIN_TEXT)).x


## 너비에 맞게 단어 단위로 줄바꿈 (한 단어가 너무 길면 글자 단위로)
func wrap_text(s: String, width: float, size := 22) -> Array:
	var lines := [""]
	for w in s.split(" "):
		var t: String = (lines[-1] + " " + w).strip_edges()
		if text_w(t, size) <= width or lines[-1] == "":
			lines[-1] = t
		else:
			lines.append(w)
	var out := []
	for line: String in lines:
		var l := line
		while text_w(l, size) > width and l.length() > 1:
			var n: int = l.length()
			while n > 1 and text_w(l.left(n), size) > width:
				n -= 1
			out.append(l.left(n))
			l = l.substr(n)
		out.append(l)
	return out


## 사각형 가운데에 (버튼 윗면 기준으로 살짝 위)
func text_c(r: Array, s: String, size := 22, c := INK) -> void:
	text((r[0] + r[2]) / 2.0 - text_w(s, size) / 2.0, (r[1] + r[3]) / 2.0 + 2, s, size, c)


func line(a: Vector2, b: Vector2, c: Color, w := 2.0) -> void:
	m.draw_line(Vector2(a.x, H - a.y), Vector2(b.x, H - b.y), c, w)


func polyline(pts: Array, c: Color, w := 4.0) -> void:
	m.draw_polyline(PackedVector2Array(pts.map(func(p): return Vector2(p.x, H - p.y))), c, w)


func circle(x: float, y: float, radius: float, c: Color) -> void:
	m.draw_circle(Vector2(x, H - y), radius, c)


# ---------- 성능 그래프 ----------
const A0 := PI * 0.75   # 계기판: 왼쪽 아래(0) → 위 → 오른쪽 아래(1)
const A1 := PI * 2.25


func arc(cx: float, cy: float, rad: float, f0: float, f1: float, c: Color, w := 20.0) -> void:
	if f1 > f0:
		m.draw_arc(Vector2(cx, H - cy), rad, A0 + f0 * (A1 - A0), A0 + f1 * (A1 - A0), 48, c, w)


func at_angle(cx: float, cy: float, rad: float, f: float) -> Vector2:
	var a: float = A0 + f * (A1 - A0)
	return Vector2(cx + cos(a) * rad, cy - sin(a) * rad)   # 화면 각도 → 게임 좌표(y 위)


## 속도계: frac = 바늘 위치(0~1), tf = 목표 위치, good_high = 클수록 좋은지
func gauge(cx: float, cy: float, rad: float, frac: float, tf: float, good_high: bool, big: String, unit: String, target_label: String) -> void:
	arc(cx, cy, rad, 0, 1, Color8(30, 22, 60), 30)
	var bad := Color(PINK, 0.75)
	var good := Color(GREEN, 0.75)
	arc(cx, cy, rad, 0, tf, bad if good_high else good, 22)
	arc(cx, cy, rad, tf, 1, good if good_high else bad, 22)
	for i in 11:
		line(at_angle(cx, cy, rad - 22, i / 10.0), at_angle(cx, cy, rad - 12, i / 10.0), DIM, 2)
	line(at_angle(cx, cy, rad - 26, tf), at_angle(cx, cy, rad + 24, tf), GOLD, 5)
	var tp := at_angle(cx, cy, rad + 40, tf)
	text(tp.x - text_w(target_label, 22) / 2.0, tp.y, target_label, 22, GOLD)
	line(Vector2(cx, cy), at_angle(cx, cy, rad - 18, clampf(frac, 0, 1)), Color.WHITE, 6)
	circle(cx, cy, 12, Color.WHITE)
	text(cx - text_w(big, 44) / 2.0, cy - 50, big, 44, Color.WHITE)
	text(cx - text_w(unit, 22) / 2.0, cy - 88, unit, 22, QUIET)


## 온도계: 0~110°C, 위험(빨강) 85 이상
func thermo(x: float, y0: float, h: float, temp: float, label: String) -> void:
	var hot := temp >= 85
	box([x - 10, y0, x + 10, y0 + h], Color8(30, 22, 60))
	box([x - 6, y0 + 4, x + 6, y0 + 4 + (h - 8) * clampf(temp / 110.0, 0, 1)], PINK if hot else (GOLD if temp >= 70 else CYAN))
	circle(x, y0, 16, PINK if hot else (GOLD if temp >= 70 else CYAN))
	text(x - text_w(label, 22) / 2.0, y0 - 34, label, 22, INK)
	text(x + 20, y0 + h - 12, "%d°" % temp, 22, PINK if hot else INK)


# ---------- 모니터 속 앱: 손님 용도대로 돌아감 (게임은 계산된 FPS만큼 부드럽거나 끊김) ----------
func draw_app(s: Array, r: Dictionary, t: float, show_fps := true) -> void:
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	box(s, Color8(10, 8, 24))
	match r.get("kind", "office"):
		"game":
			var ratio: float = r["value"] / maxf(r["target"], 1.0)
			var shown_fps: float = 60.0 if ratio >= 1.0 else clampf(60.0 * ratio * ratio, 6.0, 60.0)   # 목표 미달 → 눈에 띄게 끊김
			var tt: float = floor(t * shown_fps) / shown_fps
			if r.get("ram_low", false) and fmod(t, 2.2) < 0.35:   # RAM 부족: 주기적으로 멈칫
				tt = floor((t - fmod(t, 2.2)) * shown_fps) / shown_fps
			box([s[0], s[1] + sh * 0.25, s[2], s[3]], Color8(26, 16, 56))
			for i in 9:   # 먼 빌딩
				var bx: float = s[0] + fposmod(i * sw / 7.0 - tt * sw * 0.08, sw + sw / 7.0) - sw / 14.0
				var bh: float = sh * (0.25 + 0.2 * fposmod(i * 0.37, 1.0))
				box([maxf(s[0], bx), s[1] + sh * 0.2, minf(s[2], bx + sw / 9.0), s[1] + sh * 0.2 + bh], Color8(44, 30, 90))
			for i in 7:   # 가까운 빌딩 + 창문
				var bx: float = s[0] + fposmod(i * sw / 5.0 - tt * sw * 0.22, sw + sw / 5.0) - sw / 10.0
				var bh: float = sh * (0.18 + 0.25 * fposmod(i * 0.61, 1.0))
				var rr := [maxf(s[0], bx), s[1] + sh * 0.2, minf(s[2], bx + sw / 7.0), s[1] + sh * 0.2 + bh]
				if rr[2] > rr[0]:
					box(rr, Color8(60, 40, 120))
					if rr[2] - rr[0] > 8:
						box([rr[0] + 3, rr[3] - sh * 0.06, rr[0] + 6, rr[3] - sh * 0.04], GOLD)
			box([s[0], s[1], s[2], s[1] + sh * 0.2], Color8(20, 14, 40))   # 바닥
			box([s[0], s[1] + sh * 0.2 - 2, s[2], s[1] + sh * 0.2], PINK)
			var py: float = s[1] + sh * 0.2 + absf(sin(tt * 4.0)) * sh * 0.22   # 달리며 점프하는 캐릭터
			box([s[0] + sw * 0.2, py, s[0] + sw * 0.2 + sw * 0.04, py + sh * 0.1], CYAN)
			for i in 3:   # 다가오는 장애물
				var ox: float = s[0] + fposmod(sw * (0.5 + i * 0.45) - tt * sw * 0.45, sw * 1.3)
				if ox < s[2] - sw * 0.03:
					box([ox, s[1] + sh * 0.2, ox + sw * 0.03, s[1] + sh * 0.28], PINK)
			if show_fps:
				var lbl := "%d FPS" % roundi(r["value"])
				box([s[2] - text_w(lbl, 22) - 16, s[3] - 34, s[2] - 4, s[3] - 4], Color(0, 0, 0, 0.6))
				text(s[2] - text_w(lbl, 22) - 10, s[3] - 19, lbl, 22, GREEN if ratio >= 1.0 else PINK)
		"render", "code":
			var dur: float = r["value"] * (0.45 if r["kind"] == "render" else 0.06)   # 1분 = 0.45초, 1초 = 0.06초로 압축
			var p: float = clampf(t / maxf(dur, 0.1), 0.0, 1.0)
			if r["kind"] == "render":
				for i in 4:   # 렌더 중인 영상 미리보기 칸
					var fx: float = s[0] + 10 + i * (sw - 20) / 4.0
					box([fx, s[3] - sh * 0.55, fx + (sw - 20) / 4.0 - 8, s[3] - 10], [Color8(60, 40, 120), Color8(46, 120, 130), Color8(120, 40, 90), Color8(90, 70, 30)][i] if p * 4 > i else Color8(30, 22, 60))
			else:
				for i in int(p * 8):   # 빌드 터미널 줄
					box([s[0] + 10, s[3] - 14 - i * sh * 0.07, s[0] + 10 + sw * (0.3 + 0.08 * (i % 4)), s[3] - 9 - i * sh * 0.07], GREEN if i % 3 else CYAN)
			box([s[0] + 10, s[1] + 10, s[2] - 10, s[1] + 26], Color8(30, 22, 60))   # 진행 막대
			box([s[0] + 12, s[1] + 12, s[0] + 12 + (sw - 24) * p, s[1] + 24], GREEN if p >= 1.0 else GOLD)
			if show_fps and sh > 120:
				var lbl := ("완료! " if p >= 1.0 else "%d%%  " % roundi(p * 100)) + Bench.value_text(r)
				text(s[0] + 12, s[1] + 46, lbl, 22, GREEN if p >= 1.0 and r["ok"] else INK)
		_:
			for i in 4:   # 화상회의 4명
				var tx: float = s[0] + 6 + (i % 2) * (sw - 12) / 2.0
				var ty: float = s[1] + 6 + (i / 2) * (sh - 12) / 2.0
				var tw: float = (sw - 12) / 2.0 - 4
				var tht: float = (sh - 12) / 2.0 - 4
				box([tx, ty, tx + tw, ty + tht], [Color8(46, 60, 120), Color8(60, 40, 100), Color8(40, 90, 100), Color8(90, 50, 90)][i])
				circle(tx + tw / 2.0, ty + tht * 0.55 + sin(t * 2.0 + i) * 2.0, minf(tw, tht) * 0.18, Color8(255, 214, 180))
				box([tx + tw * 0.3, ty, tx + tw * 0.7, ty + tht * 0.3], [CYAN, PINK, GOLD, VIOLET][i])


func dim() -> void:
	box([0, 0, 1280, H], Color(0.04, 0.02, 0.09, 0.65))


func icon_of(id: String) -> String:
	if DB.ITEMS.has(id) or DB.PARTS[id]["type"] == "CASE":
		return id
	return "part_" + DB.PARTS[id]["type"]


# ---------- 주문 작업 화면 공통: 상단 바 + 탭 ----------
func tab_rect(i: int) -> Array:
	var x := 452 + i * 168
	return [x, 648, x + 160, 714]


func tab_at(x: float, y: float) -> String:
	for i in TABS.size():
		if inside(x, y, tab_rect(i)):
			return TABS[i][0]
	return ""


func top_bar(current: String) -> void:
	var req := Game.request()
	frame("ui_panel", [-12, BAR, 1292, H + 12])
	text(16, H - 24, "%d일차 · %s" % [Game.day, req["customer"]], 22, CYAN)   # 손님이 한 말은 ll(일시정지)에서 다시 봄
	var left := Game.money_left()
	text(16, H - 56, "남은 예산 %d만 / %d만" % [left, req["budget"]], 22, INK if left >= 0 else PINK)
	var wire := Rules.wiring_score(Game.cables, Game.placed)
	for i in TABS.size():
		var r := tab_rect(i)
		var on: bool = TABS[i][0] == current
		frame("ui_button", r, PINK if on else Color8(80, 66, 140))
		text_c(r, TABS[i][1], 22, Color.WHITE if on else QUIET)
		if TABS[i][0] == "wire" and (wire[1] > 0 or wire[2] > 0):
			box([r[2] - 22, r[3] - 22, r[2] - 10, r[3] - 10], PINK)  # 미연결 · 꼬임이 있으면 빨간 점


## 탭을 눌렀으면 그 화면으로 가고 true
func tabs(x: float, y: float) -> bool:
	var tab := tab_at(x, y)
	if tab != "":
		sfx("click")
		m.go(tab)
	return tab != ""


func grid() -> void:
	box([0, 0, 1280, H], BG)
