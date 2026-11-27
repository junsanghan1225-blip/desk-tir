class_name Game
## 게임 진행 상태 (state.py + save_game.py 이식).
## 가게(여러 날 유지): 돈 · 날짜 · 창고 · 업그레이드 · 별 · 단골 기록 · 오늘 장부. 주문(손님 한 명 동안): 장바구니 · 배치 · PC · 케이블.

const START_MONEY := 300
const LEVELS := [0, 3, 9, 17, 27]     # 가게 레벨 n이 되려면 필요한 누적 별
const TIP_RATE := [3, 4, 5, 6, 7]   # 레벨별 별 1개당 팁 (예산의 %). 예산이 빠듯해서 팁 · 알뜰 구매가 마진
static var SAVE_PATH := "user://save.json"   # 테스트는 test_save.json을 써서 실제 저장을 안 건드림

static var money := START_MONEY
static var day := 1
static var stock := {}         # 창고: id -> 개수
static var upgrades := {}      # 산 업그레이드: id -> true
static var stars_total := 0
static var history := {}       # 손님 이름 -> 지난번 별
static var ledger := []        # 오늘 영업 기록 {customer, stars, pay, tip, cost}
static var order_index := 0
static var used := []          # 중고 창고: {id, cond(실제 상태 %), paid, known, note}
static var bought := {}        # 오늘 중고 장터에서 산 매물 키 -> true
static var dex := {}           # 도감: "p:부품id" · "f:고장" -> true
static var stats := {}         # 업적용 누적 기록
static var achv := {}          # 달성한 업적 -> true
static var visits := {}        # 손님 이름 -> [방문마다 받은 별]
static var new_achv := []      # 방금 달성한 업적 (결과 화면에 띄움)
static var shelf := []         # 창고 랙: 미리 조립해 둔 PC (PCBuild.to_dict)
static var my_desk := {}       # 내 책상 (손님 책상과 같은 방식): pack() 모양 {placed, pc, cables}
static var mine := false       # 지금 쇼핑 · 책상 · 조립 · 배선 화면이 '내 책상'을 꾸미는 중인지 (손님 주문 대신)
## 내 책상 꾸미는 동안의 '의뢰': 예산 제한 없음 · 성능 목표는 게임 144fps (자랑용 숫자)
const MY_REQ := {"customer": "내 책상", "face": "dev", "budget": 99999, "required": [], "forbidden": [], "theme": [], "lines": [],
	"use": {"kind": "game", "genre": "fps", "res": "1080p", "fps": 144}}

## 업적: id -> [이름, 설명, 보상(만 원), 조건(stats)]
const ACHV := {
	"first": ["첫 납품", "손님에게 처음 PC를 납품", 5],
	"perfect5": ["완벽주의자", "별 3개 5번", 20],
	"fixer": ["수리 기사", "서로 다른 고장 3종 고치기", 15],
	"doctor": ["PC 닥터", "고장 도감 완성", 50],
	"thrift": ["알뜰 살림", "중고 부품을 5개 넣어 납품", 15],
	"scammed": ["속았다…", "상태 40% 미만 중고를 사 버림", 3],
	"silent": ["숨죽인 PC", "28dB 이하로 납품", 10],
	"speed": ["240 클럽", "240fps 이상 게이밍 PC 납품", 15],
}
## 일일 목표: [설명, 보상, 확인할 기록]
const DAILY := [["별 3개 2번 받기", 20, "three"], ["오늘 마진 합계 120만 이상", 20, "margin"], ["중고 부품 2개 이상 써서 납품", 15, "used"],
	["수리 의뢰를 별 3개로", 20, "repair3"], ["모든 손님에게 별 2개 이상", 25, "all2"]]

