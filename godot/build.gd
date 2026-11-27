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
const BTN_SHOW := [690, 6, 900, 60]   # 완성 모습 (옆판 유리 너머로 본 PC)
const BTN_BENCH := [930, 6, 1270, 62]
const PER := 14
const BTN_PREV := [14, 70, 64, 100]
const BTN_NEXT := [206, 70, 256, 100]
const PASTE_ROW := [10, 570, 260, 600]   # 서멀 구리스: 항상 있는 도구
const BTN_DRIVER := [10, 6, 260, 62]    # 도구: 드라이버(나사 조이기 · 풀기)
const MARGIN := {"CASE": 0, "MB": 0, "CPU": 20, "COOLER": 10, "SSD": 16, "GPU": 16, "PSU": 16}

var held: Array = []   # ["part", id] | ["cable", 이름] | ["out", …]
var toast := ""
var post: Array = []   # 마지막 전원 테스트 [단계, 메시지]
var page := 0
var tool := ""         # "" = 손(끌어 꽂기) · "driver"
var seat := {}         # 덜 꽂힌 것: "RAM0"~"RAM3" · "GPU" · "SSD" · 선 이름 → 눌러서 끝까지 (딸깍)
var press := {}        # 키 → 누른 시각 (쑥 들어가고 딸깍 연출)
const SEAT_MS := 240.0
const SEAT_SFX := {"GPU": "latch", "SSD": "snap", "24pin": "push"}   # RAM은 걸쇠 두 번(latch), 나머지 선은 snap
var spin := {}         # 나사 키 -> 돌리기 시작한 시각 (돌아가는 연출)
var showcase := false  # 완성 모습 보는 중
var hold_t := 0        # 누르기 시작한 시각 · 자리 (폰: 길게 누르면 부품 이름)
var hold_at := Vector2.ZERO


func enter() -> void:
	Game.power = false   # 조립을 만지면 전원은 꺼진 상태로
	held = []
	toast = ""
	post = []
	tool = ""
	showcase = false


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
	elif held.size() == 2 and held[0] == "part" and DB.PARTS[pid_of(held[1])]["type"] == "GPU":
		length = DB.PARTS[pid_of(held[1])]["length"]
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


## 나사 위치 [자리, 번호, Vector2]
func screw_points() -> Array:
	var out := []
	for slot in Game.pc.screws:
		var r: Array = zone(slot)
		var pts: Array
		match slot:
			"MB", "COOLER", "PSU":
				var k := 14.0 if slot != "COOLER" else 8.0
				pts = [Vector2(r[0] + k, r[3] - k), Vector2(r[2] - k, r[3] - k), Vector2(r[0] + k, r[1] + k), Vector2(r[2] - k, r[1] + k)]
				if slot == "MB":   # 아래쪽 나사는 그래픽카드에 안 가리게 위로
					pts[2] = Vector2(r[0] + k, r[1] + 90)
					pts[3] = Vector2(r[2] - k, r[1] + 90)
				if slot == "PSU":
					pts = [pts[0], pts[2]]
			"GPU": pts = [Vector2(r[0] - 16, (r[1] + r[3]) / 2.0)]   # 브래킷 나사
			"SSD": pts = [Vector2(r[2] + 8, (r[1] + r[3]) / 2.0)]
		for i in pts.size():
			out.append([slot, i, pts[i]])
	return out


## 조립이 마지막 단계라 여기서도 바로 납품 (수리 의뢰는 같은 자리에 '수리' 버튼)
func deliver_here() -> bool:
	return not Game.mine and Game.order_index < Game.todays_requests().size() and not Game.request().has("repair")


func use_tool(x: float, y: float) -> bool:
	var pc := Game.pc
	if tool == "driver":
		var near := screw_points().filter(func(q): return Vector2(x, y).distance_to(q[2]) < 24)
		near.sort_custom(func(a, b): return Vector2(x, y).distance_to(a[2]) < Vector2(x, y).distance_to(b[2]))
		for s in near.slice(0, 1):   # 가장 가까운 나사 하나
			if s[0] == "COOLER" and not pc.screws["COOLER"].all(func(v): return v):   # 쿨러는 확대 팝업에서 순서대로
				m.push("mount")
				return true
			var on: bool = pc.turn(s[0], s[1])
			spin["%s%d" % [s[0], s[1]]] = Time.get_ticks_msec()
			sfx("screw" if ResourceLoader.exists("res://resource/sfx/screw.wav") else "place")
			toast = ("%s 나사 조임 (%d/%d)" if on else "%s 나사 풀림 (%d/%d)") % [TYPE_NAMES[s[0]], pc.tight(s[0]), PCBuild.SCREWS[s[0]]]
			post = []
			return true
		toast = "나사(동그라미)를 눌러 조여요"
		return true
	return false


