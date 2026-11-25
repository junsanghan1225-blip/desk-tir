extends Mode
## PC 조립 (케이스 옆판을 연 시점): 재고에서 부품을 끌어 제자리에 꽂고, 전원선을 끌어 소켓에 꽂는다.
## 끄는 동안 갈 자리가 하늘색(가능) / 분홍(불가 + 이유). 두 번 누르기(우클릭) = 빼기.

const ORDER := ["CASE", "MB", "CPU", "COOLER", "RAM", "SSD", "GPU", "PSU"]
const TYPE_NAMES := {"CASE": "케이스", "MB": "메인보드", "CPU": "CPU", "COOLER": "쿨러", "RAM": "RAM", "SSD": "M.2 SSD", "GPU": "그래픽카드", "PSU": "파워"}
const CABLE_NAMES := {"24pin": "메인 24핀", "cpu8": "CPU 8핀", "pcie0": "GPU 8핀 #1", "pcie1": "GPU 8핀 #2", "front": "전원 버튼선"}
const PSU_CABLES := ["24pin", "cpu8", "pcie0", "pcie1"]
const FRONT_SRC := [820, 84, 890, 112]   # 케이스 앞면 버튼에서 나오는 선
const INV_W := 270
const ROW_H := 34
const ROW_TOP := 600
const CASE_AREA := [290, 70, 900, 636]
const PSU_BAY := [306, 84, 520, 196]
const BTN_POST := [930, 70, 1096, 116]
const BTN_DIAG := [1104, 70, 1270, 116]
const BTN_BENCH := [930, 6, 1270, 62]
const PER := 14
const BTN_PREV := [14, 70, 64, 100]
const BTN_NEXT := [206, 70, 256, 100]
const PASTE_ROW := [10, 570, 260, 600]   # 서멀 구리스: 항상 있는 도구
const MARGIN := {"CASE": 0, "MB": 0, "CPU": 20, "COOLER": 10, "SSD": 16, "GPU": 16, "PSU": 16}

var held: Array = []   # ["part", id] | ["cable", 이름] | ["paste"]
var toast := ""
var post: Array = []   # 마지막 전원 테스트 [단계, 메시지]
var page := 0


func enter() -> void:
	Game.power = false   # 조립을 만지면 전원은 꺼진 상태로
	held = []
	toast = ""
	post = []


# ---------- 좌표 ----------
func mb_rect() -> Array:
	var mb = Game.pc.spec("MB")
	if mb and mb["size"] == "mATX":
		return [330, 300, 700, 600]
	return [330, 236, 790, 600]


func cpu_rect() -> Array:
	var b := mb_rect()
	return [b[0] + 60, b[3] - 150, b[0] + 160, b[3] - 50]


func cooler_rect() -> Array:
	return grow(cpu_rect(), 18)


func ram_rect(i: int) -> Array:
	var b := mb_rect()
	return [b[0] + 214 + i * 26, b[3] - 196, b[0] + 228 + i * 26, b[3] - 24]


func gpu_rect() -> Array:
	var length := 280
	if Game.pc.has("GPU"):
		length = Game.pc.spec("GPU")["length"]
	elif held.size() == 2 and held[0] == "part" and DB.PARTS[held[1]]["type"] == "GPU":
		length = DB.PARTS[held[1]]["length"]
	var b := mb_rect()
	return [b[0] + 10, b[1] + 4, b[0] + 10 + int(length * 1.25), b[1] + 64]


func ssd_rect() -> Array:
	var b := mb_rect()
	return [b[0] + 60, b[1] + 88, b[0] + 190, b[1] + 104]


func lever_rect() -> Array:
	var c := cpu_rect()
	return [c[0] - 30, c[1], c[0] - 14, c[3]]


func socket_rect(c: String) -> Array:
	var b := mb_rect()
	match c:
		"front": return [b[2] - 60, b[1] + 110, b[2] - 12, b[1] + 130]
		"24pin": return [b[2] - 30, b[3] - 150, b[2] - 10, b[3] - 40]
		"cpu8": return [b[0] + 16, b[3] - 30, b[0] + 90, b[3] - 10]
	var g := gpu_rect()
	var i := int(c.right(1))
	return [g[2] - 70 + i * 34, g[3] - 4, g[2] - 42 + i * 34, g[3] + 14]


func psu_port(c: String) -> Array:
	if c == "front":
		return FRONT_SRC
	var i := PSU_CABLES.find(c)
	return [PSU_BAY[2] + 14, PSU_BAY[3] - 24 - i * 26, PSU_BAY[2] + 96, PSU_BAY[3] - 6 - i * 26]


