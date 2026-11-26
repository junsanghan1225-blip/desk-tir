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
const TABS := [["shop", "쇼핑"], ["desk", "책상"], ["build", "조립"], ["wire", "배선"], ["storage", "창고"]]   # 창고는 위에 겹쳐 열림

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
	if x + text_w(str(s), size) > 1272 and x < 1180:   # 화면 오른쪽 끝을 넘으면 잘리지 않게 아래로 줄바꿈
		var lines := wrap_text(str(s), 1272 - x, size)
		if lines.size() > 1:
			for i in lines.size():
				text(x, y - i * size * 1.3, lines[i], size, c)
			return
	var pos := Vector2(x, H - y + (m.font.get_ascent(size) - m.font.get_descent(size)) / 2.0)   # 글자 세로 가운데
	m.draw_string_outline(m.font, pos, str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, OUTLINE)   # 픽셀 게임식 검은 외곽선
	m.draw_string(m.font, pos, str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)


## 가운데 (cx, cy)에 원래 크기로
func spr(name: String, cx: float, cy: float) -> void:
	var t := DB.tex(name)
	m.draw_texture(t, Vector2(cx, H - cy) - t.get_size() / 2.0)


## 사각형에 꽉 맞춰
## 소품은 DB.skin으로 새 화풍 그림. 비율이 조금 다른 PixelLab 그림은 비율을 지켜 바닥 가운데에 맞춤
func put(name: String, r: Array, tint := Color.WHITE) -> void:
	var s := DB.skin(name)
	if s.begins_with("pixellab/"):
		var t := DB.tex(s).get_size()
		var k: float = min((r[2] - r[0]) / t.x, (r[3] - r[1]) / t.y)
		var cx: float = (r[0] + r[2]) / 2.0
		r = [cx - t.x * k / 2, r[1], cx + t.x * k / 2, r[1] + t.y * k]   # y는 아래가 작음 → r[1]이 바닥
	m.draw_texture_rect(DB.tex(s), _rect(r), false, tint)


## 비율을 유지한 채 상자 안에 맞춰 (썸네일 · 아이콘)
func fit(name: String, cx: float, cy: float, mw: float, mh: float) -> void:
	var s := DB.tex(DB.skin(name)).get_size()
	var k: float = min(mw / s.x, mh / s.y)
	if s.y * k < mh * 0.5 and DB.ITEMS.has(name) and DB.PX.has(name) and DB._has("pixellab/" + DB.PX[name]):
		name = "pixellab/" + DB.PX[name]   # 가로로 긴 정면 그림(키보드 · 마우스)은 작은 칸에서 실선이 됨 → 비스듬히 본 아이콘
		s = DB.tex(name).get_size()
		k = min(mw / s.x, mh / s.y)
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
	var q := press_frame(r, c)
	text_c(q, label, size, Color.WHITE)


## 버튼 몸통: 아래 그림자 · 위 하이라이트(입체), 마우스를 올리면 밝게, 누르는 동안 그림자 쪽으로 쑥 들어감. 눌린 자리(글자 위치)를 돌려줌
func press_frame(r: Array, c: Color) -> Array:
	var hot := inside(m.mouse.x, m.mouse.y, r)
	var down: bool = hot and m.held_down
	var d := -3.0 if down else 0.0
	if not down:
		box([r[0] + 3, r[1] - 4, r[2] + 3, r[3] - 4], Color(0, 0, 0, 0.45))   # 바닥 그림자
	var q := [r[0], r[1] + d, r[2], r[3] + d]
	frame("ui_button", q, c.darkened(0.15) if down else c.lightened(0.12) if hot else c)
	box([q[0] + 8, q[3] - 9, q[2] - 8, q[3] - 6], Color(1, 1, 1, 0.10 if down else 0.22))   # 윗면 빛
	if hot and not down:
		outline(grow(q, 1), Color(1, 1, 1, 0.35), 1)
	return q


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


