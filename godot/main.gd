class_name Main
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
const BTN_MUTE := [1232, 676, 1274, 714]   # 위쪽 바 오른쪽 끝 (폰엔 M 키가 없어서)
var muted := false
var players: Array[AudioStreamPlayer] = []
var sounds := {}
var bgm := AudioStreamPlayer.new()


func _ready() -> void:
	var screens = load("res://godot/screens.gd")
	for n in SCREENS:
		modes[n] = screens.get(SCREENS[n]).new()
	for n in ["shop", "desk", "build", "wire"]:
		modes[n] = load("res://godot/%s.gd" % n).new()
	for n in modes:
		modes[n].m = self
	for i in 6:   # 효과음이 겹쳐도 끊기지 않게
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	add_child(bgm)
	bgm.stream = load("res://resource/sfx/bgm.wav")
	bgm.volume_db = -9.0
	bgm.finished.connect(bgm.play)   # 반복
	bgm.play()
	go("title")


## 효과음 (resource/sfx/<이름>.wav). 파일이 없으면 조용히 넘어간다.
func sfx(n: String) -> void:
	if muted:
		return
	if not sounds.has(n):
		sounds[n] = load("res://resource/sfx/%s.wav" % n) if ResourceLoader.exists("res://resource/sfx/%s.wav" % n) else null
	if sounds[n] == null:
		return
	var free := players.filter(func(p): return not p.playing)
	var p: AudioStreamPlayer = free[0] if not free.is_empty() else players[0]
	p.stream = sounds[n]
	p.volume_db = -3.0
	p.play()


func toggle_mute() -> void:
	muted = not muted
	bgm.stream_paused = muted


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
	var t: Mode = stack[-1]
	t.frame("ui_button", BTN_MUTE, Color8(80, 66, 140))
	t.text(BTN_MUTE[0] + 10, 697, "♪" if not muted else "×", 18, Mode.CYAN if not muted else Mode.PINK)


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_M:
		toggle_mute()
	if ev is InputEventMouse:
		var p: Vector2 = make_input_local(ev).position
		mouse = Vector2(p.x, H - p.y)
	if ev is InputEventMouseButton:
		if ev.pressed and Rules.inside(mouse.x, mouse.y, BTN_MUTE):
			toggle_mute()
		elif ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			top().down(mouse.x, mouse.y, ev.button_index == MOUSE_BUTTON_RIGHT or ev.double_click)
		elif not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			top().up(mouse.x, mouse.y)