static var cart := {}
static var order_mod := {}   # 주문 중 손님 전화로 바뀐 의뢰 내용 (request()가 덮어씀)
static var placed := []
static var pc := PCBuild.new()
static var cables := []
static var power := false   # 책상에서 PC 전원을 켰는지 (조립을 바꾸면 꺼짐)
static var power_t := 0     # 켠 시각 (부팅 화면 → 바탕화면)
static var checkouts := 0   # 이번 주문 결제 횟수 (두 번째부터 배송비)
static var ship_paid := 0   # 이번 주문 추가 배송비 (만)
static var bill := []       # 마지막 정산 내역 [[항목, 금액(만)], ...] → 결과 화면
static var looks := {}       # 이번 수리에서 들여다본 진단 화면 (정면 빼고). 무료는 FREE_LOOKS곳, 그다음은 화면마다 점검비
const FREE_LOOKS := 2
const LOOK_FEE := 1          # 만 원. 수리비가 3~12만이라 아무 데나 다 열어 보면 남는 게 없음 → 증상으로 짐작하고 열기
static var hints_used := 0  # 이번 수리에서 본 힌트 수 (0이면 명탐정 보너스)
static var streak := 0      # 연속 별 3개 (팁이 점점 커짐)
static var burn := ""  # 납품 전 번인 테스트 결과: "" 안 함 · good 적정 · early 너무 일찍 · hot 과열
static var last_gift := ""  # 만족한 손님이 두고 간 선물 (창고로)
const SHIP_FEE := 2         # 한 주문에서 두 번째 결제부터 붙는 배송비 (만)


static func new_game() -> void:
	money = START_MONEY
	day = 1
	stock = {}
	upgrades = {}
	stars_total = 0
	streak = 0
	history = {}
	used = []
	dex = {}
	stats = {}
	achv = {}
	visits = {}
	shelf = []
	my_desk = {}
	mine = false
	start_day()
	reset_order()


static func start_day() -> void:
	ledger = []
	bought = {}
	order_index = 0


static func last_day() -> int:
	return DB.REQUESTS.map(func(r): return r["day"]).max()


static func todays_requests() -> Array:
	return DB.REQUESTS.filter(func(r): return r["day"] == day)


## 지금 손님 의뢰. 주문 중 걸려 온 전화(예산 깎기 · 추가 요청)가 있으면 그걸 덮어쓴 것
static func request() -> Dictionary:
	if mine:
		return MY_REQ
	var r: Dictionary = todays_requests()[order_index]
	return r if order_mod.is_empty() else r.merged(order_mod, true)


## ---------- 주문 중 손님 전화 (돌발 이벤트) ----------
## 둘째 날부터, 한 번이라도 결제한 뒤 책상 · 조립 · 배선으로 가면 가끔 손님이 전화한다. 날이 갈수록 자주. 특이 조건이 있는 의뢰엔 안 옴.
const CALL_CHANCE := [0, 0, 25, 35, 45, 55]   # 날짜별 %. 매번 오면 놀랍지 않으니 절반쯤만
static func call_due() -> bool:
	if order_mod.has("call") or checkouts < 1 or order_index >= todays_requests().size() or request().has("repair") or request().has("twist") or request().get("type") == "pc":   # 한 주문엔 신경 쓸 거리 하나만
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 1009 + order_index * 31 + 7   # 같은 날 같은 손님이면 늘 같음 (다시 해도 공평)
	return rng.randi() % 100 < CALL_CHANCE[mini(day, CALL_CHANCE.size() - 1)]


## 전화 내용을 정하고 의뢰에 반영 (예산 삭감 → 산 걸 덜어내야 할 수도 · 소품 하나 추가). 손님 말을 돌려줌
static func take_call() -> String:
	var req := request()
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7717 + order_index
	var k: String = ["budget", "extra"][rng.randi() % 2]
	if k == "extra":
		var have := []
		for r in req["required"]:
			have += r["any"]
		var pool := DB.ITEMS.keys().filter(func(i): return DB.ITEMS[i]["price"] <= 6 and not DB.ITEMS[i].has("line") and not DB.ITEMS[i].has("hz") and DB.ITEMS[i]["tags"].has(req["theme"][0]) and i not in have and i not in req["forbidden"])
		if pool.is_empty():
			k = "budget"
		else:
			var id: String = pool[rng.randi() % pool.size()]
			order_mod = {"call": k, "required": req["required"] + [{"any": [id], "count": 1, "named": true}]}
			return "아 참, %s도 하나 놓아 주실 수 있어요? 예산은 그대로라 죄송해요!" % _name(id)
	var cut: int = maxi(5, roundi(req["budget"] * 0.08 / 5.0) * 5)
	order_mod = {"call": "budget", "budget": req["budget"] - cut}
	return "죄송해요, 갑자기 돈 들 데가 생겨서… 예산을 %d만 줄여도 될까요?" % cut