func poly(pts: Array, c: Color) -> void:   # 채운 다각형 (게임 좌표)
	m.draw_colored_polygon(PackedVector2Array(pts.map(func(p): return Vector2(p.x, H - p.y))), c)


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
	var bw: float = text_w(big, 44) + 20
	box([cx - bw / 2.0, cy - 76, cx + bw / 2.0, cy - 24], PANEL)   # 바늘이 숫자를 가리지 않게
	text(cx - text_w(big, 44) / 2.0, cy - 50, big, 44, Color.WHITE)
	text(cx - text_w(unit, 22) / 2.0, cy - 88, unit, 22, QUIET)


## 온도계: 0~110°C, 위험(빨강) 85 이상
func thermo(x: float, y0: float, h: float, temp: float, label: String, col := CYAN) -> void:
	var c: Color = PINK if temp >= 85 else GOLD if temp >= 70 else col
	box([x - 10, y0, x + 10, y0 + h], Color8(30, 22, 60))
	box([x - 6, y0 + 4, x + 6, y0 + 4 + (h - 8) * clampf(temp / 110.0, 0, 1)], c)
	circle(x, y0, 16, c)
	text(x - text_w(label, 22) / 2.0, y0 - 34, label, 22, INK)   # 이름: 아래 (세 칸 같은 높이)
	var v := "%d°C" % temp
	text(x - text_w(v, 22) / 2.0, y0 + h + 22, v, 22, PINK if temp >= 85 else INK)   # 값: 위 가운데


# ---------- 모니터 속 앱: 손님 용도대로 돌아감 (게임은 계산된 FPS만큼 부드럽거나 끊김) ----------
func draw_app(s: Array, r: Dictionary, t: float, show_fps := true) -> void:
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	box(s, Color8(10, 8, 24))
	match r.get("kind", "office"):
		"game":
			draw_game(s, r, t, show_fps)
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
	if DB.ITEMS.has(id):
		return id   # 소품은 put · fit이 DB.skin으로 책상 배치와 같은 그림을 씀
	if DB.px(id) != "":
		return DB.px(id)
	if DB.PARTS[id]["type"] == "CASE":
		return DB.look(id)
	return "part_" + DB.PARTS[id]["type"]


# ---------- 주문 작업 화면 공통: 상단 바 + 탭 ----------
func tab_rect(i: int) -> Array:
	var x := 452 + i * 137
	return [x, 648, x + 130, 714]


func tab_at(x: float, y: float) -> String:
	for i in TABS.size():
		if inside(x, y, tab_rect(i)):
			return TABS[i][0]
	return ""


func top_bar(current: String) -> void:
	var req := Game.request()
	frame("ui_panel", [-12, BAR, 1292, H + 12])
	text(16, H - 24, "%d일차 · %s ▾" % [Game.day, req["customer"]], 22, CYAN)   # 누르면 의뢰 메모   # 손님이 한 말은 ll(일시정지)에서 다시 봄
	var left := Game.money_left()
	var budget_s := "남는 돈으로 꾸미기" if Game.mine else "손님 예산 %d/%d만" % [left, req["budget"]]
	text(16, H - 56, budget_s, 22, INK if left >= 0 else PINK)   # 손님 돈 (이번 주문)
	var mx := 40.0 + text_w(budget_s, 22)   # 가게 돈 (모아서 해금에 씀): 금화 + 금색
	circle(mx, H - 56, 9, GOLD)
	circle(mx, H - 56, 5, Color8(200, 150, 40))
	text(mx + 16, H - 56, "가게 %d만" % Game.money, 22, GOLD)
	var wire := Rules.wiring_score(Game.cables, Game.placed)
	for i in TABS.size():
		var r := tab_rect(i)
		var on: bool = TABS[i][0] == current
		var q := press_frame(r, PINK if on else Color8(80, 66, 140))
		text_c(q, TABS[i][1], 22, Color.WHITE if on else QUIET)
		if TABS[i][0] == "wire" and (wire[1] > 0 or wire[2] > 0):
			box([r[2] - 22, r[3] - 22, r[2] - 10, r[3] - 10], PINK)  # 미연결 · 꼬임이 있으면 빨간 점


