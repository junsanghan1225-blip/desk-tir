class_name Game
## 게임 진행 상태 (state.py + save_game.py 이식).
## 가게(여러 날 유지): 돈 · 날짜 · 창고 · 업그레이드 · 별 · 단골 기록 · 오늘 장부. 주문(손님 한 명 동안): 장바구니 · 배치 · PC · 케이블.

const START_MONEY := 200
const LEVELS := [0, 3, 9, 17, 27]     # 가게 레벨 n이 되려면 필요한 누적 별
const TIP_RATE := [5, 6, 8, 10, 12]   # 레벨별 별 1개당 팁 (예산의 %)
const SAVE_PATH := "user://save.json"

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
const DAILY := [["별 3개 2번 받기", 20, "three"], ["오늘 마진 합계 80만 이상", 20, "margin"], ["중고 부품 2개 이상 써서 납품", 15, "used"],
	["수리 의뢰를 별 3개로", 20, "repair3"], ["모든 손님에게 별 2개 이상", 25, "all2"]]

static var cart := {}
static var placed := []
static var pc := PCBuild.new()
static var cables := []
static var power := false   # 책상에서 PC 전원을 켰는지 (조립을 바꾸면 꺼짐)
static var power_t := 0     # 켠 시각 (부팅 화면 → 바탕화면)


static func new_game() -> void:
	money = START_MONEY
	day = 1
	stock = {}
	upgrades = {}
	stars_total = 0
	history = {}
	used = []
	dex = {}
	stats = {}
	achv = {}
	visits = {}
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


static func request() -> Dictionary:
	return todays_requests()[order_index]


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
	if rep.is_empty() and request().has("own_pc"):   # 데스크테리어 의뢰: 손님이 쓰던 PC가 이미 있음
		rep = {"pc": request()["own_pc"], "break": []}
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
	s += 1 if u.get("stream", false) or u.get("fps", 0) >= 240 or u.get("res", "") != "1080p" and u.has("res") else 0
	return clampi(s, 1, 3)


## 오늘의 중고 장터 매물 6개 (날짜로 정해짐). 가끔은 아예 고장 난 물건(dead)도 섞여 있다. 판매자 말(claim)로 값이 정해지고, 진짜 상태(cond)는 꽂고 테스트해야 안다.
static func offers() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 7919 + 13
	var out := []
	for k in 6:
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
	if cart.is_empty() or total > money:
		return {}
	money -= total
	var receipt := cart.duplicate()
	for id in cart:
		stock[id] = stock.get(id, 0) + cart[id]
	cart.clear()
	return {"items": receipt, "total": total}


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
	if upgrades.has(uid) or up["price"] > money or level() < up["level"]:
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


## 납품 정산: 손님은 예산만큼 내고 별 1개당 팁. 별 0개면 0원. [대금, 팁]
static func settle(result: Dictionary) -> Array:
	var budget: int = request()["budget"]
	var pay: int = budget if result["stars"] > 0 else 0
	var tip: int = result["stars"] * budget * TIP_RATE[level() - 1] / 100
	money += pay + tip
	stars_total += result["stars"]
	history[request()["customer"]] = result["stars"]
	visits[request()["customer"]] = visits.get(request()["customer"], []) + [result["stars"]]
	ledger.append({"customer": request()["customer"], "stars": result["stars"], "pay": pay, "tip": tip, "cost": spent()})
	var b := Bench.run(Bench.parts_of(computer()), request().get("use", {"kind": "office"}))
	var n_used := pc.used.values().filter(func(e): return e["paid"] > 0).size()   # 직접 사 온 중고만
	ledger[-1].merge({"used": n_used, "noise": b.get("noise", 99), "repair": request().has("repair")})
	if result["stars"] > 0:   # 도감 · 업적 기록
		var built := Rules.kind_of(request()) != "desk"   # 데스크테리어는 손님 PC 그대로라 기록 안 함
		for id in (computer().ids() if built else []):
			dex["p:" + id] = true
		for f in request().get("repair", {}).get("break", []):
			dex["f:" + f] = true
		_add("deliver", 1)
		_add("three", 1 if result["stars"] == 3 else 0)
		_add("used", n_used)
		if built and b.get("noise", 99) <= 28:
			stats["silent"] = 1
		if built and b["kind"] == "game" and b["value"] >= 240:
			stats["speed"] = 1
	check_achv()
	return [pay, tip]   # 교체하고 남은 헌 부품은 중고 창고에 남음 (손님이 처분해 달래요)


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
		"margin": return ledger.reduce(func(a, r): return a + r["pay"] + r["tip"] - r["cost"], 0) >= 80
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


# ---------- 저장 · 이어하기 ----------
static func save(mode: String) -> void:
	var oi := order_index
	if mode == "result":  # 정산은 끝났으니 다음 단계부터 이어간다
		var more := oi + 1 < todays_requests().size()
		mode = "request" if more else "day_end"
		oi += 1 if more else 0
	var order = null
	if mode in ["shop", "desk", "build", "wire"]:
		var flat := placed.map(func(p):   # 모니터에 붙은 소품의 host는 번호로
			var q: Dictionary = p.duplicate()
			if q.has("host"):
				q["host"] = placed.find(p["host"])
			return q)
		order = {"cart": cart, "placed": flat, "pc": pc.to_dict(),
			"cables": cables.map(func(c): return {"dev": placed.find(c["dev"]), "type": c["type"], "port": c["port"]})}
	var d := {"mode": mode, "money": money, "day": day, "stock": stock, "upgrades": upgrades.keys(), "stars_total": stars_total,
		"history": history, "ledger": ledger, "order_index": oi, "order": order, "used": used, "bought": bought, "dex": dex, "stats": stats, "achv": achv, "visits": visits}
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
	ledger = d["ledger"]
	order_index = d["order_index"]
	used = d.get("used", [])
	bought = d.get("bought", {})
	dex = d.get("dex", {})
	stats = d.get("stats", {})
	achv = d.get("achv", {})
	visits = d.get("visits", {})
	reset_order()
	if d["order"] != null:
		cart = d["order"]["cart"]
		placed = d["order"]["placed"]
		for p in placed:
			if p.has("host"):
				p["host"] = placed[p["host"]]
		pc = PCBuild.from_dict(d["order"]["pc"])
		cables = d["order"]["cables"].map(func(c): return {"dev": placed[c["dev"]], "type": c["type"], "port": c["port"]})
	return d["mode"]


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
