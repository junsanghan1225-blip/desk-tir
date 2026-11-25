class_name PCBuild
## PC 조립 규칙 (pcbuild.py 이식). 실제 조립 순서:
## 케이스 → 메인보드 → 소켓 레버 열기 → CPU → 레버 닫기 → 서멀 구리스 → 쿨러 → RAM → M.2 SSD → 그래픽카드 → 파워 → 전원선 → 전원 버튼선.
## 전원 테스트(post)는 CPU → DRAM → VGA → BOOT 순서로 검사해 처음 막힌 단계를 알려 준다. 이유 문자열이 ""이면 성공.

const NEEDS := {"MB": "CASE", "CPU": "MB", "COOLER": "CPU", "SSD": "MB", "GPU": "MB", "PSU": "CASE", "RAM": "MB"}
const SIZE_RANK := {"mATX": 0, "ATX": 1}
const POST_STAGES := ["CPU", "DRAM", "VGA", "BOOT"]
const THROTTLE := 3  # 쿨러가 CPU 발열을 못 따라가면 성능 -3

var parts := {}                # 자리(CASE/MB/CPU/COOLER/SSD/GPU/PSU) -> 부품 id
var ram := ["", "", "", ""]    # 슬롯 0~3, 빈 칸은 ""
var cables := {}               # 꽂힌 선: 이름 -> true ('24pin', 'cpu8', 'pcie0', 'pcie1', 'front')
var lever_open := false
var paste := false
var screws := {}               # 자리 -> [조였나, …] (끼우면 헐거운 상태로 시작, 드라이버로 하나씩 조임)
var ties := {}                 # 케이블 타이로 묶은 전원선: 이름 -> true
const SCREWS := {"MB": 4, "COOLER": 4, "GPU": 1, "SSD": 1, "PSU": 2}
var used := {}                 # 중고 부품이 꽂힌 자리("GPU" · "RAM1" …) -> {id, cond(상태 %), paid(산 값), known(상태 확인함)}
var faults := {}               # 수리 의뢰 고장: 이름 -> true (FAULTS). 손님 PC에만 있다

## 고장 도감: [이름, 증상, 단서, 고치는 법 · 실제 팁]
const FAULT_INFO := {
	"psu_switch": ["파워 스위치 꺼짐", "버튼을 눌러도 아무 반응 없음", "뒷면 파워 스위치가 O", "청소 · 이사 뒤 가장 흔한 '고장 아닌 고장'. I로 올리면 끝"],
	"monitor_mb": ["모니터 선을 보드에", "본체는 도는데 화면만 안 나옴", "뒷면: 선이 메인보드 HDMI에", "그래픽카드가 있으면 보드 단자는 보통 꺼져 있어요. 그래픽카드 단자에"],
	"dust": ["먼지", "시끄럽고 점점 뜨거워짐", "팬 · 방열판의 먼지, 팬이 빨리 돎", "6개월~1년마다 에어 스프레이로 청소"],
	"bloat": ["몰래 깔린 채굴 프로그램", "아무것도 안 하는데 느리고 시끄러움", "작업 관리자 CPU 사용률", "모르는 이름의 프로그램은 끝내고 지우기"],
	"ram_seat": ["RAM 접촉 불량", "팬은 도는데 화면 없음 + 삐— 삐 삐", "DRAM LED, 걸쇠가 열림", "'딸깍' 소리가 날 때까지 양쪽을 꾹"],
	"gpu_power": ["그래픽카드 전원선 덜 꽂힘", "팬은 도는데 화면 없음", "VGA LED, 커넥터 틈", "걸쇠가 걸릴 때까지 끝까지 밀기"],
	"cpu_fan": ["CPU 팬 선 빠짐", "조용해졌다가 갑자기 꺼짐", "쿨러 팬이 멈춤, BIOS 0 RPM", "보드의 CPU_FAN 단자에 꽂기"],
	"boot_order": ["부팅 순서 꼬임", "'부팅 장치 없음' 글자만", "BIOS 부팅 1순위가 USB", "윈도우가 깔린 SSD를 1순위로"],
	"paste_dry": ["굳은 서멀 구리스", "오래 쓰면 뜨거워져 느려짐", "쉬는데도 CPU 60°C 이상", "쿨러를 떼고 닦은 뒤 새로 바르기 (2~3년마다)"],
	"xmp_off": ["XMP 꺼짐", "프레임이 조금씩 모자람", "BIOS 메모리 속도 2133MHz", "BIOS에서 XMP를 켜면 RAM이 제 속도로"],
}

