extends Mode
## 진단: 맡긴 PC를 여러 각도에서 살펴보고 원인을 찾아 그 자리에서 고친다.
## 정면(전원 눌러 관찰) · 뒷면(파워 스위치 · 모니터 선) · 속 확대(RAM 걸쇠 · 팬 선 · 전원선 · 먼지) · BIOS · 윈도우(작업 관리자)

const VIEWS := ["정면", "뒷면", "속 확대", "BIOS", "윈도우"]
const BTN_BACK := [12, 648, 172, 714]
const TILES := [[20, 330, 630, 626], [650, 330, 1260, 626], [20, 20, 630, 316], [650, 20, 1260, 316]]
const POWER_BTN := Vector2(330, 520)
const PSU_SWITCH := [770, 92, 840, 160]
const MB_HDMI := [360, 470, 440, 510]
const GPU_DP := [560, 290, 640, 326]
const KILL_BTN := [960, 60, 1240, 120]

var view := 0
var on_t := -1      # 정면에서 전원 누른 시각 (-1 = 꺼짐)
var toast := ""
var pick := -1      # 작업 관리자에서 고른 줄


func enter() -> void:
	toast = ""
	on_t = -1
	pick = -1


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


func down(x: float, y: float, _right: bool) -> void:
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


func draw_front() -> void:
	var pc := Game.pc
	var tt := t()
	var p: Array = pc.post()
	var running: bool = tt >= 0 and p[0] >= 0 and not (faults().has("cpu_fan") and tt > 9)
	box([140, 60, 560, 610], Color8(28, 22, 46))   # 케이스 앞면
	for i in 14:
		line(Vector2(170, 100 + i * 32), Vector2(530, 100 + i * 32), Color8(44, 36, 70), 3)
	circle(POWER_BTN.x, POWER_BTN.y, 34, Color8(50, 44, 80))
	circle(POWER_BTN.x, POWER_BTN.y, 26, CYAN if running else Color8(80, 70, 110))
	text_c([150, 440, 510, 470], "전원 버튼" if tt < 0 else "다시 눌러 끄기", 22, QUIET)
	box([590, 60, 1000, 610], Color8(16, 12, 30))   # 옆 유리 너머 속
	outline([590, 60, 1000, 610], Color8(120, 110, 180), 2)
	var spin := tt * (14.0 if faults().has("dust") or faults().has("bloat") else 8.0) if running else 0.0
	fan(Vector2(720, 430), 70, 0.0 if faults().has("cpu_fan") else spin, faults().has("dust"))
	text(650, 520, "CPU 쿨러", 22, QUIET)
	fan(Vector2(920, 460), 50, spin, faults().has("dust"))
	if pc.has("GPU"):
		box([620, 220, 980, 300], Color8(40, 36, 60))
		fan(Vector2(720, 260), 32, spin if not faults().has("gpu_power") else 0.0, faults().has("dust"))
		fan(Vector2(880, 260), 32, spin if not faults().has("gpu_power") else 0.0, faults().has("dust"))
	for i in 4:   # 디버그 LED
		var lit: bool = running and p[0] < 4 and i == maxi(p[0], 0)
		box([620 + i * 90, 110, 690 + i * 90, 150], PINK if lit else Color8(40, 32, 70))
		text_c([620 + i * 90, 110, 690 + i * 90, 150], PCBuild.POST_STAGES[i], 22, Color.WHITE if lit else DIM)
	var sound := ""
	if running:
		if p[0] == 1:
			sound = "삐— 삐 삐" if fmod(tt, 2.0) < 1.2 else ""
		elif p[0] >= 3 and tt < 0.4:
			sound = "삐"
		elif faults().has("dust") or faults().has("bloat"):
			sound = "위이이잉…"
	if sound != "":
		text(1010, 560, "♪ " + sound, 33, GOLD)
	draw_monitor([1020, 300, 1260, 460])
	text(1020, 270, "모니터", 22, QUIET)
	if tt < 0:
		text(600, 30, "전원을 눌러 팬 · LED · 소리 · 화면을 관찰해요", 22, INK)


func draw_back() -> void:
	var pc := Game.pc
	box([300, 60, 900, 620], Color8(28, 22, 46))
	box([340, 430, 520, 600], Color8(50, 46, 66))   # 메인보드 뒷단자
	text(350, 580, "메인보드 단자", 22, QUIET)
	for i in 4:
		box([360 + (i % 2) * 70, 520 - (i / 2) * 20, 410 + (i % 2) * 70, 532 - (i / 2) * 20], Color8(30, 60, 140))
	box(MB_HDMI, Color8(20, 18, 28))
	text(448, 490, "HDMI", 22, DIM)
	fan(Vector2(720, 510), 70, 0.0, false)
	for i in 4:   # 확장 슬롯 덮개
		box([540, 220 + i * 40, 880, 248 + i * 40], Color8(60, 56, 80))
	if pc.has("GPU"):
		box([540, 280, 880, 336], Color8(80, 76, 100))
		text(560, 356, "그래픽카드 단자", 22, QUIET)
		box(GPU_DP, Color8(20, 18, 28))
	var plug: Array = MB_HDMI if faults().has("monitor_mb") else GPU_DP
	var pc_end := center(plug)
	polyline([pc_end, Vector2(1000, pc_end.y), Vector2(1000, 400), Vector2(1180, 400)], Color8(200, 200, 210), 6)
	box(grow(plug, -6), Color8(200, 200, 210))
	text(1060, 430, "모니터로", 22, QUIET)
	box([340, 80, 860, 190], Color8(40, 36, 52))   # 파워
	text(360, 170, "파워 %dW" % pc.capacity() if pc.has("PSU") else "파워 없음", 22, INK)
	box([660, 100, 740, 150], Color8(20, 18, 28))   # 전원선
	text(560, 126, "전원선", 22, DIM)
	var off: bool = faults().has("psu_switch")
	box(PSU_SWITCH, Color8(20, 18, 28))
	box([PSU_SWITCH[0] + 8, (PSU_SWITCH[1] if off else (PSU_SWITCH[1] + PSU_SWITCH[3]) / 2.0) + 4, PSU_SWITCH[2] - 8, (PSU_SWITCH[3] if not off else (PSU_SWITCH[1] + PSU_SWITCH[3]) / 2.0) - 4], Color8(200, 60, 60))
	text(PSU_SWITCH[2] + 12, PSU_SWITCH[3] - 14, "I", 22, INK)
	text(PSU_SWITCH[2] + 12, PSU_SWITCH[1] + 14, "O", 22, INK)
	text(40, 30, "단자 · 스위치를 눌러 고쳐요", 22, QUIET)


func draw_close() -> void:
	var pc := Game.pc
	var names := ["RAM 슬롯", "CPU 팬 커넥터", "그래픽카드 전원선", "방열판 · 팬"]
	for i in 4:
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
	for j in 10:
		box([700 + j * 50, 60, 730 + j * 50, 240], Color8(160, 160, 176))
	if faults().has("dust"):
		for j in 26:
			circle(710 + fmod(j * 97.0, 500.0), 70 + fmod(j * 53.0, 170.0), 14 + j % 3 * 4, Color(0.55, 0.52, 0.5, 0.9))
	text(TILES[3][0] + 16, TILES[3][1] + 22, "눌러서 에어 스프레이", 22, DIM)


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
