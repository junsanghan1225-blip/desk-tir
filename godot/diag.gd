extends Mode
## 진단: 맡긴 PC를 여러 각도에서 살펴보고 원인을 찾아 그 자리에서 고친다.
## 정면(전원 눌러 관찰) · 뒷면(파워 스위치 · 모니터 선) · 속 확대(RAM 걸쇠 · 팬 선 · 전원선 · 먼지) · BIOS · 윈도우(작업 관리자)

const VIEWS := ["정면", "뒷면", "속 확대", "BIOS", "윈도우"]
const BTN_BACK := [12, 648, 172, 714]
const TILES := [[20, 330, 630, 626], [650, 330, 1260, 626], [20, 20, 630, 316], [650, 20, 950, 316], [970, 20, 1260, 316]]
const POWER_BTN := Vector2(565, 560)
const PSU_SWITCH := [552, 92, 608, 148]
const MB_HDMI := [240, 442, 300, 462]
const GPU_DP := [420, 290, 456, 304]
const KILL_BTN := [960, 60, 1240, 120]

var view := 0
var on_t := -1      # 정면에서 전원 누른 시각 (-1 = 꺼짐)
var toast := ""
var pick := -1      # 작업 관리자에서 고른 줄

# ---- 인두(납땜) 작업: 부푼 콘덴서 교체 ----
const SOLDER_JOINTS := [Vector2(590, 230), Vector2(690, 230)]
const BTN_IRON := [160, 10, 420, 58]
const BTN_NEWCAP := [440, 10, 720, 58]
const BTN_SCLOSE := [1020, 10, 1240, 58]
var solder := false
var iron_on := false
var temp := 25.0
var stage := 0            # 0 = 헌 콘덴서 녹여 빼기 · 1 = 새 것 꽂기 · 2 = 새 것 납땜
var melt := [0.0, 0.0]
var burn := [0.0, 0.0]
var burnt := [false, false]
var holding := -1
var last_ms := 0
var smoke := []           # [x, y, 생긴 시각, 짙은지]


func enter() -> void:
	toast = ""
	on_t = -1
	pick = -1
	solder = false


func view_rect(i: int) -> Array:
	var x := 184 + i * 188
	return [x, 648, x + 180, 714]


func t() -> float:
	return (Time.get_ticks_msec() - on_t) / 1000.0 if on_t >= 0 else -1.0


func faults() -> Dictionary:
	return Game.pc.faults


func fixed(f: String, msg: String) -> void:
	faults().erase(f)
	toast = msg
	sfx("place")


func up(_x: float, _y: float) -> void:
	holding = -1


func down(x: float, y: float, _right: bool) -> void:
	if solder:
		solder_down(x, y)
		return
	if inside(x, y, BTN_BACK):
		m.pop()
		return
	for i in VIEWS.size():
		if inside(x, y, view_rect(i)):
			view = i
			toast = ""
			return
	toast = ""
	match view:
		0:
			if Vector2(x, y).distance_to(POWER_BTN) < 50:
				on_t = Time.get_ticks_msec() if on_t < 0 else -1
				sfx("click")
		1:
			if inside(x, y, PSU_SWITCH):
				if faults().has("psu_switch"):
					fixed("psu_switch", "파워 스위치를 I(켜짐)로 올렸어요")
				else:
					toast = "스위치는 이미 켜져 있어요"
			elif inside(x, y, grow(MB_HDMI, 10)) and faults().has("monitor_mb"):
				fixed("monitor_mb", "모니터 선을 그래픽카드 단자로 옮겨 꽂았어요")
			elif inside(x, y, grow(GPU_DP, 10)):
				toast = "모니터 선이 잘 꽂혀 있어요" if not faults().has("monitor_mb") else "여긴 비어 있어요"
		2:
			var acts := [["ram_seat", "딸깍! RAM을 끝까지 눌러 꽂았어요", "RAM은 잘 꽂혀 있어요"],
				["cpu_fan", "CPU_FAN 단자에 팬 선을 꽂았어요", "팬 선은 잘 꽂혀 있어요"],
				["gpu_power", "전원선을 딸깍 소리 나게 끝까지 밀었어요", "전원선은 잘 꽂혀 있어요"],
				["dust", "에어 스프레이로 먼지를 날렸어요", "먼지는 별로 없어요"]]
			if inside(x, y, TILES[4]):   # 메인보드 콘덴서 → 인두 작업
				if faults().has("cap_bulge"):
					open_solder()
				else:
					toast = "콘덴서는 멀쩡해요"
				return
			for i in 4:
				if inside(x, y, TILES[i]):
					if faults().has(acts[i][0]):
						fixed(acts[i][0], acts[i][1])
					else:
						toast = acts[i][2]
		3:
			if not screen_ok():
				return
			if inside(x, y, [700, 334, 1000, 382]):
				if faults().has("xmp_off"):
					fixed("xmp_off", "XMP를 켰어요. RAM이 제 속도로 돌아요")
				else:
					toast = "XMP는 이미 켜져 있어요"
			elif inside(x, y, [700, 226, 1000, 274]) and faults().has("boot_order"):
				fixed("boot_order", "M.2 SSD를 1순위로 바꿨어요")
		4:
			if not windows_ok():
				return
			var rows := procs()
			for i in rows.size():
				if inside(x, y, [60, 470 - i * 56, 900, 522 - i * 56]):
					pick = i
			if inside(x, y, KILL_BTN) and pick >= 0:
				if rows[pick][2]:
					fixed("bloat", "'%s'를 끝내고 지웠어요" % rows[pick][0])
					pick = -1
				else:
					toast = "필요한 프로그램이에요"