## 실제 수리점에서 흔한 고장. 숫자 = 찾기 어려움(난이도 점수)
const FAULTS := {
	"psu_switch": 1,   # 파워 뒤 스위치가 O(꺼짐)
	"monitor_mb": 1,   # 모니터 선을 그래픽카드가 아니라 메인보드 단자에 꽂음
	"dust": 1,         # 팬 · 방열판 먼지 → 시끄럽고 뜨거움
	"bloat": 1,        # 몰래 깔린 채굴 프로그램 → CPU 사용률 높음
	"ram_seat": 2,     # RAM이 반쯤 빠짐 → DRAM 불 + 삐 소리
	"gpu_power": 2,    # 그래픽카드 전원선이 덜 꽂힘 → VGA 불
	"cpu_fan": 2,      # CPU 쿨러 팬 선 빠짐 → 조용하다가 과열로 꺼짐
	"boot_order": 2,   # 부팅 순서가 SSD가 아님
	"paste_dry": 3,    # 서멀 구리스가 말라 굳음 → 오래 쓰면 뜨거워져 느려짐
	"xmp_off": 3,      # BIOS에서 RAM 속도(XMP)가 꺼짐 → 프레임이 조금 모자람
}


func has(slot: String) -> bool:
	return parts.has(slot)


func spec(slot: String):
	return DB.PARTS[parts[slot]] if parts.has(slot) else null


func ids() -> Array:
	return parts.values() + ram.filter(func(r): return r != "")


func ram_slots() -> int:
	return spec("MB")["ram_slots"] if has("MB") else 0


## CPU에 내장 그래픽이 있는지
func igpu() -> bool:
	return has("CPU") and spec("CPU").get("igpu", 0) > 0


func pcie_needed() -> int:
	return spec("GPU")["pcie"] if has("GPU") else 0


## 지금 꽂을 수 있는 선. 전원 버튼선은 케이스 → 보드라 파워 없이도 꽂는다.
func cable_targets() -> Array:
	if not has("MB"):
		return []
	if not has("PSU"):
		return ["front"]
	var out := ["front", "24pin"]
	if has("CPU"):
		out.append("cpu8")
	for i in min(pcie_needed(), spec("PSU")["pcie"]):
		out.append("pcie%d" % i)
	return out


func check(pid: String, ram_slot := -1) -> String:
	var p: Dictionary = DB.PARTS[pid]
	var t: String = p["type"]
	if NEEDS.has(t) and not has(NEEDS[t]):
		return {"CASE": "케이스", "MB": "메인보드", "CPU": "CPU"}[NEEDS[t]] + "부터 끼워야 해요"
	if t == "RAM":
		if ram_slot < 0 or ram_slot >= ram_slots():
			return "이 보드엔 그 RAM 슬롯이 없어요"
		return "이미 RAM이 꽂혀 있어요" if ram[ram_slot] != "" else ""
	if has(t):
		return "이미 끼워져 있어요. 먼저 빼 주세요"
	if t == "CPU" and not lever_open:
		return "소켓 레버를 먼저 열어 주세요"
	if t == "COOLER" and lever_open:
		return "소켓 레버를 닫고 쿨러를 올려 주세요"
	if t == "MB" and SIZE_RANK[p["size"]] > SIZE_RANK[spec("CASE")["mb_max"]]:
		return "%s 보드는 %s에 안 들어가요" % [p["size"], spec("CASE")["name"]]
	if t == "CPU" and p["socket"] != spec("MB")["socket"]:
		return "소켓이 안 맞아요 (CPU %s · 보드 %s)" % [p["socket"], spec("MB")["socket"]]
	if t == "COOLER" and p["height"] > spec("CASE")["cooler_max"]:
		return "쿨러가 높아서 옆판이 안 닫혀요 (%dmm > %dmm)" % [p["height"], spec("CASE")["cooler_max"]]
	if t == "GPU" and p["length"] > spec("CASE")["gpu_max"]:
		return "그래픽카드가 너무 길어요 (%dmm > %dmm)" % [p["length"], spec("CASE")["gpu_max"]]
	return ""