## 특이 조건 한 줄 (책상에서 맞추면 ✓)
const TWIST_TEXT := {"few": "책상이 좁아요: 책상 위 물건 %d개까지", "left": "왼손잡이예요: 마우스는 키보드 왼쪽에", "dual": "화면 두 개로 써요: 모니터 2대"}
static func twist_text(req: Dictionary) -> String:
	if not req.has("twist"):
		return ""
	var t: Dictionary = req["twist"]
	var s: String = TWIST_TEXT[t["kind"]] % t["n"] if "%d" in TWIST_TEXT[t["kind"]] else TWIST_TEXT[t["kind"]]
	return ("✓ " if Rules.twist_ok(t, placed) else "") + s


## 손님 대사. 다시 온 단골은 지난번 별점(2개 이상이면 좋은 기억)에 따라 말이 달라진다.
static func lines(req = null) -> Array:
	if req == null:
		req = request()
	if req.has("lines"):
		return req["lines"]
	return req["lines_good"] if history.get(req["customer"], 0) >= 2 else req["lines_bad"]


static func today() -> Dictionary:
	return DB.DAYS[day]


static func reset_order() -> void:
	order_mod = {}
	looks = {}
	hints_used = 0
	burn = ""
	last_gift = ""
	checkouts = 0
	ship_paid = 0
	power = false
	cart = {}
	placed = []
	pc = repair_pc()
	cables = []


## 수리 의뢰면 손님이 맡긴 고장 난 PC, 아니면 빈 케이스
static func repair_pc() -> PCBuild:
	if order_index >= todays_requests().size():   # 영업 마감 뒤 등 손님이 없을 때
		return PCBuild.new()
	var rep: Dictionary = request().get("repair", {})
	if rep.is_empty():
		return PCBuild.new()
	var b := PCBuild.full(rep["pc"])
	var age: int = rep.get("age", 3)   # 손님 PC는 쓴 지 몇 년 된 중고 (값 0원)
	for t in b.parts:
		b.used[t] = {"id": b.parts[t], "cond": rep.get("cond", {}).get(t, 100 - age * 8), "paid": 0, "known": false, "note": "손님 PC에서 뺀 부품"}
	for i in 4:
		if b.ram[i] != "":
			b.used["RAM%d" % i] = {"id": b.ram[i], "cond": 100 - age * 8, "paid": 0, "known": false, "note": "손님 PC에서 뺀 부품"}
	for f in rep["break"]:
		b.faults[f] = true
	return b


## 손님에게 갈 컴퓨터: 조립한 PC, 없으면 책상 위 노트북(그 자체가 컴퓨터)
static var _laptops := {}
static func computer() -> PCBuild:
	if pc.has("CASE"):
		return pc
	for p in placed:
		var spec = DB.ITEMS[p["id"]].get("pc")
		if spec:
			if not _laptops.has(p["id"]):
				var lp := PCBuild.full(spec)
				lp.set_meta("laptop", true)   # 노트북은 Wi-Fi 기본
				for c in lp.cables:   # 노트북은 공장에서 깔끔하게 조립된 완제품
					lp.ties[c] = true
				_laptops[p["id"]] = lp
			return _laptops[p["id"]]
	return pc


## 의뢰 난이도 ★1~3: 수리는 고장 개수 · 숨은 정도, 조립은 요구 성능
static func difficulty(req: Dictionary) -> int:
	if req.has("repair"):
		return PCBuild.level_of(req["repair"]["break"])
	var u: Dictionary = req.get("use", {})
	var s := 0 if u.get("kind", "office") == "office" else 1
	s += 1 if u.has("quiet") else 0
	s += 1 if req.has("twist") else 0   # 특이 조건
	s += 1 if u.get("stream", false) or u.get("fps", 0) >= 240 or u.get("res", "") != "1080p" and u.has("res") else 0
	return clampi(s, 1, 3)