# ---------- 상태 ----------
func screen_ok() -> bool:   # 화면이 나와서 BIOS를 볼 수 있는지
	var p: Array = Game.pc.post()
	return p[0] >= 3 and not faults().has("monitor_mb")


func windows_ok() -> bool:
	return Game.pc.picture() and not faults().has("cpu_fan")


## 쉬고 있을 때 CPU 온도 (BIOS · 작업 관리자)
func idle_temp() -> int:
	var pc := Game.pc
	if not pc.has("CPU") or not pc.has("COOLER"):
		return 0
	var v: float = 30 + 18.0 * pc.spec("CPU")["watt"] / pc.spec("COOLER")["tdp"]
	v += (22 if faults().has("paste_dry") else 0) + (6 if faults().has("dust") else 0) + (8 if faults().has("bloat") else 0)
	if faults().has("cpu_fan"):
		v = 70 + minf(30, maxf(0, t()) * 4)
	return roundi(v)


func procs() -> Array:   # [이름, CPU %, 수상함]
	var out := [["시스템", 1, false], ["바탕화면 관리자", 2, false], ["카톡", 1, false]]
	if faults().has("bloat"):
		out.insert(1, ["svc_update_helper", 64, true])
	return out


# ---------- 그리기 ----------
func fan(c: Vector2, r: float, spin: float, dusty: bool) -> void:
	circle(c.x, c.y, r, Color8(30, 26, 44))
	var a := spin
	for k in 5:
		var e := Vector2(c.x + cos(a + k * TAU / 5) * r * 0.9, c.y + sin(a + k * TAU / 5) * r * 0.9)
		line(c, e, Color8(120, 110, 160), r * 0.28)
	circle(c.x, c.y, r * 0.25, Color8(60, 54, 90))
	if dusty:
		for k in 9:
			circle(c.x + cos(k * 2.1) * r * 0.6, c.y + sin(k * 1.7) * r * 0.6, r * 0.12, Color(0.6, 0.58, 0.55, 0.8))


func draw_monitor(r: Array, label := "") -> void:
	frame("ui_slot", grow(r, 8))
	var tt := t()
	var pc := Game.pc
	box(r, Color8(6, 5, 12))
	if tt < 0:
		return
	var p: Array = pc.post()
	if p[0] < 0:
		return
	if p[0] < 3 or faults().has("monitor_mb"):
		text_c(r, "신호 없음", 22, QUIET)
		return
	if p[0] == 3:
		text_c(r, "부팅 장치 없음", 22, Color.WHITE)
		return
	if faults().has("cpu_fan") and tt > 9:   # 과열로 꺼짐
		return
	if tt < 1.5:
		text_c(r, "BIOS 로고", 22, CYAN)
	elif faults().has("cpu_fan") and tt < 4:
		box(r, Color8(10, 20, 80))
		text_c(r, "CPU Fan Error!", 22, Color.WHITE)
	else:
		draw_app(r, Bench.run(Bench.parts_of(pc), Game.request().get("use", {"kind": "office"})), tt, false)