func place(pid: String, ram_slot := -1) -> String:
	var reason := check(pid, ram_slot)
	if reason == "":
		var t: String = DB.PARTS[pid]["type"]
		if t == "RAM":
			ram[ram_slot] = pid
		else:
			parts[t] = pid
		if SCREWS.has(t):
			var s := []
			s.resize(SCREWS[t])
			s.fill(false)
			screws[t] = s
	return reason


## 이 자리 위에 꽂혀 있어서 먼저 빼야 하는 부품 종류 (실제처럼 위에서부터 하나씩)
func blockers(slot: String) -> Array:
	var out := []
	for child in NEEDS:
		if NEEDS[child] == slot and (ram.any(func(r): return r != "") if child == "RAM" else has(child)):
			out.append(child)
	return out


## 중고 부품을 꽂는다 (자리 규칙은 place와 같음)
func place_used(e: Dictionary, ram_slot := -1) -> String:
	var reason := place(e["id"], ram_slot)
	if reason == "":
		used[key_of(DB.PARTS[e["id"]]["type"], ram_slot)] = e
	return reason


static func key_of(t: String, ram_slot := -1) -> String:
	return "RAM%d" % ram_slot if t == "RAM" else t


## 자리별 상태 % (새것 100). RAM은 가장 나쁜 것
func cond_of(t: String) -> int:
	if t == "RAM":
		var worst := 100
		for i in 4:
			if used.has("RAM%d" % i):
				worst = mini(worst, used["RAM%d" % i]["cond"])
		return worst
	return used[t]["cond"] if used.has(t) else 100


## 나사 조이기 / 풀기 (드라이버). 조였으면 true
func turn(slot: String, i: int) -> bool:
	screws[slot][i] = not screws[slot][i]
	return screws[slot][i]


## 나사가 덜 조여진 자리
func loose() -> Array:
	return screws.keys().filter(func(k): return not screws[k].all(func(v): return v))


func tight(slot: String) -> int:
	return screws.get(slot, []).count(true)


## 꽂힌 전원선을 모두 케이블 타이로 묶었는지 (바람길이 트여 조금 시원해짐)
func tidy() -> bool:
	var power := cables.keys().filter(func(c): return c != "front")
	return not power.is_empty() and power.all(func(c): return ties.has(c))


## 부품을 뺀다. 그 위에 올라가 있던 부품 · 전원선도 같이 빠진다. 빠진 부품 id 목록을 돌려준다.
func remove(slot: String, ram_slot := -1) -> Array:
	var out := []
	if slot == "RAM":
		if ram[ram_slot] != "":
			out.append(used.get("RAM%d" % ram_slot, ram[ram_slot]))   # 중고면 상태 정보째로 돌려줌
			used.erase("RAM%d" % ram_slot)
			ram[ram_slot] = ""
		return out
	if not has(slot):
		return out
	out.append(used.get(slot, parts[slot]))
	used.erase(slot)
	parts.erase(slot)
	screws.erase(slot)
	if slot == "COOLER" and faults.erase("paste_dry"):   # 쿨러를 떼면 굳은 구리스가 보이고, 닦아 내면 새로 발라야 함
		paste = false
	if slot == "CPU":
		paste = false
	if slot == "MB":
		lever_open = false
	for child in NEEDS:
		if NEEDS[child] == slot:
			if child == "RAM":
				for i in 4:
					out += remove("RAM", i)
			else:
				out += remove(child)
	var ok := cable_targets()
	for c in cables.keys():
		if c not in ok:
			cables.erase(c)
			ties.erase(c)
	return out