## 오늘의 중고 장터 매물 3개 (날짜로 정해짐). 가끔은 아예 고장 난 물건(dead)도 섞여 있다. 판매자 말(claim)로 값이 정해지고, 진짜 상태(cond)는 꽂고 테스트해야 안다.
static func offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var out := []
	for k in 3:   # 하루 매물은 3개만 (너무 많으면 새 제품이 묻힘)
		var t: String = ["GPU", "GPU", "CPU", "CPU", "RAM", "PSU", "COOLER", "SSD", "MB", "CASE"][rng.randi() % 10]
		var ids := DB.PARTS.keys().filter(func(p): return DB.PARTS[p]["type"] == t)
		ids.sort()
		var id: String = ids[rng.randi() % ids.size()]
		var cond := rng.randi_range(25, 95)
		var lie := rng.randf() < 0.35   # 셋 중 하나는 상태를 부풀림
		var dead := rng.randf() < 0.12 + (0.2 if cond < 40 else 0.0)   # 꽂아 보면 아예 안 됨
		var claim: String = "거의 새것이에요" if cond >= 80 or lie else "사용감 조금 있어요" if cond >= 55 else "작동은 돼요"
		if t == "GPU" and claim == "거의 새것이에요":
			claim = "채굴 안 했어요, 거의 새것"
		var rate: float = {"거의 새것이에요": 0.7, "채굴 안 했어요, 거의 새것": 0.7, "사용감 조금 있어요": 0.5, "작동은 돼요": 0.3}[claim]
		out.append({"key": "d%d_%d" % [day, k], "id": id, "cond": cond, "claim": claim, "dead": dead, "price": maxi(1, roundi(DB.PARTS[id]["price"] * rate))})
	return out.filter(func(o): return not bought.has(o["key"]))


static func buy_offer(o: Dictionary) -> bool:
	if o["price"] > money or bought.has(o["key"]):
		return false
	money -= o["price"]
	bought[o["key"]] = true
	used.append({"id": o["id"], "cond": o["cond"], "paid": o["price"], "known": false, "dead": o.get("dead", false), "note": "판매자: " + o["claim"]})
	return true


## 중고 되팔기: 새 값 × 상태 × 30%
static func sell_used(i: int) -> int:
	var e: Dictionary = used[i]
	var v: int = 1 if e.get("dead", false) and e["known"] else maxi(1, roundi(price_of(e["id"]) * e["cond"] / 100.0 * 0.3))   # 고장 난 걸 알면 고철값
	money += v
	used.remove_at(i)
	return v


static func unlocked(thing: Dictionary) -> bool:
	return not thing.has("line") or upgrades.has(thing["line"])


static func price_of(id: String) -> int:
	return DB.spec(id)["price"]


static func add_to_cart(id: String, n := 1) -> bool:
	if not unlocked(DB.spec(id)):
		return false
	cart[id] = cart.get(id, 0) + n
	if cart[id] <= 0:
		cart.erase(id)
	return true


static func cart_total() -> int:
	var total := 0
	for id in cart:
		total += price_of(id) * cart[id]
	return total


## 결제: 가게 돈에서 빠지고 물건은 창고로. 돈이 모자라면 아무것도 안 바뀌고 빈 Dictionary.
static func checkout() -> Dictionary:
	var total := cart_total()
	var fee := SHIP_FEE if checkouts > 0 else 0   # 방해 요소: 나눠 사면 배송비
	if cart.is_empty() or total + fee > money:
		return {}
	checkouts += 1
	ship_paid += fee
	money -= total + fee
	var receipt := cart.duplicate()
	for id in cart:
		stock[id] = stock.get(id, 0) + cart[id]
	cart.clear()
	return {"items": receipt, "total": total, "fee": fee}


## 반품: 산 값의 절반 환불.
static func sell_back(id: String) -> bool:
	if stock.get(id, 0) <= 0:
		return false
	stock[id] -= 1
	money += price_of(id) / 2
	return true


static func level() -> int:
	return LEVELS.filter(func(need): return stars_total >= need).size()


static func buy_upgrade(uid: String) -> bool:
	var up: Dictionary = DB.UPGRADES[uid]
	if upgrades.has(uid) or up["price"] > money:   # 레벨 제한 없이 모은 가게 돈으로 해금
		return false
	money -= up["price"]
	upgrades[uid] = true
	return true


static func take(id: String) -> bool:
	if stock.get(id, 0) <= 0:
		return false
	stock[id] -= 1
	return true


static func give_back(id: String) -> void:
	stock[id] = stock.get(id, 0) + 1