## 진짜 본체처럼: 옆 유리 너머로 실제 조립한 부품이 보이고, 전원을 넣으면 팬이 돌고 LED · 소리 · 화면이 반응
const CASE_R := [60, 40, 600, 616]


func fan_blades(c: Vector2, r: float, spin: float, a: float) -> void:   # 도는 팬 날개 (조립 그림 위에 겹침)
	for k in 7:
		var e := Vector2(c.x + cos(spin + k * TAU / 7) * r, c.y + sin(spin + k * TAU / 7) * r)
		line(c, e, Color(0.75, 0.72, 0.9, a), r * 0.22)
	circle(c.x, c.y, r * 0.22, Color(0.15, 0.13, 0.25, a + 0.2))


func dust_on(c: Vector2, r: float) -> void:
	for k in 11:
		circle(c.x + cos(k * 2.3) * r * 0.7, c.y + sin(k * 1.9) * r * 0.7, r * (0.1 + 0.05 * (k % 3)), Color(0.62, 0.6, 0.56, 0.85))


func draw_front() -> void:
	var pc := Game.pc
	var tt := t()
	var p: Array = pc.post()
	var running: bool = tt >= 0 and p[0] >= 0 and not (faults().has("cpu_fan") and tt > 9)
	var r := CASE_R
	var body: Color = m.modes["desk"].CASE_BODY.get(DB.look(pc.parts.get("CASE", "")), Color8(42, 35, 80))
	box([r[0] + 20, r[1] - 10, r[0] + 70, r[1]], Color8(10, 6, 24))   # 받침발
	box([r[2] - 70, r[1] - 10, r[2] - 20, r[1]], Color8(10, 6, 24))
	box(r, body.darkened(0.15))
	box([r[0], r[3] - 8, r[2], r[3]], body.lightened(0.15))
	var g := [r[0] + 16, r[1] + 16, r[2] - 70, r[3] - 16]   # 옆 유리
	box(g, Color8(8, 5, 18))
	var b = m.modes["build"]
	var ca: Array = b.CASE_AREA
	var k: float = minf(float(g[2] - g[0]) / (ca[2] - ca[0]), float(g[3] - g[1]) / (ca[3] - ca[1]))
	var ox: float = g[0] + ((g[2] - g[0]) - (ca[2] - ca[0]) * k) / 2.0
	var oy: float = (H - g[3]) + ((g[3] - g[1]) - (ca[3] - ca[1]) * k) / 2.0
	m.draw_set_transform(Vector2(ox - ca[0] * k, oy - (H - ca[3]) * k), 0.0, Vector2(k, k))   # 조립 화면 그대로 → 유리 안
	var spin := tt * (16.0 if faults().has("dust") or faults().has("bloat") else 9.0) if running else 0.0
	var dusty: bool = faults().has("dust")
	for fy in [420, 540]:   # 뒷면 케이스 팬
		put("inb_casefan", [810, fy - 40, 890, fy + 40])
		if running:
			fan_blades(Vector2(850, fy), 34, spin, 0.55)
		if dusty:
			dust_on(Vector2(850, fy), 34)
	if pc.has("MB"):
		b.draw_board()
		b.draw_parts()
		b.draw_cables()
		if pc.has("COOLER"):
			var cc: Vector2 = b.center(b.cooler_rect())
			if running and not faults().has("cpu_fan"):
				fan_blades(cc, 52, spin * 1.2, 0.5)
			if dusty:
				dust_on(cc, 52)
		if pc.has("GPU"):
			var gr: Array = b.gpu_rect()
			for q in [0.3, 0.7]:
				var gc := Vector2(gr[0] + (gr[2] - gr[0]) * q, (gr[1] + gr[3]) / 2.0)
				if running and not faults().has("gpu_power"):
					fan_blades(gc, 24, spin, 0.5)
				if dusty:
					dust_on(gc, 24)
		var mb: Array = b.mb_rect()   # 보드 위 디버그 LED 4개
		for i in 4:
			var lit: bool = running and p[0] < 4 and i == maxi(p[0], 0)
			var lr := [mb[2] - 120 + i * 28, mb[1] + 150, mb[2] - 100 + i * 28, mb[1] + 164]
			box(lr, Color8(255, 60, 90) if lit else Color8(60, 20, 30))
			if lit:
				circle(center(lr).x, center(lr).y, 18, Color(1, 0.2, 0.35, 0.35 + 0.25 * sin(tt * 8)))
	m.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if running:   # 켜지면 RGB가 은은하게 돎
		box(g, Color.from_hsv(fmod(tt * 0.08, 1.0), 0.7, 1.0, 0.1))
	line(Vector2(g[0] + 10, g[3] - 60), Vector2(g[0] + 70, g[3] - 6), Color(1, 1, 1, 0.1), 5)   # 유리 반사
	outline(g, Color8(90, 80, 140), 2)
	var fp := [r[2] - 54, r[1] + 16, r[2] - 16, r[3] - 16]   # 앞면 패널 + 전원 버튼
	box(fp, body.darkened(0.35))
	for i in 18:
		box([fp[0] + 8, fp[1] + 20 + i * 26, fp[2] - 8, fp[1] + 26 + i * 26], body.darkened(0.5))
	circle(POWER_BTN.x, POWER_BTN.y, 17, Color8(10, 6, 24))
	circle(POWER_BTN.x, POWER_BTN.y, 13, CYAN if running else (GOLD if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1 else Color8(90, 78, 130)))
	circle(POWER_BTN.x, POWER_BTN.y, 6, Color8(10, 6, 24))
	box([POWER_BTN.x - 2, POWER_BTN.y + 1, POWER_BTN.x + 2, POWER_BTN.y + 9], Color8(10, 6, 24))
	box([POWER_BTN.x - 4, POWER_BTN.y - 34, POWER_BTN.x + 4, POWER_BTN.y - 28], CYAN if running and fmod(tt * 7, 2.0) < 1 else Color8(40, 30, 60))   # HDD LED
	if tt < 0:   # 눌러 보라는 말풍선
		var bx := [POWER_BTN.x - 300, POWER_BTN.y - 26, POWER_BTN.x - 40, POWER_BTN.y + 26]
		frame("ui_button", bx, GOLD)
		text_c(bx, "전원 버튼 → 눌러요", 22, Color8(30, 20, 10))
	# 오른쪽: 모니터 + 관찰 기록
	var scr := [660, 330, 1240, 600]
	box([650, 320, 1250, 610], Color8(14, 10, 26))
	outline([650, 320, 1250, 610], Color8(70, 60, 110), 2)
	box([930, 300, 960, 320], Color8(30, 24, 50))
	box([870, 290, 1020, 300], Color8(30, 24, 50))
	draw_monitor(scr)
	frame("ui_panel", [650, 20, 1250, 276])
	text(674, 248, "관찰 기록", 22, PINK)
	var fan_s: String = "-" if tt < 0 else ("안 돎" if not running else ("CPU 쿨러만 멈춰 있어요" if faults().has("cpu_fan") else ("엄청 빨리 돎" if faults().has("dust") or faults().has("bloat") else "잘 돎")))
	var led_s: String = "-" if tt < 0 else ("꺼짐" if not running else (PCBuild.POST_STAGES[maxi(p[0], 0)] + " 불이 켜져 있어요" if p[0] < 4 else "다 꺼짐 (정상)"))
	var snd := "-"
	if tt >= 0:
		snd = "조용함" if not running else ("삐— 삐 삐 (반복)" if p[0] == 1 else ("위이이잉… 시끄러움" if faults().has("dust") or faults().has("bloat") else ("삐 한 번 (정상)" if p[0] >= 3 else "없음")))
	var scr_s: String = "-" if tt < 0 else ("꺼짐" if not running else ("신호 없음" if p[0] < 3 or faults().has("monitor_mb") else ("부팅 장치 없음" if p[0] == 3 else ("CPU Fan Error → 잠시 뒤 꺼짐" if faults().has("cpu_fan") else "정상"))))
	var rows := [["팬", fan_s], ["LED", led_s], ["소리", snd], ["화면", scr_s]]
	for i in 4:
		text(674, 198 - i * 44, rows[i][0], 22, QUIET)
		text(760, 198 - i * 44, rows[i][1], 22, INK if rows[i][1] in ["-", "잘 돎", "다 꺼짐 (정상)", "삐 한 번 (정상)", "정상"] else GOLD)