## 탭을 눌렀으면 그 화면으로 가고 true
func tabs(x: float, y: float) -> bool:
	var tab := tab_at(x, y)
	if tab == "storage":
		sfx("click")
		m.push("storage")
	elif tab != "":
		sfx("click")
		m.go(tab)
	return tab != ""


func grid() -> void:
	box([0, 0, 1280, H], BG)


## 딱지: 어두운 바탕 + 색 테두리 + 색 글씨 (진한 색 채우기 위 검은 글씨는 뭉개져 보여서)
func chip(x: float, y: float, s: String, c: Color) -> void:
	var r := [x, y - 18, x + text_w(s, 22) + 24, y + 18]
	box(r, Color(0.08, 0.06, 0.16, 0.9))
	outline(r, c, 2.0)
	text(x + 12, y, s, 22, c)


## 칸에 안 들어가는 이름은 끝을 '…'로 (겹치지 않게) → 마우스를 올리면 hover_tip()으로 전체 이름
func clip(s: String, w: float, size := 22) -> String:
	if text_w(s, size) <= w:
		return s
	while s.length() > 1 and text_w(s + "…", size) > w:
		s = s.left(s.length() - 1)
	return s.strip_edges() + "…"


## 말풍선: (x, y) 오른쪽에 전체 글자
func hover_tip(x: float, y: float, s: String) -> void:
	var w := text_w(s, 22) + 20
	box([x, y - 18, x + w, y + 18], Color(0.05, 0.03, 0.12, 0.95))
	outline([x, y - 18, x + w, y + 18], CYAN, 2)
	text(x + 10, y, s, 22, INK)


## ---------- 손님 게임 화면 (장르마다 다르게 · 사양이 모자라면 실제로 끊김) ----------
## 화면이 바뀌는 횟수 = 실제 FPS 느낌: 목표 이상이면 부드럽게, 모자랄수록 뚝뚝. 1% 최저가 낮으면 주기적으로 멈칫.
func game_clock(r: Dictionary, t: float) -> Array:   # [보이는 시각, 지금 멈칫 중인지]
	var ratio: float = r["value"] / maxf(r["target"], 1.0)
	var vis: float = 60.0 if ratio >= 1.0 else clampf(60.0 * ratio * ratio, 5.0, 50.0)
	var period := 1.7
	var stall := 0.0
	if r.get("ram_low", false):
		stall = 0.45
		period = 2.2
	elif r.get("low1", 9999) < r["target"] * 0.6:
		stall = lerpf(0.12, 0.35, 1.0 - clampf(r.get("low1", 0) / (r["target"] * 0.6), 0.0, 1.0))
	var ph := fmod(t, period)
	var hitch := stall > 0 and ph < stall
	var base := t - ph if hitch else t
	return [floor(base * vis) / vis, hitch]


func draw_game(s: Array, r: Dictionary, t: float, show_fps: bool) -> void:
	var gc := game_clock(r, t)
	var tt: float = gc[0]
	match r.get("genre", "fps"):
		"aos": game_aos(s, tt)
		"open": game_open(s, tt, r.get("vram_short", false))
		_: game_fps(s, tt)
	if r.get("stream", false):   # 방송 겸용: LIVE 표시 + 채팅
		box([s[0] + 8, s[3] - 30, s[0] + 74, s[3] - 8], Color8(220, 40, 60))
		text(s[0] + 14, s[3] - 19, "LIVE", 22, Color.WHITE)
		for k in 3:
			box([s[2] - 120, s[1] + 40 + k * 18, s[2] - 30 + (k * 23) % 40, s[1] + 50 + k * 18], Color(1, 1, 1, 0.35))
	if gc[1]:   # 멈칫한 순간: 화면이 살짝 찢어짐
		box([s[0], s[1] + (s[3] - s[1]) * 0.45, s[2], s[1] + (s[3] - s[1]) * 0.47], Color(1, 1, 1, 0.25))
	if show_fps:   # 오른쪽 위 FPS 표시 (멈칫하면 1% 최저로 뚝)
		var now: float = r.get("low1", r["value"] * 0.5) if gc[1] else r["value"] * (1.0 + 0.04 * sin(t * 7.0))
		var lbl := "%d FPS" % roundi(now)
		box([s[2] - text_w(lbl, 22) - 16, s[3] - 34, s[2] - 4, s[3] - 4], Color(0, 0, 0, 0.6))
		text(s[2] - text_w(lbl, 22) - 10, s[3] - 19, lbl, 22, GREEN if now >= r["target"] else GOLD if now >= r["target"] * 0.6 else PINK)