# ---------- 재고 ----------
func inv_all() -> Array:
	var out := []
	for t in ORDER:
		out += DB.PARTS.keys().filter(func(p): return DB.PARTS[p]["type"] == t and Game.stock.get(p, 0) > 0)
	for i in Game.used.size():   # 중고 창고 (손님이 두고 간 헌 부품 · 장터에서 산 것)
		out.append("u%d" % i)
	return out


## 재고 줄 키 → 부품 id ("u3" = 중고 3번)
func pid_of(key: String) -> String:
	return Game.used[int(key.substr(1))]["id"] if key.begins_with("u") else key


func used_label(e: Dictionary) -> String:
	if e["known"] and e.get("dead", false):
		return "고장"
	return "%d%%" % e["cond"] if e["known"] else "상태?"


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
	if showcase:   # 아무 데나 누르면 닫힘
		showcase = false
		return
	if tabs(x, y):
		return
	toast = ""   # 지난 안내는 다음 손길에 지움 (엉뚱한 때 남아 있지 않게)
	hold_t = Time.get_ticks_msec()
	hold_at = Vector2(x, y)
	if pc.has("CASE") and inside(x, y, BTN_SHOW):
		showcase = true
		sfx("boot_ok" if pc.boots() else "click")
		return
	prune_seat()
	if not seat.is_empty() and (inside(x, y, BTN_BENCH) or inside(x, y, BTN_POST) or ((Game.request().has("repair") or deliver_here()) and inside(x, y, BTN_DIAG))):
		toast = "덜 꽂힌 곳을 눌러 끝까지 (딸깍)"
		sfx("error")
		return
	for k in seat.keys():   # 손맛: 들뜬 부품 · 선을 눌러 끝까지 밀어 넣기
		if tool == "" and not right and inside(x, y, grow(seat_rect(k), 6)):
			seat.erase(k)
			press[k] = Time.get_ticks_msec()
			sfx(SEAT_SFX.get(k, "latch" if k.begins_with("RAM") else "snap"))
			toast = "딸깍! 끝까지 들어갔어요"
			post = []
			return
	if inside(x, y, BTN_BENCH):
		sfx("click")
		m.modes["bench"].open()
		return
	for tb in [[BTN_DRIVER, "driver"]]:
		if inside(x, y, tb[0]):
			tool = "" if tool == tb[1] else tb[1]
			toast = "드라이버: 나사를 눌러 조이기 · 다시 누르면 풀기" if tool == "driver" else ""
			sfx("click")
			return
	if tool != "" and inside(x, y, CASE_AREA) and use_tool(x, y):
		return
	if deliver_here() and inside(x, y, BTN_DIAG):
		m.done()
		return
	if Game.request().has("repair") and inside(x, y, BTN_DIAG):
		sfx("click")
		m.push("diag")
		return
	if inside(x, y, BTN_POST):
		post = pc.post()
		if post[0] < 4:   # 안 켜지면 고장 난 중고가 들통남
			for e in pc.used.values():
				if e.get("dead", false) and e["paid"] > 0:
					e["known"] = true
		sfx("boot_ok" if post[0] == 4 else "boot_fail")
		if post[0] == 4 and not pc.bios_done:   # 새 CPU 첫 부팅: BIOS 설정부터
			m.push("bios")
		elif post[0] == 4:
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
	if inside(x, y, PASTE_ROW):   # 확대 팝업에서 직접 짜기
		toast = pc.paste_check()
		if toast == "":
			m.push("paste")
		else:
			sfx("error")
		return
	for c in CABLE_NAMES:   # 파워 전원선 + 케이스 전원 버튼선
		if pc.has("CASE" if c == "front" else "PSU") and inside(x, y, psu_port(c)):
			if right:
				pc.cables.erase(c)
				seat.erase(c)
			elif c in pc.cable_targets():
				held = ["cable", c]
				toast = ""
			else:
				toast = why_no_cable(c)
			post = []
			return
	var ids := inv_ids()
	for i in ids.size():
		if inside(x, y, inv_row(i)):
			if right and ids[i].begins_with("u"):   # 중고 두 번 누르기 = 되팔기
				var nm: String = DB.PARTS[pid_of(ids[i])]["name"]
				toast = "중고 %s 되팔기 +%d만" % [nm, Game.sell_used(int(ids[i].substr(1)))]
				sfx("buy")
				return
			held = ["part", ids[i]]
			toast = ""
			return
	if tool == "" and inside(x, y, CASE_AREA):   # 손으로 나사를 눌러도 드라이버로 조여 줌
		for s in screw_points():
			if Vector2(x, y).distance_to(s[2]) < 18:
				tool = "driver"
				use_tool(x, y)
				tool = ""
				return
	var hit := placed_at(x, y)
	if hit.is_empty():
		return
	if right:   # 두 번 누르기(우클릭) = 바로 빼기
		take_out(hit)
	elif tool == "":   # 끌어서 재고 쪽에 놓으면 빼기 (실수로 조립이 풀리지 않게 놓는 곳이 정해짐)
		held = ["out", hit[0], hit[1]]


