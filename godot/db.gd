class_name DB
## data/*.json 과 resource/*.png 를 읽는다 (pico2d 버전과 같은 파일).

const THEME_NAMES := {"cozy": "아늑", "focus": "집중", "gamer": "게이머", "minimal": "미니멀", "plant": "플랜테리어"}
static var ITEMS := {}
static var PARTS := {}
static var REQUESTS := []
static var UPGRADES := {}
static var DAYS := {}
static var STORY := {}   # 큰 목표 · 시작 이야기 · 손님별 뒷이야기 (Godot 판)
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
	STORY = _load("story")


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


## 상점 · 재고 아이콘용 PixelLab 그림 (resource/pixellab/<값>.png). 없는 id는 기존 그림 그대로.
const PX := {
	"gpu1": "gpu_low", "gpu7": "gpu_low", "gpu4": "gpu_low",
	"gpu2": "gpu_mid", "gpu8": "gpu_mid", "gpu5": "gpu_mid",
	"gpu3": "gpu_high", "gpu9": "gpu_high", "gpu6": "gpu_high",
	"cool1": "cooler_stock", "cool4": "cooler_stock",
	"cool2": "cooler_tower", "cool5": "cooler_tower", "cool6": "cooler_tower",
	"cool3": "cooler_aio", "cool7": "cooler_aio",
	"ram4": "ram_rgb", "ram7": "ram_rgb", "ssd4": "ssd_sata",
	"case1": "case_mid", "case6": "case_mid", "case8": "case_mid",
	"case2": "case_white", "case3": "case_rgb", "case7": "case_rgb",
	# 모니터는 화면 위치(desk.gd SCREEN)가 원래 그림 기준이라 PixelLab 그림 대신 같은 화풍으로 바꾼 원래 그림
	"keyboard": "kb_office", "gaming_kb": "kb_gaming", "mouse_gaming": "mouse_gaming",
	"headset": "headset", "speaker": "speaker_book", "lamp_warm": "lamp_warm",
	"monitor_bar": "light_bar", "mug": "mug",
	"book": "book_stand", "hanging_plant": "plant_hang", "lucky_cat": "cat_lucky",
	"mini_plant": "plant_mini",
}
const PX_TYPE := {"CPU": "cpu", "MB": "mb_atx", "RAM": "ram", "SSD": "ssd_m2", "PSU": "psu"}   # 종류 전체가 한 그림


## 부품 아이콘: PixelLab 그림 → 같은 화풍으로 바꾼 그림(styled/) → "" (기존 그림)
static func px(id: String) -> String:
	var pid: String = PX.get(id, PX_TYPE.get(PARTS[id]["type"], "") if PARTS.has(id) else "")
	if pid != "" and _has("pixellab/" + pid):
		return "pixellab/" + pid
	return "styled/" + id if _has("styled/" + id) else ""


static var _skin := {}


## 소품 그림(id 또는 id__c색)을 쇼핑 아이콘 · 책상 배치 · 창고 어디서나 같은 그림으로 바꿔 줌.
## PixelLab 그림은 색 바꾸기가 없고 비율이 책상 그림과 비슷할 때만, 아니면 같은 화풍으로 바꾼 원래 그림(styled/).
static func skin(name: String) -> String:
	if not _skin.has(name):
		var id := name.get_slice("__", 0)
		var s := name
		if ITEMS.has(id):
			var pid: String = PX.get(id, id)
			if name == id and not _has(id + "__c1") and _has("pixellab/" + pid) and _ratio_ok(id, "pixellab/" + pid):
				s = "pixellab/" + pid
			elif _has("styled/" + name):
				s = "styled/" + name
		_skin[name] = s
	return _skin[name]


static func _ratio_ok(id: String, art: String) -> bool:   # 가로세로 비율 차이 1.5배 안쪽
	var a := size_of(id)
	var b := tex(art).get_size()
	var r := (float(a.x) / a.y) / (b.x / b.y)
	return r < 1.5 and r > 1 / 1.5


static func _has(name: String) -> bool:
	return ResourceLoader.exists("res://resource/real/%s.png" % name) or ResourceLoader.exists("res://resource/%s.png" % name)


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var real := "res://resource/real/%s.png" % name   # 실제 비율 정면 그림이 있으면 그걸로 (pico2d는 원래 그림)
		_tex[name] = load(real if ResourceLoader.exists(real) else "res://resource/%s.png" % name)
		if name.begins_with("pixellab/") or name.begins_with("styled/"):   # 투명 여백을 잘라 다른 아이콘처럼 칸을 채우게
			var at := AtlasTexture.new()
			at.atlas = _tex[name]
			at.region = Rect2(_tex[name].get_image().get_used_rect())
			_tex[name] = at
	return _tex[name]


## 그림이 따로 없는 확장 부품은 비슷한 부품 그림을 빌려 씀 (parts.json "look")
static func look(id: String) -> String:
	return PARTS[id].get("look", id) if PARTS.has(id) else id


## 소품은 실제 비율 그림(5.5px/cm)을 책상 축척(Rules.UNIT)에 맞춰 줄인 크기
static func size_of(name: String) -> Vector2i:
	var s := tex(name).get_size()
	return Vector2i((s * Rules.UNIT / 5.5).round()) if ITEMS.has(name.get_slice("__", 0)) else Vector2i(s)