func zone(t: String) -> Array:
	match t:
		"CASE": return CASE_AREA
		"MB": return mb_rect()
		"CPU": return cpu_rect()
		"COOLER": return cooler_rect()
		"SSD": return ssd_rect()
		"GPU": return gpu_rect()
	return PSU_BAY


## 놓은 위치가 그 부품의 자리 위면 RAM 슬롯 번호(RAM이 아니면 -1), 아니면 -2
func target_for(pid: String, x: float, y: float) -> int:
	var t: String = DB.PARTS[pid]["type"]
	if t == "RAM":
		for i in 4:
			if inside(x, y, grow(ram_rect(i), 10)):
				return i
		return -2
	return -1 if inside(x, y, grow(zone(t), MARGIN[t])) else -2


# ---------- 재고 ----------
func inv_all() -> Array:
	var out := []
	for t in ORDER:
		out += DB.PARTS.keys().filter(func(p): return DB.PARTS[p]["type"] == t and Game.stock.get(p, 0) > 0)
	return out


func inv_ids() -> Array:
	return inv_all().slice(page * PER, (page + 1) * PER)


func inv_row(i: int) -> Array:
	var y := ROW_TOP - (i + 1) * ROW_H
	return [10, y - ROW_H + 4, INV_W - 10, y]


# ---------- 입력 ----------
## 누른 곳에 끼워진 부품 [자리, RAM 슬롯] (위에 올라간 것 먼저)
func placed_at(x: float, y: float) -> Array:
	var pc := Game.pc
	for i in 4:
		if pc.ram[i] != "" and inside(x, y, ram_rect(i)):
			return ["RAM", i]
	for slot in ["COOLER", "CPU", "SSD", "GPU", "PSU", "MB", "CASE"]:
		if pc.has(slot) and inside(x, y, zone(slot)):
			return [slot, -1]
	return []


func down(x: float, y: float, right: bool) -> void:
	var pc := Game.pc
	if tabs(x, y):
		return
	if inside(x, y, BTN_BENCH):
		sfx("click")
		m.modes["bench"].open()
		return
	if inside(x, y, BTN_DIAG):
		sfx("click")
		m.push("diag")
		return
	if inside(x, y, BTN_POST):
		post = pc.post()
		sfx("boot_ok" if post[0] == 4 else "boot_fail")
		if post[0] == 4:
			m.modes["boot"].open()
		return
	if inside(x, y, BTN_PREV) or inside(x, y, BTN_NEXT):
		var last: int = max(0, (inv_all().size() - 1) / PER)
		page = max(0, page - 1) if inside(x, y, BTN_PREV) else min(last, page + 1)
		return
	if pc.has("MB") and inside(x, y, grow(lever_rect(), 12)):
		toast = pc.toggle_lever()
		sfx("lever" if toast == "" else "error")
		if toast == "":
			toast = "레버를 열었어요" if pc.lever_open else "레버를 닫았어요"
		post = []
		return
	if inside(x, y, PASTE_ROW):
		held = ["paste"]
		toast = ""
		return
	for c in CABLE_NAMES:   # 파워 전원선 + 케이스 전원 버튼선
		if pc.has("CASE" if c == "front" else "PSU") and inside(x, y, psu_port(c)):
			if right:
				pc.cables.erase(c)
			elif c in pc.cable_targets():
				held = ["cable", c]
				toast = ""
			else:
				toast = "지금은 이 선을 꽂을 데가 없어요"
			post = []
			return
	var ids := inv_ids()
	for i in ids.size():
		if inside(x, y, inv_row(i)):
			held = ["part", ids[i]]
			toast = ""
			return
	var hit := placed_at(x, y)
	if right and not hit.is_empty():   # 빼기는 두 번 누르기만 (실수로 조립이 풀리지 않게)
		var pid: String = pc.ram[hit[1]] if hit[0] == "RAM" else pc.parts[hit[0]]
		for id in pc.remove(hit[0], hit[1]):
			Game.give_back(id)
		post = []
		toast = "%s을(를) 뺐어요%s" % [DB.PARTS[pid]["name"], " (위에 꽂힌 부품도 재고로)" if hit[0] in ["CASE", "MB", "CPU"] else ""]


