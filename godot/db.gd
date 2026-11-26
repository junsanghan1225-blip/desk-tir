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
	"monitor": "mon_24", "monitor_22": "mon_24", "monitor_144": "mon_24",
	"monitor_27": "mon_27", "monitor_qhd165": "mon_27", "monitor_240": "mon_27",
	"monitor_oled": "mon_27", "monitor_4k": "mon_27", "monitor_curve": "mon_curved",
	"keyboard": "kb_office", "gaming_kb": "kb_gaming", "mouse_gaming": "mouse_gaming",
	"headset": "headset", "speaker": "speaker_book", "lamp_warm": "lamp_warm",
	"monitor_bar": "light_bar", "mug": "mug",
	"book": "book_stand", "hanging_plant": "plant_hang", "lucky_cat": "cat_lucky",
	"mini_plant": "plant_mini",
}
const PX_TYPE := {"CPU": "cpu", "MB": "mb_atx", "RAM": "ram", "SSD": "ssd_m2", "PSU": "psu"}   # 종류 전체가 한 그림


## 아이콘 그림 이름: PixelLab 그림(또는 같은 화풍으로 바꾼 그림)이 있으면 "pixellab/<id>", 없으면 ""
static func px(id: String) -> String:
	var pid: String = PX.get(id, "")
	if pid == "" or not _px_has(pid):   # 대응표 → 같은 이름 파일(같은 화풍으로 바꾼 것) → 종류 공통 그림
		pid = id if _px_has(id) else PX_TYPE.get(PARTS[id]["type"], "") if PARTS.has(id) else ""
	return "pixellab/" + pid if pid != "" and _px_has(pid) else ""


static func _px_has(pid: String) -> bool:
	return ResourceLoader.exists("res://resource/pixellab/%s.png" % pid)


static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		var real := "res://resource/real/%s.png" % name   # 실제 비율 정면 그림이 있으면 그걸로 (pico2d는 원래 그림)
		_tex[name] = load(real if ResourceLoader.exists(real) else "res://resource/%s.png" % name)
		if name.begins_with("pixellab/"):   # 128px 캔버스의 투명 여백을 잘라 다른 아이콘처럼 칸을 채우게
			var at := AtlasTexture.new()
			at.atlas = _tex[name]
			at.region = Rect2(_tex[name].get_image().get_used_rect())
			_tex[name] = at
	return _tex[name]


## 그림이 따로 없는 확장 부품은 비슷한 부품 그림을 빌려 씀 (parts.json "look")
static func look(id: String) -> String:
	return PARTS[id].get("look", id) if PARTS.has(id) else id


static func size_of(name: String) -> Vector2i:
	return Vector2i(tex(name).get_size())