## FPS: 1인칭 복도 · 바닥 줄이 다가옴 · 적 · 조준점 · 총이 흔들리고 가끔 섬광
func game_fps(s: Array, tt: float) -> void:
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	var c := Vector2(s[0] + sw / 2.0, s[1] + sh * 0.55)
	box(s, Color8(24, 20, 40))
	poly([Vector2(s[0], s[1]), Vector2(s[2], s[1]), c + Vector2(sw * 0.12, -sh * 0.08), c + Vector2(-sw * 0.12, -sh * 0.08)], Color8(40, 34, 60))   # 바닥
	poly([Vector2(s[0], s[3]), Vector2(s[2], s[3]), c + Vector2(sw * 0.12, sh * 0.12), c + Vector2(-sw * 0.12, sh * 0.12)], Color8(30, 26, 48))   # 천장
	poly([Vector2(s[0], s[1]), Vector2(s[0], s[3]), c + Vector2(-sw * 0.12, sh * 0.12), c + Vector2(-sw * 0.12, -sh * 0.08)], Color8(52, 40, 86))   # 왼벽
	poly([Vector2(s[2], s[1]), Vector2(s[2], s[3]), c + Vector2(sw * 0.12, sh * 0.12), c + Vector2(sw * 0.12, -sh * 0.08)], Color8(46, 36, 78))   # 오른벽
	for k in 6:   # 다가오는 바닥 줄 (원근)
		var d := fposmod(k / 6.0 + tt * 0.6, 1.0)
		var y: float = lerpf(c.y - sh * 0.08, s[1], d * d)
		var hw: float = lerpf(sw * 0.12, sw * 0.5, d * d)
		line(Vector2(c.x - hw, y), Vector2(c.x + hw, y), Color8(90, 70, 150), 2)
	var ex: float = c.x + sin(tt * 1.3) * sw * 0.08   # 적
	box([ex - 8, c.y - sh * 0.06, ex + 8, c.y + sh * 0.06], PINK)
	circle(ex, c.y + sh * 0.08, 7, PINK)
	line(c + Vector2(-12, 0), c + Vector2(12, 0), Color.WHITE, 2)   # 조준점
	line(c + Vector2(0, -12), c + Vector2(0, 12), Color.WHITE, 2)
	var bob := sin(tt * 9.0) * 4.0
	poly([Vector2(s[2] - sw * 0.28, s[1]), Vector2(s[2] - sw * 0.08, s[1]), Vector2(s[2] - sw * 0.16, s[1] + sh * 0.28 + bob), Vector2(s[2] - sw * 0.22, s[1] + sh * 0.26 + bob)], Color8(70, 70, 84))   # 총
	if fmod(tt, 0.9) < 0.08:   # 총구 섬광
		circle(s[2] - sw * 0.19, s[1] + sh * 0.3 + bob, 12, GOLD)


