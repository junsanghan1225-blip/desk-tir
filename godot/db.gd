class_name DB
## data/*.json 과 resource/*.png 를 읽는다 (pico2d 버전과 같은 파일).

const THEME_NAMES := {"cozy": "아늑", "focus": "집중", "gamer": "게이머", "minimal": "미니멀", "plant": "플랜테리어"}
static var ITEMS := {}
static var PARTS := {}
static var REQUESTS := []
static var UPGRADES := {}
static var DAYS := {}
static var _tex := {}


static func _static_init() -> void:
	for it in _load("items"):
		ITEMS[it["id"]] = it
	for p in _load("parts"):
		PARTS[p["id"]] = p
	REQUESTS = _load("requests")
	for u in _load("upgrades"):
		UPGRADES[u["id"]] = u
	for d in _load("days"):
		DAYS[d["day"]] = d


static func _load(name: String):
	return ints(load("res://data/%s.json" % name).data)


## JSON 숫자는 전부 실수로 읽히므로, 소수점 없는 값은 정수로 되돌린다 (가격이 "25.0만"으로 찍히지 않게).
static func ints(v):
	if v is float and v == floor(v):
		return int(v)
	if v is Array:
		for i in v.size():
			v[i] = ints(v[i])
	elif v is Dictionary:
		for k in v:
			v[k] = ints(v[k])
	return v


static func spec(id: String) -> Dictionary:
	return ITEMS[id] if ITEMS.has(id) else PARTS[id]


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://resource/%s.png" % name)
	return _tex[name]


static func size_of(name: String) -> Vector2i:
	return Vector2i(tex(name).get_size())
