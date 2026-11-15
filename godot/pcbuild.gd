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


func has(slot: String) -> bool:
	return parts.has(slot)


func spec(slot: String):
	return DB.PARTS[parts[slot]] if parts.has(slot) else null


func ids() -> Array:
	return parts.values() + ram.filter(func(r): return r != "")


func ram_slots() -> int:
	return spec("MB")["ram_slots"] if has("MB") else 0


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
		if DB.PARTS[pid]["type"] == "RAM":
			ram[ram_slot] = pid
		else:
			parts[DB.PARTS[pid]["type"]] = pid
	return reason


## 부품을 뺀다. 그 위에 올라가 있던 부품 · 전원선도 같이 빠진다. 빠진 부품 id 목록을 돌려준다.
func remove(slot: String, ram_slot := -1) -> Array:
	var out := []
	if slot == "RAM":
		if ram[ram_slot] != "":
			out.append(ram[ram_slot])
			ram[ram_slot] = ""
		return out
	if not has(slot):
		return out
	out.append(parts[slot])
	parts.erase(slot)
	if slot == "CPU":
		paste = false
	if slot == "MB":
		lever_open = false
	for child in NEEDS:
		if NEEDS[child] == slot:
			if child == "RAM":
				out += ram.filter(func(r): return r != "")
				ram = ["", "", "", ""]
			else:
				out += remove(child)
	var ok := cable_targets()
	for c in cables.keys():
		if c not in ok:
			cables.erase(c)
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
	if ram.all(func(r): return r == ""):
		return [1, "DRAM 불이 켜졌어요 (RAM 없음)"]
	if not has("GPU"):
		return [2, "VGA 불이 켜졌어요 (그래픽카드 없음)"]
	if pcie_needed() > spec("PSU")["pcie"]:
		return [2, "VGA 불이 켜졌어요 (이 파워엔 그래픽카드 전원선이 %d개뿐)" % spec("PSU")["pcie"]]
	for i in pcie_needed():
		if not cables.has("pcie%d" % i):
			return [2, "VGA 불이 켜졌어요 (그래픽카드 전원선 확인)"]
	if watt() > capacity():
		return [3, "부팅 중 꺼졌어요 (전력 %dW > 파워 %dW)" % [watt(), capacity()]]
	if not has("SSD"):
		return [3, "BOOT 불이 켜졌어요 (부팅 장치 없음 · SSD)"]
	return [4, "부팅 성공!" + (" 단, 쿨러가 약해서 성능이 떨어져요" if throttled() else "")]


func boots() -> bool:
	return post()[0] == 4


func to_dict() -> Dictionary:
	return {"parts": parts, "ram": ram, "cables": cables.keys(), "lever_open": lever_open, "paste": paste}


static func from_dict(d: Dictionary) -> PCBuild:
	var b := PCBuild.new()
	b.parts = d["parts"]
	b.ram = d["ram"]
	for c in d["cables"]:
		b.cables[c] = true
	b.lever_open = d["lever_open"]
	b.paste = d["paste"]
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
		b.place(d[k])
	for c in b.cable_targets():
		b.plug(c)
	return b