## 이번 주문에 들어간 물건 값 합 (손님 예산을 넘으면 안 된다).
static func spent() -> int:
	var total := 0
	for p in placed:
		total += price_of(p["id"])
	for t in pc.parts:   # 중고는 산 값(손님 부품은 0원), 새것은 정가
		total += pc.used[t]["paid"] if pc.used.has(t) else price_of(pc.parts[t])
	for i in 4:
		if pc.ram[i] != "":
			total += pc.used["RAM%d" % i]["paid"] if pc.used.has("RAM%d" % i) else price_of(pc.ram[i])
	return total


static func money_left() -> int:
	return request()["budget"] - spent()


static func look_cost() -> int:
	return maxi(0, looks.size() - FREE_LOOKS) * LOOK_FEE


## 번인 테스트: 바늘이 0 → 1로 가는 동안 [lo, hi] 안에서 멈추면 적정. hi는 CPU가 뜨거울수록 빨리 옴 (쿨러 · 케이스)
const BURN := {"good": "번인 테스트 통과 (불량 미리 잡음)", "early": "번인 부족 → 숨은 불량 A/S", "hot": "번인 과열 → 부품 열화 보상"}


static func burn_zone(cpu_temp: int, jitter: float) -> Array:
	var lo := 0.45 + jitter   # jitter: -0.06 ~ 0.06 (매번 조금씩 다르게)
	return [lo, minf(0.97, lo + clampf((95 - cpu_temp) / 100.0, 0.08, 0.40))]


static func burn_grade(k: float, zone: Array) -> String:
	return "early" if k < zone[0] else "hot" if k > zone[1] else "good"


static func burn_money(budget: int) -> int:   # 좋으면 +, 나쁘면 − (예산의 4%, 최소 2만)
	var v := maxi(2, budget * 4 / 100)
	return {"good": v, "early": -v, "hot": -v}.get(burn, 0)


## 납품 정산: 손님은 예산만큼 내고 별 1개당 팁. 별 0개면 0원. [대금, 팁]
const PAY_RATE := [40, 80, 100, 100]   # 별 0~3개일 때 받는 비율(%). 별 0개 = 실망: 그래도 일부는 냄


static func settle(result: Dictionary) -> Array:
	var budget: int = request()["budget"]
	var sat: int = roundi(budget * PAY_RATE[result["stars"]] / 100.0) - budget   # 실망하면 깎아서 냄
	var pay: int = max(0, budget + sat)
	var tip: int = result["stars"] * budget * TIP_RATE[level() - 1] / 100
	streak = streak + 1 if result["stars"] == 3 else 0   # 계속할 이유: 연속 만점이면 팁이 불어남
	var combo: int = tip * mini(streak - 1, 3) / 2 if streak >= 2 else 0
	var sleuth: int = 2 if request().has("repair") and result["stars"] > 0 and hints_used == 0 else 0
	var look_fee := look_cost()
	var burn_v := burn_money(budget)
	money += pay + tip + combo + sleuth - look_fee + burn_v
	last_gift = gift() if result["stars"] == 3 else ""
	if last_gift != "":
		stock[last_gift] = stock.get(last_gift, 0) + 1
	bill = [["손님 예산", budget], ["만족도 별 %d개 (%d%%)" % [result["stars"], PAY_RATE[result["stars"]]], sat],
		["팁", tip], ["연속 만점 %d번째 (팁 보너스)" % streak, combo], ["명탐정 보너스 (힌트 없이 수리)", sleuth], ["점검 시간 (무료 %d곳 넘게 열어 봄)" % FREE_LOOKS, -look_fee],
		[BURN.get(burn, "번인 테스트"), burn_v], ["물건 값", -spent()]]
	if ship_paid > 0:
		bill.append(["나눠 산 배송비 (%d번)" % (checkouts - 1), -ship_paid])
	stars_total += result["stars"]
	history[request()["customer"]] = result["stars"]
	visits[request()["customer"]] = visits.get(request()["customer"], []) + [result["stars"]]
	ledger.append({"customer": request()["customer"], "stars": result["stars"], "pay": pay, "tip": tip, "cost": spent()})
	var b := Bench.run(Bench.parts_of(computer()), request().get("use", {"kind": "office"}))
	var n_used := pc.used.values().filter(func(e): return e["paid"] > 0).size()   # 직접 사 온 중고만
	ledger[-1].merge({"used": n_used, "noise": b.get("noise", 99), "repair": request().has("repair")})
	if result["stars"] > 0:   # 도감 · 업적 기록
		for id in computer().ids():
			dex["p:" + id] = true
		for f in request().get("repair", {}).get("break", []):
			dex["f:" + f] = true
		_add("deliver", 1)
		_add("three", 1 if result["stars"] == 3 else 0)
		_add("used", n_used)
		if b.get("noise", 99) <= 28:
			stats["silent"] = 1
		if b["kind"] == "game" and b["value"] >= 240:
			stats["speed"] = 1
	check_achv()
	return [pay, tip]   # 교체하고 남은 헌 부품은 중고 창고에 남음 (손님이 처분해 달래요)