## 진짜 본체 뒷면: 메인보드 단자 · 뒷면 팬 · 확장 슬롯(그래픽카드 단자) · 파워(전원선 · 스위치)
const BACK := [180, 50, 740, 610]   # diag_back.png(560x560)을 놓는 자리
func draw_back() -> void:
	var pc := Game.pc
	put("diag_back", BACK)
	if pc.has("GPU"):
		put("diag_gpu_bracket", [390, 274, 700, 320])
	# 전원선: 오른쪽에서 들어와 파워 소켓에
	polyline([Vector2(503, 100), Vector2(503, 28), Vector2(1270, 28)], Color8(20, 18, 28), 14)   # 아래로 빠져 콘센트로
	box([476, 98, 530, 142], Color8(30, 28, 40))
	# 스위치 (I = 켜짐 위 / O = 꺼짐 아래)
	var off: bool = faults().has("psu_switch")
	box(PSU_SWITCH, Color8(20, 18, 28))
	var mid: float = (PSU_SWITCH[1] + PSU_SWITCH[3]) / 2.0
	box([PSU_SWITCH[0] + 8, (PSU_SWITCH[1] + 6) if off else mid, PSU_SWITCH[2] - 8, mid if off else (PSU_SWITCH[3] - 6)], Color8(220, 60, 70))
	box([PSU_SWITCH[0] + 8, mid if off else (PSU_SWITCH[1] + 6), PSU_SWITCH[2] - 8, (PSU_SWITCH[3] - 6) if off else mid], Color8(120, 30, 40))
	text(PSU_SWITCH[2] + 10, PSU_SWITCH[3] - 14, "I", 22, INK)
	text(PSU_SWITCH[2] + 10, PSU_SWITCH[1] + 14, "O", 22, INK)
	# 모니터 선: 그래픽카드가 있으면 그래픽카드 단자가 정답, 없으면(내장 그래픽) 보드 단자
	var on_mb: bool = faults().has("monitor_mb") or not pc.has("GPU")
	var plug: Array = MB_HDMI if on_mb else GPU_DP
	var e := center(plug)
	polyline([Vector2(plug[2] + 20, e.y), Vector2(760, e.y), Vector2(800, 400), Vector2(1270, 400)], Color8(30, 30, 40), 10)
	box([plug[0] - 2, plug[1] - 4, plug[2] + 24, plug[3] + 4], Color8(60, 60, 72))   # 커넥터 머리
	box([plug[2] + 4, plug[1], plug[2] + 24, plug[3]], Color8(90, 90, 104))
	# 설명은 옆에 짧게
	frame("ui_panel", [790, 440, 1260, 610])
	text(810, 584, "뒷면", 22, PINK)
	text(810, 548, "모니터 선 · 파워 스위치", 22, INK)
	text(810, 514, "눌러서 고쳐요", 22, QUIET)
	text(810, 470, "파워 %dW" % pc.capacity() if pc.has("PSU") else "파워 없음", 22, GOLD)
	if not pc.has("GPU"):
		text(810, 410, "그래픽카드 없음:", 22, QUIET)
		text(810, 376, "보드 단자가 정답", 22, QUIET)