func up(x: float, y: float) -> void:
	if held.is_empty():
		return
	var pc := Game.pc
	var h := held
	held = []
	post = []
	if h[0] == "paste":
		if inside(x, y, grow(cpu_rect(), 16)):
			toast = pc.apply_paste()
			sfx("paste" if toast == "" else "error")
			if toast == "":
				toast = "서멀 구리스를 발랐어요"
		return
	if h[0] == "cable":
		if inside(x, y, grow(socket_rect(h[1]), 16)):
			toast = pc.plug(h[1])
			sfx("plug" if toast == "" else "error")
		return
	var pid: String = h[1]
	var slot := target_for(pid, x, y)
	if slot == -2:
		if inside(x, y, CASE_AREA):
			toast = "%s 자리가 아니에요" % TYPE_NAMES[DB.PARTS[pid]["type"]]
		return
	toast = pc.check(pid, slot)
	if toast != "":
		sfx("error")
		return
	if DB.PARTS[pid]["price"] > Game.money_left():
		toast = "손님 예산을 넘어요!"
	elif not Game.take(pid):
		toast = "재고가 없어요"
	else:
		pc.place(pid, slot)
		sfx("place")


# ---------- 그리기 ----------
func draw_case() -> void:
	var pc := Game.pc
	if not pc.has("CASE"):
		outline(CASE_AREA, DIM)
		text(CASE_AREA[0] + 150, 353, "케이스를 여기에 끌어다 놓으세요", 20, DIM)
		return
	var case: Dictionary = pc.spec("CASE")
	frame("ui_slot", grow(CASE_AREA, 6))
	var mb = pc.spec("MB")
	text(CASE_AREA[0] + 12, CASE_AREA[3] - 16, case["name"] + ("  ·  %s (%s)" % [mb["name"], mb["size"]] if mb else ""), 13, QUIET)
	for fy in [420, 540]:   # 뒷면 케이스 팬
		put("inb_casefan", [810, fy - 40, 890, fy + 40])
	var gx: float = gpu_rect()[0] + int(case["gpu_max"] * 1.25)   # 그래픽카드 길이 한계선
	if gx < CASE_AREA[2]:
		line(Vector2(gx, mb_rect()[1] - 6), Vector2(gx, mb_rect()[1] + 74), PINK, 1)


func draw_board() -> void:
	var pc := Game.pc
	var b := mb_rect()
	if not pc.has("MB"):
		outline(b, DIM)
		text(b[0] + 110, (b[1] + b[3]) / 2.0, "메인보드 자리", 18, DIM)
		return
	put("inb_" + pc.parts["MB"], b)
	var l := lever_rect()   # 소켓 레버: 열리면 위로 선다
	if pc.lever_open:
		box([l[0] + 5, l[3], l[2] - 5, l[3] + 56], Color8(216, 216, 224))
		box([l[0] + 2, l[3] + 50, l[2] - 2, l[3] + 58], Color8(216, 216, 224))
	else:
		box([l[0] + 5, l[1] + 4, l[2] - 5, l[3] - 4], Color8(176, 176, 188))
		box([l[0] + 2, l[1], l[2] - 2, l[1] + 8], Color8(176, 176, 188))


func draw_parts() -> void:
	var pc := Game.pc
	if pc.has("CPU"):
		put("inb_cpu", cpu_rect())
		if pc.paste and not pc.has("COOLER"):
			put("inb_paste", cpu_rect())
	if pc.has("SSD"):
		put("inb_ssd", ssd_rect())
	if pc.has("COOLER"):
		put("inb_" + pc.parts["COOLER"], cooler_rect())
	for i in 4:
		if pc.ram[i] != "":
			put("inb_" + pc.ram[i], ram_rect(i))
	if pc.has("GPU"):
		put("inb_" + pc.parts["GPU"], gpu_rect())
		for i in pc.spec("GPU")["pcie"]:
			box(socket_rect("pcie%d" % i), Color8(20, 20, 28))
			outline(socket_rect("pcie%d" % i), Color8(90, 90, 100))
	if not pc.has("PSU"):
		outline(PSU_BAY, DIM)
		text(PSU_BAY[0] + 60, 140, "파워 자리", 16, DIM)
		return
	var psu: Dictionary = pc.spec("PSU")
	put("inb_psu_white" if pc.parts["PSU"] == "psu5" else "inb_psu", PSU_BAY)
	text(PSU_BAY[0] + 150, PSU_BAY[1] + 18, "%dW" % psu["capacity"], 13)
	for c in PSU_CABLES:
		if c.begins_with("pcie") and int(c.right(1)) >= psu["pcie"]:
			continue
		var r := psu_port(c)
		var on: bool = pc.cables.has(c)
		box(r, Color8(60, 50, 100) if on else DARK)
		outline(r, CYAN if c in pc.cable_targets() and not on else DIM)
		text(r[0] + 4, (r[1] + r[3]) / 2.0, CABLE_NAMES[c], 11, INK if on else QUIET)