## 만족한 손님의 선물: 아직 안 가진 싼 소품 하나 (날짜 · 순서로 정해짐)
static func gift() -> String:
	var pool := DB.ITEMS.keys().filter(func(i): return DB.ITEMS[i]["price"] <= 6 and unlocked(DB.ITEMS[i]) and not stock.has(i) and i != "monitor")
	if pool.is_empty():
		return ""
	return pool[(day * 31 + order_index * 7) % pool.size()]


## 내일 예약 손님: [몇 명, 그중 한 명의 첫마디] → 영업 마감 화면 예고
static func teaser() -> Array:
	var reqs := DB.REQUESTS.filter(func(q): return q["day"] == day + 1)
	if reqs.is_empty():
		return [0, ""]
	return [reqs.size(), lines(reqs[day % reqs.size()])[0]]


static func _add(k: String, n: int) -> void:
	stats[k] = stats.get(k, 0) + n


static func faults_known() -> int:
	return dex.keys().filter(func(k): return k.begins_with("f:")).size()


## 새로 달성한 업적은 보상을 주고 new_achv에 담는다
static func check_achv() -> void:
	new_achv = []
	var done := {"first": stats.get("deliver", 0) >= 1, "perfect5": stats.get("three", 0) >= 5, "fixer": faults_known() >= 3,
		"doctor": faults_known() >= PCBuild.FAULTS.size(), "thrift": stats.get("used", 0) >= 5, "scammed": stats.get("scammed", 0) > 0,
		"silent": stats.get("silent", 0) > 0, "speed": stats.get("speed", 0) > 0}
	for k in done:
		if done[k] and not achv.has(k):
			achv[k] = true
			money += ACHV[k][2]
			new_achv.append(k)


## 큰 목표: 마지막 날 마감까지 가게 돈 GOAL
static func goal() -> int:
	return DB.STORY["goal"]


static func goal_met() -> bool:
	return money >= goal()


## 손님 뒷이야기: 마지막 방문 별 2개 이상이면 좋은 결말
static func epilogue(name: String) -> String:
	return DB.STORY["epilogue"].get(name, ["", ""])[0 if history.get(name, 0) >= 2 else 1]


static func daily() -> Array:
	return DAILY[(day - 1) % DAILY.size()]


## 오늘 목표를 이뤘는지 (오늘 장부로 판단)
static func daily_done() -> bool:
	var kind: String = daily()[2]
	if ledger.is_empty():
		return false
	match kind:
		"three": return ledger.filter(func(r): return r["stars"] == 3).size() >= 2
		"margin": return ledger.reduce(func(a, r): return a + r["pay"] + r["tip"] - r["cost"], 0) >= 120
		"used": return ledger.reduce(func(a, r): return a + r.get("used", 0), 0) >= 2
		"repair3": return ledger.any(func(r): return r.get("repair", false) and r["stars"] == 3)
	return ledger.all(func(r): return r["stars"] >= 2)


## 영업 마감 때 한 번: 일일 목표 보상
static func claim_daily() -> int:
	if stats.has("daily%d" % day) or not daily_done():
		return 0
	stats["daily%d" % day] = 1
	money += daily()[1]
	return daily()[1]


static func next_customer() -> bool:
	order_index += 1
	return order_index < todays_requests().size()


# ---------- 창고: 미리 조립한 PC 랙 · 내 전시 책상 ----------
const SHELF_MAX := 6   # 진열대 2단 × 3대
const SHELF_FEE := 1   # 랙 PC 한 대당 하루 보관료(만). 공짜면 미리 조립이 의뢰 긴장감을 무너뜨려서