func draw_close() -> void:
	var pc := Game.pc
	var names := ["RAM 슬롯", "CPU 팬 커넥터", "그래픽카드 전원선", "방열판 · 팬", "보드 콘덴서"]
	for i in 5:
		var r: Array = TILES[i]
		frame("ui_slot", r)
		text(r[0] + 16, r[3] - 26, names[i], 22, CYAN)
	# RAM: 반쯤 빠지면 한쪽이 들뜨고 걸쇠가 열림
	var sticks := pc.ram.filter(func(s): return s != "")
	for k in sticks.size():
		var x: float = 120 + k * 120
		var lift: float = 26.0 if k == 0 and faults().has("ram_seat") else 0.0
		box([x - 6, 360, x + 66, 380], Color8(20, 18, 28))   # 슬롯
		box([x, 372 + lift, x + 60, 560 + lift], Color8(40, 120, 80))
		for j in 6:
			box([x + 6 + j * 9, 374 + lift, x + 11 + j * 9, 384 + lift], GOLD)
		var open := lift > 0
		box([x - 14, 360, x - 6, 410] if not open else [x - 30, 380, x - 6, 392], Color8(220, 220, 230))
	# CPU_FAN 단자
	box([840, 420, 940, 460], Color8(20, 18, 28))
	text(950, 440, "CPU_FAN", 22, DIM)
	var unplugged := faults().has("cpu_fan")
	var plug := [850, 420, 930, 460] if not unplugged else [1000, 360, 1080, 400]
	polyline([Vector2(890, 560), Vector2(890, 500), Vector2(center(plug).x, center(plug).y + 30), center(plug)], Color8(40, 40, 50), 6)
	box(plug, Color8(240, 240, 240))
	# 그래픽카드 8핀: 덜 꽂히면 틈이 보임
	box([120, 80, 520, 160], Color8(60, 56, 80))
	var gap := 22.0 if faults().has("gpu_power") else 0.0
	box([260, 160, 380, 190], Color8(20, 18, 28))
	box([262, 160 + gap, 378, 220 + gap], Color8(30, 30, 36))
	if gap > 0:
		for j in 4:
			box([270 + j * 28, 162, 284 + j * 28, 178], GOLD)
	polyline([Vector2(320, 220 + gap), Vector2(320, 290)], Color8(230, 190, 80), 8)
	# 방열판: 먼지
	for j in 8:
		box([672 + j * 34, 60, 694 + j * 34, 240], Color8(160, 160, 176))
	if faults().has("dust"):
		for j in 20:
			circle(680 + fmod(j * 97.0, 250.0), 70 + fmod(j * 53.0, 170.0), 12 + j % 3 * 3, Color(0.55, 0.52, 0.5, 0.9))
	# 보드 콘덴서: 부풀면 윗면이 볼록 + 갈색 자국
	box([990, 40, 1240, 250], Color8(30, 80, 60))
	for j in 3:
		var cx := 1040.0 + j * 75
		var bulge: bool = j == 1 and faults().has("cap_bulge")
		box([cx - 20, 80, cx + 20, 190], Color8(40, 40, 60))
		box([cx - 20, 180, cx + 20, 190], Color8(190, 190, 200))
		box([cx - 6, 80, cx + 6, 190], Color8(70, 70, 100))
		if bulge:
			circle(cx, 194, 20, Color8(190, 190, 200))
			circle(cx + 6, 186, 8, Color8(120, 70, 30))
		else:
			box([cx - 14, 184, cx + 14, 188], Color8(120, 120, 130))
	text(TILES[3][0] + 16, TILES[3][1] + 22, "눌러서 에어 스프레이", 22, DIM)