## 꽂힌 부품을 빼서 재고로 [자리, RAM 슬롯]
func take_out(hit: Array) -> void:
	var pc := Game.pc
	var kids := pc.blockers(hit[0])
	if not kids.is_empty():   # 위에 꽂힌 부품부터 (케이스 · 보드를 통째로 빼서 조립이 날아가지 않게)
		toast = "%s부터 빼 주세요" % ", ".join(kids.map(func(k): return TYPE_NAMES[k]))
		sfx("error")
		return
	if pc.tight(hit[0]) > 0:
		toast = "나사 %d개를 먼저 풀어요 (드라이버)" % pc.tight(hit[0])
		sfx("error")
		return
	var pid: String = pc.ram[hit[1]] if hit[0] == "RAM" else pc.parts[hit[0]]
	for id in pc.remove(hit[0], hit[1]):
		if id is Dictionary:   # 중고는 상태째로 중고 창고에
			Game.used.append(id)
		else:
			Game.give_back(id)
	post = []
	toast = "%s을(를) 뺐어요" % DB.PARTS[pid]["name"]
	sfx("pick")


## 선을 꽂을 수 없는 이유를 구체적으로
func why_no_cable(c: String) -> String:
	if not Game.pc.has("MB"):
		return "메인보드를 먼저 장착해요"
	if c == "cpu8":
		return "CPU를 먼저 꽂아요"
	if c.begins_with("pcie"):
		var i := int(c.right(1))
		if not Game.pc.has("GPU"):
			return "그래픽카드를 먼저 꽂아요"
		if Game.pc.pcie_needed() == 0:
			return "이 그래픽카드는 보조전원이 필요 없어요 (슬롯 전기로 충분)"
		if i >= Game.pc.pcie_needed():
			return "이 그래픽카드는 8핀 %d개만 써요" % Game.pc.pcie_needed()
		return "이 파워엔 그래픽카드 선이 %d개뿐이에요" % Game.pc.spec("PSU")["pcie"]
	return "지금은 이 선을 꽂을 데가 없어요"


func up(x: float, y: float) -> void:
	if held.is_empty():
		return
	var pc := Game.pc
	var h := held
	held = []
	post = []
	if h[0] == "out":
		if x < INV_W:
			take_out([h[1], h[2]])
		return
	if h[0] == "cable":
		if inside(x, y, grow(socket_rect(h[1]), 16)):
			toast = pc.plug(h[1])
			sfx("plug" if toast == "" else "error")
			if toast == "":
				seat[h[1]] = true
				toast = "반쯤 꽂혔어요 → 커넥터를 눌러 딸깍"
		return
	var key: String = h[1]
	var pid := pid_of(key)
	var slot := target_for(pid, x, y)
	if slot == -2:
		if inside(x, y, CASE_AREA):
			toast = "%s 자리가 아니에요" % TYPE_NAMES[DB.PARTS[pid]["type"]]
		return
	toast = pc.check(pid, slot)
	if toast != "":
		sfx("error")
		return
	if key.begins_with("u"):
		var e: Dictionary = Game.used[int(key.substr(1))]
		var over_u: bool = e["paid"] > Game.money_left()
		Game.used.remove_at(int(key.substr(1)))
		pc.place_used(e, slot)
		sfx("place")
		mark_seat(pid, slot)
		toast = Game.OVER if over_u else "중고 %s (%s) 장착" % [DB.PARTS[pid]["name"], used_label(e)]
	elif not Game.take(pid):
		toast = "재고가 없어요"
	else:
		var over: bool = DB.PARTS[pid]["price"] > Game.money_left()
		pc.place(pid, slot)
		sfx("place")
		mark_seat(pid, slot)
		if over:
			toast = Game.OVER


## 끼운 직후엔 반쯤 걸쳐 있음 → 눌러야 딸깍 (RAM · 그래픽카드 · M.2)
func mark_seat(pid: String, slot: int) -> void:
	var t: String = DB.PARTS[pid]["type"]
	if t == "CPU":   # 직접 꽂은 CPU는 칩 등급을 뽑음 (테스트해야 보임)
		Game.pc.roll_chip()
	if t == "RAM":
		seat["RAM%d" % slot] = true
	elif t in ["GPU", "SSD"]:
		seat[t] = true
	if seat.size() > 0 and toast == "":
		toast = "반쯤 걸쳤어요 → 눌러서 딸깍"


func prune_seat() -> void:   # 빼거나 손님이 바뀌면 지움
	var pc := Game.pc
	for k in seat.keys():
		var ok: bool = (pc.ram[int(k.right(1))] != "") if k.begins_with("RAM") else pc.has(k) if k in ["GPU", "SSD"] else pc.cables.has(k)
		if not ok:
			seat.erase(k)


