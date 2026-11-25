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
	start_day()
	reset_order()


static func start_day() -> void:
	ledger = []
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
	var rep: Dictionary = request().get("repair", {})
	if rep.is_empty():
		return PCBuild.new()
	var b := PCBuild.full(rep["pc"])
	for f in rep["break"]:
		match f:
			"paste": b.paste = false
			_: b.cables.erase(f)   # 선 빠짐 (cpu8 · 24pin · pcie0 …)
	return b


## 손님이 가져온 부품 id -> 개수 (값을 안 받음)
static func lent() -> Dictionary:
	var out := {}
	if request().has("repair"):
		for id in PCBuild.full(request()["repair"]["pc"]).ids():
			out[id] = out.get(id, 0) + 1
	return out


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
	var free := lent()
	for id in pc.ids():
		if free.get(id, 0) > 0:
			free[id] -= 1
		else:
			total += price_of(id)
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
	ledger.append({"customer": request()["customer"], "stars": result["stars"], "pay": pay, "tip": tip, "cost": spent()})
	var left := lent()   # 교체하고 남은 손님 헌 부품은 손님이 도로 가져감
	for id in pc.ids():
		if left.get(id, 0) > 0:
			left[id] -= 1
	for id in left:
		stock[id] = max(0, stock.get(id, 0) - left[id])
	return [pay, tip]


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
		"history": history, "ledger": ledger, "order_index": oi, "order": order}
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