# ---------- 인두 작업 ----------
func open_solder() -> void:
	solder = true
	iron_on = false
	temp = 25.0
	stage = 0
	melt = [0.0, 0.0]
	burn = [0.0, 0.0]
	burnt = [false, false]
	holding = -1
	smoke = []
	last_ms = Time.get_ticks_msec()
	toast = "인두를 켜고 300°C가 넘으면 납땜 자리를 꾹 눌러 녹여요"


func solder_down(x: float, y: float) -> void:
	if inside(x, y, BTN_SCLOSE):
		solder = false
		return
	if inside(x, y, BTN_IRON):
		iron_on = not iron_on
		sfx("click")
		return
	if inside(x, y, BTN_NEWCAP) and stage == 1:
		stage = 2
		melt = [0.0, 0.0]
		sfx("place")
		toast = "새 콘덴서를 꽂았어요. 다리 두 곳을 납땜해요"
		return
	for i in 2:
		if Vector2(x, y).distance_to(SOLDER_JOINTS[i]) < 40 and stage != 1:
			holding = i
			if temp < 300:
				toast = "납이 안 녹아요 — 인두 온도가 낮아요"
			else:
				sfx("paste")


func solder_tick(dt: float) -> void:
	temp = minf(370.0, temp + 170.0 * dt) if iron_on else maxf(25.0, temp - 70.0 * dt)
	if holding < 0 or stage == 1:
		return
	var now := Time.get_ticks_msec()
	if temp < 300:
		return
	melt[holding] += dt
	var j: Vector2 = SOLDER_JOINTS[holding]
	if randf() < 0.5:
		smoke.append([j.x + randf_range(-10, 10), j.y + 10, now, burn[holding] > 0.2])
	if melt[holding] > 1.6:   # 너무 오래 꾹: 기판이 탐
		burn[holding] += dt
		if burn[holding] > 1.0 and not burnt[holding]:
			burnt[holding] = true
			Game.money -= 5
			toast = "앗, 너무 오래 대서 기판이 탔어요! (가게 돈 -5만)"
			sfx("error")
	if melt[0] >= 1.0 and melt[1] >= 1.0:
		if stage == 0:
			stage = 1
			holding = -1
			toast = "다리를 다 녹였어요 → 부푼 콘덴서를 뽑았어요. '새 콘덴서 꽂기'를 눌러요"
			sfx("place")
		elif stage == 2:
			holding = -1
			solder = false
			fixed("cap_bulge", "새 콘덴서를 납땜했어요!" + (" (조금 탔지만)" if burnt[0] or burnt[1] else ""))