func seat_rect(k: String) -> Array:
	if k.begins_with("RAM"):
		return ram_rect(int(k.right(1)))
	if k == "GPU":
		return gpu_rect()
	if k == "SSD":
		return ssd_rect()
	return grow(socket_rect(k), 10)


## 들뜬 높이(px): 덜 꽂혔으면 최대, 누르면 쑥 내려가고 살짝 튕김
func lift(k: String) -> float:
	var top := 9.0 if k in CABLE_NAMES else 12.0
	if seat.has(k):
		return top + 1.5 * sin(Time.get_ticks_msec() / 160.0)   # 살짝 들썩여서 '눌러 줘' 신호
	if press.has(k):
		var t: float = (Time.get_ticks_msec() - press[k]) / SEAT_MS
		if t < 1.0:
			return top * (1.0 - t) * (1.0 - t) - (2.0 * sin(t * PI) if t > 0.6 else 0.0)
	return 0.0


## 선이 빠져나오는 방향 (보드 오른쪽 소켓은 옆으로, 나머지는 위로)
func out_dir(c: String) -> Vector2:
	return Vector2(1, 0) if c in ["24pin", "front"] else Vector2(0, 1)


func shifted(r: Array, d: Vector2) -> Array:
	return [r[0] + d.x, r[1] + d.y, r[2] + d.x, r[3] + d.y]


## 덜 꽂힌 곳: 하늘색 테두리가 깜빡 + 아래 화살표
func draw_seat_hints() -> void:
	if seat.is_empty() or tool != "":
		return
	var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 200.0)
	for k in seat:
		var r := grow(seat_rect(k), 4)
		outline(r, Color(CYAN.r, CYAN.g, CYAN.b, a), 2)
		var c := center(r)
		poly([Vector2(c.x - 8, r[3] + 18), Vector2(c.x + 8, r[3] + 18), Vector2(c.x, r[3] + 6)], Color(1, 1, 1, a))