func toggle_lever() -> String:
	if not has("MB"):
		return "메인보드가 없어요"
	if has("COOLER"):
		return "쿨러를 먼저 빼야 레버를 열 수 있어요"
	lever_open = not lever_open
	return ""


func apply_paste() -> String:
	if not has("CPU"):
		return "CPU 위에 발라야 해요"
	if has("COOLER"):
		return "쿨러를 올리기 전에 발라야 해요"
	if lever_open:
		return "레버를 닫고 발라 주세요"
	paste = true
	return ""


func plug(cable: String) -> String:
	if cable not in cable_targets():
		return "지금은 꽂을 데가 없어요"
	cables[cable] = true
	return ""


func dual_channel() -> bool:
	var sticks := ram.filter(func(r): return r != "")
	if sticks.size() != 2 or sticks[0] != sticks[1]:
		return false
	return ram_slots() == 2 or (ram[1] != "" and ram[3] != "")  # 4슬롯 보드는 A2 · B2가 정답


func throttled() -> bool:
	return has("CPU") and has("COOLER") and spec("COOLER")["tdp"] < spec("CPU")["watt"]


func perf() -> int:
	var total := 0
	for i in ids():
		total += DB.PARTS[i].get("perf", 0)
	return max(0, total + (1 if dual_channel() else 0) - (THROTTLE if throttled() else 0))


func stars() -> int:
	var p := perf()
	return 3 if p >= 19 else 2 if p >= 12 else 1 if p >= 6 else 0


func watt() -> int:
	var total := 0
	for i in ids():
		total += DB.PARTS[i].get("watt", 0)
	return total


func capacity() -> int:
	return spec("PSU")["capacity"] if has("PSU") else 0


## [통과한 단계 수(-1~4), 메시지]. 4면 부팅 성공.
func post() -> Array:
	if not has("CASE") or not has("MB"):
		return [-1, "메인보드가 없어요"]
	if faults.has("psu_switch"):   # 증상만 알려 준다 (원인은 진단 화면에서)
		return [-1, "전원 버튼을 눌러도 아무 반응이 없어요"]
	if not has("PSU") or not cables.has("24pin"):
		return [-1, "전원이 안 들어와요 (파워 · 24핀 확인)"]
	if not cables.has("front"):
		return [-1, "전원 버튼을 눌러도 반응이 없어요 (케이스 전원 버튼선)"]
	if not has("CPU") or not cables.has("cpu8"):
		return [0, "CPU 불이 켜졌어요 (CPU · CPU 8핀 확인)"]
	if lever_open:
		return [0, "CPU 불이 켜졌어요 (소켓 레버가 열려 있어요)"]
	if not has("COOLER"):
		return [0, "켜지자마자 과열로 꺼졌어요 (쿨러 없음)"]
	if not paste:
		return [0, "몇 초 뒤 과열로 꺼졌어요 (서멀 구리스 안 바름)"]
	if faults.has("ram_seat"):
		return [1, "팬은 도는데 화면이 안 나오고 삐— 삐 삐 소리가 나요"]
	if ram.all(func(r): return r == ""):
		return [1, "DRAM 불이 켜졌어요 (RAM 없음)"]
	if not has("GPU") and not igpu():   # 내장 그래픽 CPU면 그래픽카드 없이도 화면이 나옴 (모니터는 보드 단자에)
		return [2, "VGA 불이 켜졌어요 (그래픽카드 없음 · 이 CPU는 내장 그래픽이 없어요)"]
	if pcie_needed() > spec("PSU")["pcie"]:
		return [2, "VGA 불이 켜졌어요 (이 파워엔 그래픽카드 전원선이 %d개뿐)" % spec("PSU")["pcie"]]
	for i in pcie_needed():
		if not cables.has("pcie%d" % i):
			return [2, "VGA 불이 켜졌어요 (그래픽카드 전원선 확인)"]
	if faults.has("gpu_power"):
		return [2, "팬은 도는데 화면이 안 나와요"]
	if watt() > capacity():
		return [3, "부팅 중 꺼졌어요 (전력 %dW > 파워 %dW)" % [watt(), capacity()]]
	if not has("SSD") or faults.has("boot_order"):
		if faults.has("boot_order"):
			return [3, "'부팅 장치를 찾을 수 없음' 글자만 떠요"]
		return [3, "BOOT 불이 켜졌어요 (부팅 장치 없음 · SSD)"]
	if cond_of("SSD") < 30:
		return [3, "부팅이 한참 걸리다가 멈춰요"]
	if "SSD" in loose():
		return [3, "BOOT 불이 켜졌어요 (SSD가 들떠 있어요 · 나사)"]
	return [4, "부팅 성공!" + (" 단, 쿨러가 약해서 성능이 떨어져요" if throttled() else "")]