func draw_solder() -> void:
	var now := Time.get_ticks_msec()
	solder_tick(minf(0.1, (now - last_ms) / 1000.0))
	last_ms = now
	box([0, 0, 1280, 640], Color8(10, 8, 20))
	box([140, 70, 1140, 600], Color8(28, 90, 64))   # 기판
	for i in 9:
		line(Vector2(160, 110 + i * 52), Vector2(1120, 110 + i * 52), Color8(40, 120, 84), 3)   # 회로 줄
	for i in 2:   # 납땜 자리: 녹을수록 반짝, 너무 오래면 거뭇
		var j: Vector2 = SOLDER_JOINTS[i]
		if burn[i] > 0 or burnt[i]:
			circle(j.x, j.y, 30 + minf(burn[i], 1.5) * 14, Color(0.15, 0.08, 0.02, minf(0.9, 0.3 + burn[i] * 0.5)))
		circle(j.x, j.y, 20, Color8(200, 200, 210))
		var mt: float = clampf(melt[i], 0.0, 1.0)
		circle(j.x, j.y, 12 + mt * 6, Color8(150, 150, 160).lerp(Color8(240, 240, 250), mt))
		if mt >= 1.0:
			circle(j.x - 4, j.y + 4, 4, Color.WHITE)
	if stage != 1:   # 콘덴서 몸통 (위로 서 있음)
		var newcap: bool = stage == 2
		box([560, 250, 720, 470], Color8(40, 40, 70) if newcap else Color8(36, 34, 52))
		box([560, 250, 720, 470], Color8(40, 40, 70))
		box([600, 250, 620, 470], Color8(80, 80, 120))
		box([560, 460, 720, 474], Color8(200, 200, 210))
		if not newcap:   # 부풀고 새어 나온 갈색 자국
			circle(640, 478, 70, Color8(200, 200, 210))
			circle(660, 468, 24, Color8(130, 80, 30))
		line(Vector2(590, 250), Vector2(590, 230), Color8(200, 200, 210), 5)
		line(Vector2(690, 250), Vector2(690, 230), Color8(200, 200, 210), 5)
	for p in smoke.duplicate():   # 연기: 위로 올라가며 흐려짐 (짙으면 탐)
		var age: float = (now - p[2]) / 1000.0
		if age > 1.6:
			smoke.erase(p)
			continue
		var c := Color(0.25, 0.22, 0.2, 0.7 - age * 0.4) if p[3] else Color(0.9, 0.9, 0.95, 0.45 - age * 0.28)
		circle(p[0] + sin(age * 4 + p[1]) * 10, p[1] + age * 140, 8 + age * 14, c)
	if holding >= 0:   # 인두 끝이 납땜 자리에
		var tip: Vector2 = SOLDER_JOINTS[holding]
		line(tip, tip + Vector2(120, 260), Color8(170, 170, 180), 8)
		line(tip + Vector2(120, 260), tip + Vector2(170, 380), Color8(40, 40, 50), 22)
		circle(tip.x, tip.y, 6, Color(1, 0.5, 0.2, 0.8) if temp >= 300 else Color8(120, 120, 130))
	# 온도계 + 버튼
	box([1170, 90, 1210, 560], Color8(30, 22, 60))
	box([1176, 96 + 470 * 300.0 / 450, 1204, 96 + 470 * 380.0 / 450], Color(GREEN, 0.25))   # 알맞은 온도
	box([1176, 96, 1204, 96 + 458 * clampf(temp / 450.0, 0, 1)], PINK if temp >= 380 else (GREEN if temp >= 300 else CYAN))
	text(1150, 590, "%d°C" % temp, 33, GREEN if temp >= 300 else INK)
	button(BTN_IRON, "인두 끄기" if iron_on else "인두 켜기", PINK if iron_on else VIOLET)
	button(BTN_NEWCAP, "새 콘덴서 꽂기", CYAN if stage == 1 else DIM)
	button(BTN_SCLOSE, "닫기", VIOLET)
	text(160, 620, ["① 헌 콘덴서 다리 두 곳을 녹여요", "② 새 콘덴서를 꽂아요", "③ 새 콘덴서 다리 두 곳을 납땜해요"][stage], 33, GOLD)