func cable_color(c: String) -> Color:
	return Color8(230, 190, 80) if c.begins_with("pcie") else Color8(170, 160, 220) if c == "front" else Color8(220, 140, 60)


func cable_start(c: String) -> Vector2:
	var r := psu_port(c)
	return Vector2((r[0] + r[2]) / 2.0, r[3]) if c == "front" else Vector2(r[2], (r[1] + r[3]) / 2.0)


func draw_cables() -> void:
	var pc := Game.pc
	box(FRONT_SRC, Color8(60, 50, 100) if pc.cables.has("front") else DARK)   # 케이스 앞면 전원 버튼선 출발점
	outline(FRONT_SRC, CYAN if "front" in pc.cable_targets() else DIM)
	text(FRONT_SRC[0] + 4, 98, "버튼선", 11)
	for c in pc.cables:   # 파워 포트 → 오른쪽 통로 → 소켓 높이 → 소켓 (실제 선 정리처럼 꺾인 선)
		var r := socket_rect(c)
		var a := cable_start(c)
		var b := center(r)
		var lane: float = mb_rect()[2] + 22 + CABLE_NAMES.keys().find(c) * 9
		polyline([a, Vector2(lane, a.y), Vector2(lane, b.y), b], cable_color(c), 3)
		box(r, Color8(24, 20, 30))   # 커넥터
		outline(r, cable_color(c))
		box([r[0] + 2, r[1] + 2, r[0] + 6, r[3] - 2], cable_color(c))