static func in_order() -> bool:
	return order_index < todays_requests().size() and not request().has("repair")


## 조립대 PC를 랙에 올림 (켜지는 PC만). 못 하면 이유
static func shelve() -> String:
	if not (in_order() or mine) or not pc.has("CASE"):
		return "조립대에 있는 PC를 올려요 (주문 중 · 내 책상)"
	if shelf.size() >= SHELF_MAX:
		return "랙이 꽉 찼어요 (%d대)" % SHELF_MAX
	if not pc.boots():
		return "켜지는 PC만 보관해요 (전원 테스트부터)"
	shelf.append(pc.to_dict())
	pc = PCBuild.new()
	power = false
	return ""


## 랙 PC가 지금 손님 조건에 맞는지: 용도 성능 · 새 제품만
static func shelf_fits(i: int) -> bool:
	var b := PCBuild.from_dict(shelf[i])
	var req := request()
	if req.get("used", "") == "new" and not b.used.is_empty():
		return false
	if req.has("use"):
		return Bench.run(Bench.parts_of(b), req["use"])["ok"]
	return b.stars() >= req.get("perf", 1)


## 랙 PC를 조립대로 (조건이 맞고 예산 안일 때만). 못 하면 이유
static func unshelve(i: int) -> String:
	if not in_order():
		return "손님 주문 중에만 꺼내 쓸 수 있어요"
	if pc.has("CASE"):
		return "조립대가 비어 있어야 해요"
	if not shelf_fits(i):
		return "이 손님 조건엔 안 맞아요"
	pc = PCBuild.from_dict(shelf[i])
	if money_left() < 0:
		pc = PCBuild.new()
		return "손님 예산을 넘어요"
	shelf.remove_at(i)
	power = false
	return ""


static func shelf_fee() -> int:
	return shelf.size() * SHELF_FEE


## 다음 날로 넘어갈 때 보관료
static func pay_shelf_fee() -> int:
	money -= shelf_fee()
	return shelf_fee()


## 진열대 PC ↔ 내 책상 PC (원래 있던 건 진열대로). 내 책상 꾸미는 중이면 지금 조립대에 바로
static func pc_to_desk(i: int) -> void:
	var old: Dictionary = pc.to_dict() if mine else my_desk.get("pc", {})
	var nw: Dictionary = shelf[i]
	shelf.remove_at(i)
	if mine:
		pc = PCBuild.from_dict(nw)
		power = false
	else:
		my_desk = {"placed": my_desk.get("placed", []), "cables": my_desk.get("cables", []), "pc": nw}
	if old.get("parts", {}).has("CASE"):
		shelf.append(old)


## 내 책상 꾸미기 시작: 손님 주문 상태 대신 내 책상을 쇼핑 · 책상 · 조립 · 배선 화면에 올림 (영업 마감 때만)
static func enter_mine() -> void:
	reset_order()
	mine = true
	if not my_desk.is_empty():
		unpack(my_desk)


static func exit_mine() -> void:
	my_desk = pack()
	mine = false
	reset_order()


## 책상 · PC · 선을 저장 모양으로 (모니터에 붙은 소품의 host · 선의 기기는 번호로)
static func pack() -> Dictionary:
	var flat := placed.map(func(p):
		var q: Dictionary = p.duplicate()
		if q.has("host"):
			q["host"] = placed.find(p["host"])
		return q)
	return {"placed": flat, "pc": pc.to_dict(), "cables": cables.map(func(c): return {"dev": placed.find(c["dev"]), "type": c["type"], "port": c["port"]})}


static func unpack(d: Dictionary) -> void:
	placed = d["placed"]
	for p in placed:
		if p.has("host"):
			p["host"] = placed[p["host"]]
	pc = PCBuild.from_dict(d["pc"])
	cables = d["cables"].map(func(c): return {"dev": placed[c["dev"]], "type": c["type"], "port": c["port"]})