func draw_bios() -> void:
	if not screen_ok():
		box([20, 20, 1260, 626], Color8(6, 5, 12))
		text_c([20, 20, 1260, 626], "화면이 안 나와서 BIOS를 볼 수 없어요", 33, QUIET)
		return
	var pc := Game.pc
	box([20, 20, 1260, 626], Color8(16, 30, 110))
	text(60, 590, "BIOS 설정", 33, Color.WHITE)
	var gb := 0
	for s in pc.ram:
		gb += DB.PARTS[s].get("gb", 0) if s != "" else 0
	var tmp := idle_temp()
	var rows := [["CPU 온도 (쉬는 중)", "%d°C" % tmp, PINK if tmp >= 60 else Color.WHITE],
		["CPU 팬 속도", "0 RPM  ⚠" if faults().has("cpu_fan") else "%d RPM" % (2400 if faults().has("dust") else 1100), PINK if faults().has("cpu_fan") else Color.WHITE],
		["메모리", "%dGB · %s" % [gb, "2133MHz" if faults().has("xmp_off") else "3200MHz"], Color.WHITE],
		["XMP (RAM 제 속도)", "끔" if faults().has("xmp_off") else "켬", GOLD if faults().has("xmp_off") else GREEN],
		["", "", Color.WHITE],
		["부팅 1순위", "USB 장치" if faults().has("boot_order") else "M.2 SSD", GOLD if faults().has("boot_order") else Color.WHITE]]
	for i in rows.size():
		text(80, 520 - i * 54, rows[i][0], 22, Color8(200, 210, 255))
		text(720, 520 - i * 54, rows[i][1], 22, rows[i][2])
	outline([700, 334, 1000, 382], Color8(200, 210, 255))
	outline([700, 226, 1000, 274], Color8(200, 210, 255))
	text(60, 60, "값을 눌러 바꿔요", 22, Color8(200, 210, 255))


func draw_windows() -> void:
	if not windows_ok():
		box([20, 20, 1260, 626], Color8(6, 5, 12))
		text_c([20, 20, 1260, 626], "윈도우까지 켜지지 않아요", 33, QUIET)
		return
	box([20, 20, 1260, 626], Color8(24, 24, 32))
	text(60, 590, "작업 관리자", 33, Color.WHITE)
	var rows := procs()
	var total := 0
	for row in rows:
		total += row[1]
	text(700, 590, "CPU %d%%  ·  %d°C" % [total, idle_temp() + total / 5], 22, PINK if total > 50 else INK)
	text(60, 540, "이름", 22, QUIET)
	text(700, 540, "CPU", 22, QUIET)
	for i in rows.size():
		var r := [60, 470 - i * 56, 900, 522 - i * 56]
		if i == pick:
			box(r, Color8(50, 60, 110))
		text(76, r[1] + 26, rows[i][0], 22, INK)
		text(700, r[1] + 26, "%d%%" % rows[i][1], 22, PINK if rows[i][1] > 30 else INK)
	button(KILL_BTN, "작업 끝내기", PINK if pick >= 0 else DIM)


func draw() -> void:
	grid()
	if solder:
		draw_solder()
		if toast != "":
			box([300, 64, 1100, 110], Color(0, 0, 0, 0.7))
			text_c([300, 64, 1100, 110], toast, 22, GREEN)
		return
	match view:
		0: draw_front()
		1: draw_back()
		2: draw_close()
		3: draw_bios()
		4: draw_windows()
	frame("ui_panel", [-12, BAR, 1292, H + 12])
	button(BTN_BACK, "◀ 조립", VIOLET)
	for i in VIEWS.size():
		frame("ui_button", view_rect(i), CYAN if i == view else Color8(80, 66, 140))
		text_c(view_rect(i), VIEWS[i], 22, Color.WHITE if i == view else QUIET)
	if toast != "":
		box([300, 0, 980, 50], Color(0, 0, 0, 0.7))
		text_c([300, 0, 980, 50], toast, 22, GREEN)
