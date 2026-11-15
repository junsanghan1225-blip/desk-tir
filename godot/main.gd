extends Control
## 화면(모드) 스택 · 입력 분배 · 자동 저장. 각 화면은 godot/*.gd 의 Mode.
## 터치는 마우스로 들어온다 (Godot 기본: 터치 → 마우스 에뮬레이션). 더블탭 = 우클릭(빼기).

const H := 720
const SCREENS := {"title": "Title", "news": "News", "request": "Request", "result": "Result", "day_end": "DayEnd", "product": "Product", "receipt": "Receipt"}
const SAVED := ["news", "request", "shop", "desk", "build", "wire", "result", "day_end"]

var font: Font = load("res://resource/font.ttf")
var modes := {}
var stack: Array = []
var mouse := Vector2.ZERO   # 게임 좌표 (y 위쪽)


func _ready() -> void:
	var screens = load("res://godot/screens.gd")
	for n in SCREENS:
		modes[n] = screens.get(SCREENS[n]).new()
	for n in ["shop", "desk", "build", "wire"]:
		modes[n] = load("res://godot/%s.gd" % n).new()
	for n in modes:
		modes[n].m = self
	go("title")


func top() -> Mode:
	return stack[-1]


## 화면 바꾸기 (자동 저장)
func go(n: String) -> void:
	stack = [modes[n]]
	top().enter()
	if n in SAVED:
		Game.save(n)


## 겹쳐 띄우기 (상품 상세 · 영수증)
func push(n: String) -> void:
	stack.append(modes[n])


func pop() -> void:
	stack.pop_back()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var base := stack.size() - 1
	while base > 0 and stack[base].overlay:
		base -= 1
	for i in range(base, stack.size()):
		stack[i].draw()


func _input(ev: InputEvent) -> void:
	if ev is InputEventMouse:
		var p: Vector2 = make_input_local(ev).position
		mouse = Vector2(p.x, H - p.y)
	if ev is InputEventMouseButton:
		if ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			top().down(mouse.x, mouse.y, ev.button_index == MOUSE_BUTTON_RIGHT or ev.double_click)
		elif not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			top().up(mouse.x, mouse.y)