## 손가락 · 마우스를 올린 자리의 이름
func draw_hover() -> void:
	var pc := Game.pc
	if not held.is_empty() or not pc.has("MB"):
		return
	var mb: Dictionary = pc.spec("MB")
	var spots := [[cpu_rect(), "CPU 소켓 %s" % mb["socket"] + (" · " + pc.spec("CPU")["name"] if pc.has("CPU") else "")],
		[lever_rect(), "소켓 레버 (눌러서 열고 닫기)"],
		[ssd_rect(), "M.2 슬롯" + (" · " + pc.spec("SSD")["name"] if pc.has("SSD") else "")],
		[gpu_rect(), "%s · %dmm" % [pc.spec("GPU")["name"], pc.spec("GPU")["length"]] if pc.has("GPU") else "PCIe x16 (그래픽카드)"],
		[socket_rect("24pin"), "메인 24핀 소켓"], [socket_rect("cpu8"), "CPU 8핀 소켓"], [socket_rect("front"), "케이스 전원 버튼 핀"]]
	for i in mb["ram_slots"]:
		spots.append([ram_rect(i), "RAM 슬롯 %d" % (i + 1) + (" · " + DB.PARTS[pc.ram[i]]["name"] if pc.ram[i] != "" else "")])
	for s in spots:
		if inside(m.mouse.x, m.mouse.y, grow(s[0], 4)):
			var w: float = m.font.get_string_size(s[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 16
			var r := [m.mouse.x + 14, m.mouse.y + 10, m.mouse.x + 14 + w, m.mouse.y + 34]
			box(r, Color(0.04, 0.02, 0.09, 0.86))
			outline(r, CYAN)
			text(r[0] + 8, m.mouse.y + 22, s[1], 13)
			return


func draw_drag() -> void:
	if held.is_empty():
		return
	var pc := Game.pc
	var x := m.mouse.x
	var y := m.mouse.y
	if held[0] == "paste":
		outline(grow(cpu_rect(), 6), CYAN if pc.has("CPU") and not pc.has("COOLER") else PINK, 2)
		circle(x, y, 14, Color8(200, 200, 210))
		text(x + 18, y, "서멀 구리스", 13)
		return
	if held[0] == "cable":
		outline(grow(socket_rect(held[1]), 6), CYAN, 2)
		line(cable_start(held[1]), m.mouse, GOLD, 4)
		return
	var t: String = DB.PARTS[held[1]]["type"]   # 갈 수 있는 자리 미리 보기
	var zones := []
	if t == "RAM":
		for i in pc.ram_slots():
			if pc.ram[i] == "":
				zones.append([i, ram_rect(i)])
	else:
		zones.append([-1, zone(t)])
	for z in zones:
		var reason := pc.check(held[1], z[0])
		outline(grow(z[1], 4), CYAN if reason == "" else PINK, 2)
		if reason != "" and inside(x, y, grow(z[1], 20)):
			text(x + 20, y - 30, reason, 14, PINK)
	fit(icon_of(held[1]), x, y, 56, 56)


func draw_side() -> void:
	var pc := Game.pc
	var x0 := 930
	panel([912, 130, 1276, 638])
	text(x0, 610, "조립 순서", 18, PINK)
	var steps := [["케이스", pc.has("CASE")], ["메인보드", pc.has("MB")], ["CPU (레버 닫기)", pc.has("CPU") and not pc.lever_open],
		["서멀 구리스", pc.paste], ["쿨러", pc.has("COOLER")], ["RAM", pc.ram.any(func(r): return r != "")], ["M.2 SSD", pc.has("SSD")],
		["그래픽카드", pc.has("GPU")], ["파워", pc.has("PSU")],
		["전원선", pc.has("PSU") and pc.cable_targets().all(func(c): return c == "front" or pc.cables.has(c))], ["전원 버튼선", pc.cables.has("front")]]
	for i in steps.size():
		text(x0, 584 - i * 21, ("●  " if steps[i][1] else "○  ") + steps[i][0], 15, GREEN if steps[i][1] else QUIET)
	var b := Bench.run(Bench.parts_of(pc), Game.request().get("use", {}))
	text(x0, 344, "예상 " + Bench.short(b), 22, GREEN if b["ok"] else GOLD)
	text(x0, 316, "전력 %dW / %sW" % [pc.watt(), pc.capacity() if pc.capacity() else "?"], 16, PINK if pc.capacity() and pc.watt() > pc.capacity() else INK)
	var extra := []
	if pc.dual_channel():
		extra.append("듀얼 채널 +1")
	if pc.throttled():
		extra.append("쿨러 부족 -3")
	text(x0, 288, "  ·  ".join(extra), 14, GOLD)
	text(x0, 238, "디버그 LED", 15, QUIET)
	var stage: int = post[0] if not post.is_empty() else -9
	for i in 4:
		var c := Color8(40, 32, 70)
		if stage == 4:
			c = GREEN
		elif stage != -9 and i < stage:
			c = Color8(60, 120, 90)
		elif stage != -9 and i == max(stage, 0):
			c = PINK
		frame("ui_button", [x0 + i * 84, 176, x0 + i * 84 + 74, 220], c)
		text(x0 + i * 84 + 10, 199, PCBuild.POST_STAGES[i], 16, Color.WHITE)
	if not post.is_empty():
		text(x0, 154, post[1].left(22), 15, GREEN if stage == 4 else PINK)
		text(x0, 132, post[1].substr(22), 15, GREEN if stage == 4 else PINK)
	button(BTN_POST, "전원", GOLD)
	button(BTN_DIAG, "진단", PINK if Game.request().has("repair") else VIOLET)
	button(BTN_BENCH, "성능 테스트", CYAN)


func draw_inventory() -> void:
	panel([-12, -12, INV_W, 650])
	text(14, ROW_TOP + 22, "부품 재고  (끌어서 장착)", 18)
	frame("ui_slot", PASTE_ROW)
	circle(26, 585, 9, Color8(200, 200, 210))
	text(46, 585, "서멀 구리스 (CPU 위로)", 16)
	var ids := inv_ids()
	if ids.is_empty():
		text(14, ROW_TOP - 56, "부품 재고가 없어요", 15, QUIET)
		text(14, ROW_TOP - 78, "쇼핑 탭에서 사 오세요", 13, DIM)
	var total := inv_all().size()
	if total > PER:
		button(BTN_PREV, "▲", VIOLET)
		button(BTN_NEXT, "▼", VIOLET)
		text(92, 85, "%d/%d" % [page + 1, (total - 1) / PER + 1], 13, QUIET)
	for i in ids.size():
		var r := inv_row(i)
		var p: Dictionary = DB.PARTS[ids[i]]
		var cy: float = (r[1] + r[3]) / 2.0
		fit(icon_of(ids[i]), r[0] + 16, cy, 28, 26)
		text(r[0] + 36, cy, p["name"], 16)
		text(r[2] - 34, cy, "x%d" % Game.stock[ids[i]], 16, CYAN)


func draw() -> void:
	grid()
	draw_case()
	if Game.pc.has("CASE"):
		draw_board()
		draw_parts()
		draw_cables()
	draw_inventory()
	draw_side()
	draw_drag()
	draw_hover()
	top_bar("build")
	text(INV_W + 20, 30, "끌어다 꽂기 · 두 번 누르면 빼기", 13, QUIET)
	if toast != "":
		text(INV_W + 20, 54, toast, 16, PINK)