# ---------- 저장 · 이어하기 ----------
static func save(mode: String) -> void:
	if mine:   # 내 책상 꾸미는 중: 손님 주문은 없으니 영업 마감 화면으로 이어감
		my_desk = pack()
		mode = "day_end"
	var oi := order_index
	if mode == "result":  # 정산은 끝났으니 다음 단계부터 이어간다
		var more := oi + 1 < todays_requests().size()
		mode = "request" if more else "day_end"
		oi += 1 if more else 0
	var order = null
	if mode in ["shop", "desk", "build", "wire"]:
		order = pack().merged({"cart": cart, "mod": order_mod})
	var d := {"mode": mode, "money": money, "day": day, "stock": stock, "upgrades": upgrades.keys(), "stars_total": stars_total,
		"history": history, "streak": streak, "ledger": ledger, "order_index": oi, "order": order, "used": used, "bought": bought, "dex": dex, "stats": stats, "achv": achv, "visits": visits,
		"shelf": shelf, "my_desk": my_desk}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


## 저장 내용(없거나 깨졌으면 빈 Dictionary).
static func peek() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return DB.ints(d) if d is Dictionary and d.has("mode") else {}


## 상태를 되살리고 이어서 열 화면 이름을 돌려준다 ("" = 저장 없음).
static func load_save() -> String:
	var d := peek()
	if d.is_empty():
		return ""
	money = d["money"]
	day = d["day"]
	stock = d["stock"]
	upgrades = {}
	for u in d["upgrades"]:
		upgrades[u] = true
	stars_total = d["stars_total"]
	history = d["history"]
	streak = d.get("streak", 0)
	ledger = d["ledger"]
	order_index = d["order_index"]
	used = d.get("used", [])
	bought = d.get("bought", {})
	dex = d.get("dex", {})
	stats = d.get("stats", {})
	achv = d.get("achv", {})
	visits = d.get("visits", {})
	shelf = d.get("shelf", [])
	my_desk = d.get("my_desk", {})
	mine = false
	reset_order()
	if d["order"] != null:
		cart = d["order"]["cart"]
		unpack(d["order"])
		order_mod = d["order"].get("mod", {})
	return d["mode"]


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


const CAT_LABEL := {"screen": "화면", "input": "키보드 · 마우스", "light": "조명", "audio": "오디오", "plant": "식물", "decor": "소품", "wall": "벽 장식"}


static func _name(i: String) -> String:
	return "모니터" if i == "monitor" else DB.ITEMS[i]["name"]


## 첫 글자만 보이고 나머지는 ○ (띄어쓰기는 그대로): "북쉘프 스피커" → "북○○ ○○○"
static func mask(s: String) -> String:
	var out := s.left(1)
	for ch in s.substr(1):
		out += ch if ch == " " else "○"
	return out


## 꼭 필요한 소품: 처음엔 종류 + 첫 글자만 → 책상에 맞는 걸 놓으면 ✓ 이름 공개 (손님 말로 짐작하는 재미)
static func need_text(req: Dictionary) -> String:
	var ids := placed.map(func(p): return p["id"])
	var parts := []
	for r in req.get("required", []):
		var hit: Array = ids.filter(func(i): return i in r["any"] or ("monitor" in r["any"] and Rules.is_monitor(i)))
		var first: String = r["any"][0]
		var cat: String = CAT_LABEL.get(DB.ITEMS[first]["cat"], "소품") if first != "monitor" else "화면"
		if hit.size() >= r["count"]:
			parts.append("✓ " + _name(hit[0]))
		elif r.get("named", false):   # 전화로 추가된 건 이름을 말해 줌
			parts.append(_name(first))
		else:
			parts.append("%s %d개 (%s %s)" % [cat, r["count"], "예:" if r["any"].size() > 1 else "힌트:", mask(_name(first))])   # 예) 조명 1개 (예: 따OO OOO)
	return " · ".join(parts)


## 싫어하는 것: 처음엔 종류만, 책상에 놓아 버리면 그 이름이 드러남
static func dislike_text(req: Dictionary) -> String:
	var bad: Array = placed.map(func(p): return p["id"]).filter(func(i): return i in req.get("forbidden", []))
	if not bad.is_empty():
		return "✗ " + ", ".join(bad.map(func(i): return _name(i))) + " (싫어해요!)"
	var cats := {}
	for i in req.get("forbidden", []):
		cats[CAT_LABEL.get(DB.ITEMS[i]["cat"], "소품")] = true
	return "" if cats.is_empty() else "싫어하는 %s 종류가 있대요" % " · ".join(cats.keys())