## AOS: 위에서 본 맵 · 대각선 라인 · 미니언이 줄지어 감 · 탑 · 영웅 체력바 · 스킬 원
func game_aos(s: Array, tt: float) -> void:
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	box(s, Color8(30, 70, 50))
	for k in 12:   # 풀숲
		circle(s[0] + 16 + fposmod(k * 97.0, sw - 32), s[1] + 16 + fposmod(k * 61.0, sh - 32), 14, Color8(24, 56, 40))
	var a := Vector2(s[0] + sw * 0.08, s[1] + sh * 0.1)
	var b := Vector2(s[2] - sw * 0.08, s[3] - sh * 0.1)
	line(a, b, Color8(120, 100, 70), sh * 0.12)   # 라인
	for e in [[a.lerp(b, 0.2), CYAN], [a.lerp(b, 0.8), PINK]]:   # 탑
		box([e[0].x - 10, e[0].y - 10, e[0].x + 10, e[0].y + 22], e[1])
	for k in 5:   # 미니언 (양쪽에서)
		var p := a.lerp(b, fposmod(0.25 + k * 0.05 + tt * 0.08, 0.5))
		circle(p.x, p.y, 5, CYAN)
		var q := b.lerp(a, fposmod(0.25 + k * 0.05 + tt * 0.08, 0.5))
		circle(q.x, q.y, 5, PINK)
	var h := a.lerp(b, 0.45 + 0.05 * sin(tt * 1.5)) + Vector2(0, 26)
	circle(h.x, h.y, 11, GOLD)   # 내 영웅
	box([h.x - 16, h.y + 16, h.x + 16, h.y + 20], Color8(40, 20, 20))
	box([h.x - 16, h.y + 16, h.x - 16 + 32 * (0.6 + 0.3 * sin(tt)), h.y + 20], GREEN)
	if fmod(tt, 1.4) < 0.4:   # 스킬
		var rr := fmod(tt, 1.4) / 0.4
		m.draw_arc(Vector2(h.x, H - h.y), 10 + rr * 40, 0, TAU, 24, Color(0.4, 0.9, 1.0, 1.0 - rr), 3)


## 오픈월드: 하늘 · 산(먼 것 천천히) · 나무가 스쳐 감 · 길 원근 · 캐릭터 뒷모습. 그래픽 메모리가 모자라면 나무가 회색 덩어리로 늦게 뜸
func game_open(s: Array, tt: float, pop: bool) -> void:
	var sw: float = s[2] - s[0]
	var sh: float = s[3] - s[1]
	box([s[0], s[1] + sh * 0.4, s[2], s[3]], Color8(90, 120, 200))   # 하늘
	box([s[0], s[1] + sh * 0.7, s[2], s[3]], Color8(70, 100, 190))
	circle(s[2] - sw * 0.2, s[3] - sh * 0.2, 18, Color8(255, 230, 160))
	for k in 5:   # 먼 산
		var mx: float = s[0] + fposmod(k * sw * 0.3 - tt * sw * 0.02, sw * 1.5) - sw * 0.2
		poly([Vector2(mx, s[1] + sh * 0.4), Vector2(mx + sw * 0.35, s[1] + sh * 0.4), Vector2(mx + sw * 0.17, s[1] + sh * 0.68)], Color8(70, 80, 130))
	box([s[0], s[1], s[2], s[1] + sh * 0.4], Color8(60, 120, 70))   # 들판
	var c := Vector2(s[0] + sw / 2.0, s[1] + sh * 0.4)
	poly([Vector2(c.x - sw * 0.03, c.y), Vector2(c.x + sw * 0.03, c.y), Vector2(c.x + sw * 0.3, s[1]), Vector2(c.x - sw * 0.3, s[1])], Color8(140, 120, 90))   # 길
	for k in 6:   # 나무: 멀리서 다가와 옆으로 스침
		var d := fposmod(k / 6.0 + tt * 0.35, 1.0)
		var side := -1.0 if k % 2 else 1.0
		var x: float = c.x + side * lerpf(sw * 0.06, sw * 0.6, d * d)
		var y: float = lerpf(c.y, s[1] - sh * 0.1, d * d)
		var sz: float = lerpf(4.0, sh * 0.25, d * d)
		if pop and d < 0.45:   # 텍스처가 늦게 뜸
			box([x - sz * 0.4, y, x + sz * 0.4, y + sz], Color8(120, 120, 130))
		else:
			box([x - sz * 0.08, y, x + sz * 0.08, y + sz * 0.4], Color8(100, 70, 40))
			circle(x, y + sz * 0.7, sz * 0.4, Color8(40, 110, 60))
	var bob := absf(sin(tt * 6.0)) * 4.0   # 캐릭터 뒷모습
	box([c.x - 14, s[1] + sh * 0.08 + bob, c.x + 14, s[1] + sh * 0.26 + bob], Color8(60, 50, 110))
	circle(c.x, s[1] + sh * 0.3 + bob, 11, Color8(240, 200, 170))