func boots() -> bool:
	return post()[0] == 4


## 모니터에 화면이 나오는지 (켜져도 선을 메인보드에 꽂으면 신호 없음)
func picture() -> bool:
	return boots() and not faults.has("monitor_mb")


## 고장 난이도 ★1~3
static func level_of(fs: Array) -> int:
	var s := 0
	for f in fs:
		s += FAULTS.get(f, 1)
	return clampi(ceili(s / 2.0), 1, 3)


func to_dict() -> Dictionary:
	return {"parts": parts, "ram": ram, "cables": cables.keys(), "lever_open": lever_open, "paste": paste, "faults": faults.keys(), "screws": screws, "ties": ties.keys(), "used": used}


static func from_dict(d: Dictionary) -> PCBuild:
	var b := PCBuild.new()
	b.parts = d["parts"]
	b.ram = d["ram"]
	for c in d["cables"]:
		b.cables[c] = true
	b.lever_open = d["lever_open"]
	b.paste = d["paste"]
	for f in d.get("faults", []):
		b.faults[f] = true
	for t in b.parts:   # 예전 저장: 다 조인 것으로
		if SCREWS.has(t):
			b.screws[t] = d.get("screws", {}).get(t, [])
			if b.screws[t].size() != SCREWS[t]:
				b.screws[t] = []
				b.screws[t].resize(SCREWS[t])
				b.screws[t].fill(true)
	for c in d.get("ties", []):
		b.ties[c] = true
	b.used = d.get("used", {})
	return b


## 테스트 · 데모용: 실제 순서대로 끼우고 선까지 꽂은 PC. o로 부품을 바꾼다.
static func full(o := {}) -> PCBuild:
	var d := {"case": "case2", "mb": "mb2", "cpu": "cpu2", "cooler": "cool1", "ram": ["ram2", "ram2"], "gpu": "gpu2", "psu": "psu2", "ssd": "ssd1"}
	d.merge(o, true)
	var b := PCBuild.new()
	b.place(d["case"])
	b.place(d["mb"])
	b.toggle_lever()
	b.place(d["cpu"])
	b.toggle_lever()
	b.apply_paste()
	b.place(d["cooler"])
	var slots := [1, 3] if b.ram_slots() == 4 else [0, 1]
	for i in d["ram"].size():
		b.place(d["ram"][i], slots[i])
	for k in ["ssd", "gpu", "psu"]:
		if d[k] != "":   # gpu ""면 내장 그래픽만
			b.place(d[k])
	for c in b.cable_targets():
		b.plug(c)
	for t in b.screws:
		b.screws[t].fill(true)
	return b