## 딸깍 순간: 반짝 선 4개 + '딸깍' 글자가 떠오름
func draw_clicks() -> void:
	var now := Time.get_ticks_msec()
	for k in press.keys():
		var t: float = (now - press[k]) / 1000.0
		if t > 0.7:
			press.erase(k)
			continue
		if t < SEAT_MS / 1000.0 * 0.6:
			continue
		var c := center(seat_rect(k))
		var a := clampf(1.0 - t / 0.7, 0.0, 1.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			line(c + d * (10 + t * 30), c + d * (18 + t * 40), Color(1, 1, 1, a), 2)
		text(c.x - 20, c.y + 24 + t * 40, "딸깍", 22, Color(1, 1, 0.7, a))


## 다음에 할 일 [안내, 반짝일 자리, 같이 반짝일 것: 부품 종류 · "paste" · "driver" · ""]
func next_step() -> Array:
	var pc := Game.pc
	var n: Array
	if not seat.is_empty():
		n = ["반짝이는 곳을 눌러 딸깍", seat_rect(seat.keys()[0]), ""]
	elif not pc.has("CASE"):
		n = ["케이스를 가운데로", CASE_AREA, "CASE"]
	elif not pc.has("MB"):
		n = ["메인보드를 케이스에", mb_rect(), "MB"]
	elif not pc.has("CPU"):
		n = ["CPU를 소켓에", cpu_rect(), "CPU"] if pc.lever_open else ["소켓 레버를 눌러 열기", lever_rect(), ""]
	elif pc.lever_open:
		n = ["소켓 레버를 눌러 닫기", lever_rect(), ""]
	elif not pc.paste and not pc.has("COOLER"):
		n = ["서멀 구리스를 눌러 CPU에 짜기", cpu_rect(), "paste"]
	elif not pc.has("COOLER"):
		n = ["쿨러를 CPU 위에", cooler_rect(), "COOLER"]
	elif pc.ram.all(func(r): return r == ""):
		n = ["RAM을 반짝이는 슬롯에", ram_rect(1 if pc.ram_slots() == 4 else 0), "RAM"]   # 4슬롯은 A2부터 (듀얼 채널)
	elif not pc.has("SSD"):
		n = ["M.2 SSD를 슬롯에", ssd_rect(), "SSD"]
	elif not pc.has("GPU") and not pc.igpu():
		n = ["그래픽카드를 긴 슬롯에", gpu_rect(), "GPU"]
	elif not pc.has("PSU"):
		n = ["파워를 왼쪽 아래 칸에", PSU_BAY, "PSU"]
	else:
		var left := pc.cable_targets().filter(func(c): return not pc.cables.has(c))
		if not left.is_empty():
			n = ["선 꽂기: " + CABLE_NAMES[left[0]], psu_port(left[0]), ""]
		elif not pc.loose().is_empty():
			n = ["나사 조이기: " + TYPE_NAMES[pc.loose()[0]], zone(pc.loose()[0]), "driver"]
		else:
			n = ["전원을 눌러 확인!", BTN_POST, ""]
	if n[2] in TYPE_NAMES and not inv_all().any(func(k): return DB.PARTS[pid_of(k)]["type"] == n[2]):
		n[0] = "%s 재고 없음 · 쇼핑에서" % TYPE_NAMES[n[2]]
	return n


## 다음 할 자리 · 집을 재고 줄을 금색으로 깜빡 (들고 있거나 딸깍 대기 중엔 안 보임)
func draw_guide() -> void:
	if not held.is_empty() or tool != "" or not seat.is_empty():
		return
	var n := next_step()
	var col := Color(GOLD, 0.45 + 0.45 * sin(Time.get_ticks_msec() / 260.0))
	outline(grow(n[1], 4), col, 3)
	if n[2] == "paste":
		outline(grow(PASTE_ROW, 2), col, 2)
	elif n[2] == "driver":
		outline(grow(BTN_DRIVER, 2), col, 3)
	elif n[2] != "":
		var ids := inv_ids()
		for i in ids.size():
			if DB.PARTS[pid_of(ids[i])]["type"] == n[2]:
				outline(grow(inv_row(i), 2), col, 2)


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
	put("inb_" + DB.look(pc.parts["MB"]), b)
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
		put("inb_ssd", shifted(ssd_rect(), Vector2(0, lift("SSD"))))
	if pc.has("COOLER"):
		put("inb_" + DB.look(pc.parts["COOLER"]), cooler_rect())
	for i in 4:
		if pc.ram[i] != "":
			var k := "RAM%d" % i
			var up := lift(k)
			put("inb_" + DB.look(pc.ram[i]), shifted(ram_rect(i), Vector2(0, up)))
			var rr := ram_rect(i)   # 양 끝 흰 걸쇠: 들떠 있으면 바깥으로 벌어짐, 끝까지 들어가면 딸깍 닫힘
			var open := up > 3.0
			for e in [[rr[1] - 2, -1.0], [rr[3] + 2, 1.0]]:
				var y0: float = e[0]
				box([rr[0] - (5 if open else 1), y0 - 4 + (e[1] * 4 if open else 0.0), rr[2] + (5 if open else 1), y0 + 4 + (e[1] * 4 if open else 0.0)], Color8(232, 230, 240) if not open else Color8(190, 188, 200))
	if pc.has("GPU"):
		put("inb_" + DB.look(pc.parts["GPU"]), shifted(gpu_rect(), Vector2(0, lift("GPU"))))
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
		text(r[0] + 4, (r[1] + r[3]) / 2.0, CABLE_NAMES[c], 11, INK if on else QUIET if c in pc.cable_targets() else Color(1, 1, 1, 0.25))   # 지금 필요 없는 선은 흐리게


func cable_color(c: String) -> Color:
	return Color8(230, 190, 80) if c.begins_with("pcie") else Color8(170, 160, 220) if c == "front" else Color8(220, 140, 60)


func cable_start(c: String) -> Vector2:
	var r := psu_port(c)
	return Vector2((r[0] + r[2]) / 2.0, r[3]) if c == "front" else Vector2(r[0] + text_w(CABLE_NAMES[c], 22) + 24, (r[1] + r[3]) / 2.0)   # 이름 글자 바로 오른쪽 플러그에서 출발


func draw_cables() -> void:
	var pc := Game.pc
	box(FRONT_SRC, Color8(60, 50, 100) if pc.cables.has("front") else DARK)   # 케이스 앞면 전원 버튼선 출발점
	outline(FRONT_SRC, CYAN if "front" in pc.cable_targets() else DIM)
	text(FRONT_SRC[0] + 4, 98, "버튼선", 11)
	if not pc.cables.is_empty():   # 보드 옆 고무 선정리 구멍 (선이 뒤로 돌아 나옴)
		var gx: float = mb_rect()[2] + 18
		box([gx, mb_rect()[1] + 20, gx + 44, mb_rect()[3] - 20], Color8(14, 12, 20))
		outline([gx, mb_rect()[1] + 20, gx + 44, mb_rect()[3] - 20], Color8(50, 46, 62), 2)
	for c in pc.cables:   # 파워 포트 → 오른쪽 통로 → 소켓 높이 → 소켓 (실제 선 정리처럼, 모서리는 둥글게)
		var r := socket_rect(c)
		var a := cable_start(c)
		var b := center(r)
		var lane: float = mb_rect()[2] + 24 + CABLE_NAMES.keys().find(c) * 9
		var d := out_dir(c) * lift(c)   # 반쯤 꽂혔으면 커넥터가 빠져나와 있음
		real_cable(c, [a, Vector2(lane, a.y), Vector2(lane, b.y + d.y), b + d])
		plug(shifted(r, d), c)
		if c != "front":
			var pr := psu_port(c)
			plug([a.x - 14, pr[1] + 3, a.x, pr[3] - 3], "psu")   # 모듈러 파워 쪽 플러그


## 실제 선처럼: 24핀은 굵은 검은 슬리브, 8핀은 노랑 · 검정 가닥, 버튼선은 가는 색선 다발. 모서리는 둥글게.
func real_cable(c: String, pts: Array) -> void:
	var path := round_path(pts, 14.0)
	match c:
		"24pin":
			polyline(path, Color8(90, 86, 104), 15)   # 어두운 배경에서도 보이게 테두리
			polyline(path, Color8(22, 20, 28), 12)
			polyline(path, Color8(52, 48, 62), 2)   # 슬리브 결
		"front":
			for k in 3:
				var off := Vector2(k * 3 - 3, k * 3 - 3)
				polyline(path.map(func(p): return p + off), [Color8(230, 230, 236), Color8(220, 70, 70), Color8(40, 40, 48)][k], 2)
		_:   # CPU 8핀 · GPU 8핀: 노랑(12V) + 검정(GND) 가닥
			polyline(path, Color8(90, 86, 104), 11)
			polyline(path, Color8(22, 20, 28), 8)
			polyline(path.map(func(p): return p + Vector2(-2, 2)), Color8(220, 180, 60), 2)
			polyline(path.map(func(p): return p + Vector2(2, -2)), Color8(60, 56, 70), 2)


## 꺾인 선의 모서리를 둥글게 (모서리마다 작은 곡선 점 추가)
func round_path(pts: Array, rad: float) -> Array:
	var out := [pts[0]]
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var a: Vector2 = p + (pts[i - 1] - p).limit_length(rad)
		var b: Vector2 = p + (pts[i + 1] - p).limit_length(rad)
		for t in 5:
			var u := t / 4.0
			out.append(a.lerp(p, u).lerp(p.lerp(b, u), u))
	out.append(pts[-1])
	return out


## 커넥터 머리: 검은 하우징 + 걸쇠 + 핀 구멍 줄
func plug(r: Array, c: String) -> void:
	var h := grow(r, 3)
	box(h, Color8(16, 14, 20))
	outline(h, Color8(70, 66, 84), 2)
	var tall: bool = (r[3] - r[1]) > (r[2] - r[0])
	var n: int = {"24pin": 12, "cpu8": 4, "front": 5}.get(c, 4)
	for k in n:
		var t: float = (k + 0.5) / n
		var pt := Vector2(lerpf(r[0], r[2], 0.5), lerpf(r[1], r[3], t)) if tall else Vector2(lerpf(r[0], r[2], t), lerpf(r[1], r[3], 0.5))
		box([pt.x - 2, pt.y - 2, pt.x + 2, pt.y + 2], Color8(40, 38, 50))
	if c != "front":   # 딸깍 걸쇠
		box([h[2] - 2, (h[1] + h[3]) / 2.0 - 5, h[2] + 3, (h[1] + h[3]) / 2.0 + 5] if tall else [(h[0] + h[2]) / 2.0 - 5, h[3] - 2, (h[0] + h[2]) / 2.0 + 5, h[3] + 3], Color8(70, 66, 84))


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
			hover_tip(m.mouse.x + 14, m.mouse.y + 26, s[1])
			return


const SCREW_ANIM := 450.0   # 나사 돌리는 시간(ms)


## 나사: 헐거우면 살짝 떠 있고, 누르면 드라이버가 내려와 빙글빙글 돌며 쏙 들어감 (풀 땐 반대로 올라옴)
func draw_screws() -> void:
	var pc := Game.pc
	var now := Time.get_ticks_msec()
	for s in screw_points():
		var p0: Vector2 = s[2]
		var on: bool = pc.screws[s[0]][s[1]]
		var started: int = spin.get("%s%d" % [s[0], s[1]], -100000)
		var k: float = clampf((now - started) / SCREW_ANIM, 0.0, 1.0)
		var ease: float = k * k * (3 - 2 * k)
		var up: float = (1.0 - ease) if on else ease   # 0 = 끝까지 박힘, 1 = 떠 있음
		circle(p0.x, p0.y, 10, Color8(20, 16, 30))   # 나사 구멍
		var p := p0 + Vector2(5, 5) * up
		var r: float = 8.0 + 2.0 * up                  # 떠 있으면 조금 커 보임 (가까움)
		circle(p.x + 1, p.y - 2, r, Color(0, 0, 0, 0.35 * up))   # 그림자
		circle(p.x, p.y, r, Color8(150, 150, 165).lerp(Color8(214, 214, 224), 1.0 - up))
		circle(p.x - r * 0.3, p.y + r * 0.3, r * 0.35, Color(1, 1, 1, 0.25))   # 반짝
		var turns: float = (2.5 * TAU) * (ease if on else -ease)
		var a: float = 0.6 + turns
		var d := Vector2(cos(a), sin(a)) * (r - 2)
		var e := Vector2(-d.y, d.x)
		line(p - d, p + d, Color8(60, 60, 70), 2.5)
		line(p - e, p + e, Color8(60, 60, 70), 2.5)
		if k < 1.0:   # 돌리는 동안 드라이버가 나사 위에
			var tip := p + Vector2(0, 2)
			line(tip, tip + Vector2(18, 30), Color8(200, 200, 212), 4)
			var hb := tip + Vector2(18, 30)
			for q in 3:   # 손잡이 홈이 돌아가 보이게
				var off: float = fmod(turns * 3.0 + q * 2.1, TAU)
				line(hb + Vector2(cos(off) * 5, 0), hb + Vector2(cos(off) * 5 + 14, 24), PINK.darkened(0.2 * q), 6)
		elif on and now - started < SCREW_ANIM + 250:   # 다 조이면 반짝
			m.draw_arc(Vector2(p.x, H - p.y), 14, 0, TAU, 16, Color(1, 1, 1, 1.0 - (now - started - SCREW_ANIM) / 250.0), 2)
		if tool == "driver" and not on:
			outline([p0.x - 15, p0.y - 15, p0.x + 15, p0.y + 15], GOLD if fmod(now / 400.0, 2.0) < 1 else PINK, 2)


func draw_tool_cursor() -> void:
	var x := m.mouse.x
	var y := m.mouse.y
	if tool == "driver":   # 손잡이 + 축
		line(Vector2(x, y), Vector2(x + 26, y + 26), Color8(200, 200, 210), 4)
		line(Vector2(x + 26, y + 26), Vector2(x + 50, y + 50), PINK, 12)



func draw_drag() -> void:
	if held.is_empty():
		return
	var pc := Game.pc
	var x := m.mouse.x
	var y := m.mouse.y
	if held[0] == "cable":
		outline(grow(socket_rect(held[1]), 6), CYAN, 2)
		line(cable_start(held[1]), m.mouse, GOLD, 4)
		return
	if held[0] == "out":   # 꽂힌 부품을 재고 쪽으로
		var oid: String = pc.ram[held[2]] if held[1] == "RAM" else pc.parts[held[1]]
		if m.mouse.distance_to(hold_at) > 12:
			outline([2, 2, INV_W - 2, 640], CYAN if x < INV_W else Color(CYAN, 0.5), 3)
			text_c([0, 300, INV_W, 340], "여기 놓으면 빼기", 22, CYAN)
			fit(icon_of(oid), x, y, 56, 56)
		hold_tip(oid)
		return
	var hid := pid_of(held[1])
	var t: String = DB.PARTS[hid]["type"]   # 갈 수 있는 자리 미리 보기
	var zones := []
	if t == "RAM":
		for i in pc.ram_slots():
			if pc.ram[i] == "":
				zones.append([i, ram_rect(i)])
	else:
		zones.append([-1, zone(t)])
	for z in zones:
		var reason := pc.check(hid, z[0])
		outline(grow(z[1], 4), CYAN if reason == "" else PINK, 2)
		if reason != "" and inside(x, y, grow(z[1], 20)):
			text(x + 20, y - 30, reason, 14, PINK)
	fit(icon_of(hid), x, y, 56, 56)
	hold_tip(hid)


## 폰엔 마우스 올림이 없어서: 제자리에서 길게 누르면 부품 이름
func hold_tip(pid: String) -> void:
	if m.held_down and Time.get_ticks_msec() - hold_t > 450 and m.mouse.distance_to(hold_at) < 12:
		var s: String = DB.PARTS[pid]["name"]
		hover_tip(clampf(m.mouse.x + 34, 0, 1270 - text_w(s, 22) - 20), m.mouse.y + 40, s)


func draw_side() -> void:
	var pc := Game.pc
	var x0 := 930
	panel([912, 122, 1276, 638])
	var steps := [["케이스", pc.has("CASE")], ["메인보드", pc.has("MB")], ["CPU (레버 닫기)", pc.has("CPU") and not pc.lever_open],
		["서멀 구리스", pc.paste], ["쿨러", pc.has("COOLER")], ["RAM", pc.ram.any(func(r): return r != "")], ["M.2 SSD", pc.has("SSD")],
		["그래픽 (내장 OK)" if pc.igpu() and not pc.has("GPU") else "그래픽카드", pc.has("GPU") or pc.igpu()], ["파워", pc.has("PSU")],
		["전원선", pc.has("PSU") and pc.cable_targets().all(func(c): return c == "front" or pc.cables.has(c))], ["전원 버튼선", pc.cables.has("front")],
		["나사 조이기", not pc.screws.is_empty() and pc.loose().is_empty()]]
	var done := steps.filter(func(s): return s[1]).size()   # 진행 막대 (할 일은 아래 '다음'이 알려 줌)
	text(x0, 610, "조립 %d / %d" % [done, steps.size()], 22, PINK)
	box([x0, 566, 1258, 584], DARK)
	box([x0, 566, x0 + (1258 - x0) * done / steps.size(), 584], GREEN)
	outline([x0, 566, 1258, 584], DIM, 2)
	var nl := wrap_text("다음: " + next_step()[0], 1270 - x0)
	for i in min(nl.size(), 2):
		text(x0, 536 - i * 26, nl[i], 22, GOLD)
	var b := Bench.run(Bench.parts_of(pc), Game.request().get("use", {}))
	text(x0, 456, "예상 " + Bench.short(b), 22, GREEN if b["ok"] else GOLD)
	text(x0, 426, "전력 %dW / %sW" % [pc.watt(), pc.capacity() if pc.capacity() else "?"], 16, PINK if pc.capacity() and pc.watt() > pc.capacity() else INK)
	var extra := []
	if pc.dual_channel():
		extra.append("듀얼 채널 +1")
	if pc.throttled():
		extra.append("쿨러 부족 -3")
	text(x0, 396, "  ·  ".join(extra), 14, GOLD)
	text(x0, 256, "디버그 LED", 15, QUIET)
	var stage: int = post[0] if not post.is_empty() else -9
	for i in 4:
		var c := Color8(40, 32, 70)
		if stage == 4:
			c = GREEN
		elif stage != -9 and i < stage:
			c = Color8(60, 120, 90)
		elif stage != -9 and i == max(stage, 0):
			c = PINK
		frame("ui_button", [x0 + i * 84, 190, x0 + i * 84 + 74, 232], c)
		text(x0 + i * 84 + 10, 212, PCBuild.POST_STAGES[i], 16, Color.WHITE)
	if not post.is_empty():
		var pl := wrap_text(post[1], 1270 - x0)
		for i in min(pl.size(), 2):
			text(x0, 168 - i * 25, pl[i], 22, GREEN if stage == 4 else PINK)
	button(BTN_POST, "전원", GOLD)
	if Game.request().has("repair"):   # 수리 화면은 수리 의뢰에서만
		button(BTN_DIAG, "수리", PINK)
	elif deliver_here():
		button(BTN_DIAG, "납품하기", PINK)
	button(BTN_BENCH, "성능 테스트", CYAN)


func draw_inventory() -> void:
	panel([-12, -12, INV_W, 650])
	text(14, ROW_TOP + 22, "부품 재고  (끌어서 장착)", 18)
	button(BTN_DRIVER, "드라이버", GOLD if tool == "driver" else VIOLET)
	frame("ui_slot", PASTE_ROW)
	circle(26, 585, 9, Color8(200, 200, 210))
	text(46, 585, clip("서멀 구리스 (눌러서)", PASTE_ROW[2] - 52), 16)
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
		var pid := pid_of(ids[i])
		var p: Dictionary = DB.PARTS[pid]
		var cy: float = (r[1] + r[3]) / 2.0
		fit(icon_of(pid), r[0] + 16, cy, 28, 26)
		if ids[i].begins_with("u"):
			var e: Dictionary = Game.used[int(ids[i].substr(1))]
			box([r[0], r[1], r[0] + 4, r[3]], GOLD)
			var lb := used_label(e)
			text(r[0] + 36, cy, clip(p["name"], r[2] - r[0] - 46 - text_w(lb, 22)), 16, GOLD)
			text(r[2] - 4 - text_w(lb, 22), cy, lb, 16, (GREEN if e["cond"] >= 60 else PINK) if e["known"] else QUIET)
		else:
			var cnt := "x%d" % Game.stock[ids[i]]
			text(r[0] + 36, cy, clip(p["name"], r[2] - r[0] - 46 - text_w(cnt, 22)), 16)
			text(r[2] - 4 - text_w(cnt, 22), cy, cnt, 16, CYAN)
		if inside(m.mouse.x, m.mouse.y, r) and held.is_empty():   # 잘린 이름은 올리면 전체
			hover_tip(INV_W + 8, cy, p["name"])


func draw() -> void:
	grid()
	draw_case()
	if Game.pc.has("CASE"):
		draw_board()
		draw_parts()
		draw_cables()
		draw_screws()
		draw_seat_hints()
		draw_clicks()
	draw_inventory()
	draw_side()
	draw_guide()
	draw_drag()
	draw_hover()
	draw_tool_cursor()
	if Game.pc.has("CASE"):
		button(BTN_SHOW, "완성 모습", CYAN if Game.pc.boots() else VIOLET)
	if showcase:
		box([0, 0, 1280, H], BG)
		grid()
		var on: bool = Game.pc.boots()
		m.modes["desk"].draw_side([382, 50, 898, 603], on)
		text(382, 624, ("완성! 전원이 켜진 모습" if on else "아직 안 켜져요 (전원 테스트로 확인)") + "  ·  누르면 닫기", 22, GREEN if on else GOLD)
	top_bar("build")
	text(INV_W + 20, 30, "끌어다 꽂기 · 재고로 끌어내면 빼기", 13, QUIET)
	if toast != "":
		text(INV_W + 20, 54, toast, 16, PINK)
