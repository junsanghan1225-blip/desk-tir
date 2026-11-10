"""게임 프레임워크: 모드(화면) 스택 · 이벤트 분배 · 그리기 · 프레임 시간.

모드 = 아래 함수를 가진 모듈.
    init()  finish()             스택에 들어올 때 / 나갈 때
    pause() resume()             (선택) 위에 다른 모드가 덮일 때 / 다시 맨 위가 될 때
    handle_event(e)              이벤트 하나. 마우스 위치는 game_framework.mouse (캔버스 좌표)
    update()                     매 프레임. 지난 프레임 시간은 game_framework.frame_time (초)
    draw()                       그리기만. clear_canvas / update_canvas 는 프레임워크가 한다
모드 속성 (선택)
    OVERLAY = True               아래 모드를 먼저 그리고 그 위에 그린다 (일시정지 메뉴 등)
    ESC = 'pause' | 'quit' | 'back' | None
                                 ESC 키 처리. 기본 'pause' (일시정지 메뉴를 띄움), None 이면 모드가 직접 받는다

화면 전환
    change_mode(m)   맨 위 모드를 m으로 바꾼다 (같은 단계의 화면 이동: 책상 → PC 조립)
    push_mode(m)     m을 위에 쌓는다 (일시정지 메뉴). 아래 모드는 pause()
    pop_mode()       맨 위를 빼고 아래 모드를 resume()
"""
import time

from pico2d import clear_canvas, update_canvas, get_events, SDL_QUIT, SDL_KEYDOWN, SDLK_ESCAPE, \
    SDL_MOUSEMOTION, SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP

FPS = 60
running = True
stack = []
frame_time = 0.0
mouse = (0, 0)
pause_mode = None  # main.py가 연결 (순환 import 방지)
on_change = None   # 화면이 바뀔 때 부를 함수 (자동 저장). main.py가 연결


def top():
    return stack[-1]


def change_mode(mode):
    if stack:
        stack.pop().finish()
    stack.append(mode)
    mode.init()
    if on_change:
        on_change(mode)


def push_mode(mode):
    if stack and hasattr(top(), 'pause'):
        top().pause()
    stack.append(mode)
    mode.init()


def pop_mode():
    stack.pop().finish()
    if stack and hasattr(top(), 'resume'):
        top().resume()


def quit():
    global running
    running = False


def dispatch(e, height):
    """이벤트 하나를 처리: 종료 · ESC · 마우스 좌표 변환은 여기서, 나머지는 맨 위 모드로."""
    global mouse
    if e.type == SDL_QUIT:
        quit()
        return
    if e.type in (SDL_MOUSEMOTION, SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP):
        mouse = (e.x, height - 1 - e.y)
    if e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE:
        rule = getattr(top(), 'ESC', 'pause')
        if rule == 'quit':
            quit()
            return
        if rule == 'back':
            pop_mode()
            return
        if rule == 'pause' and pause_mode:
            push_mode(pause_mode)
            return
    top().handle_event(e)


def render():
    """맨 위부터 내려가며 OVERLAY가 아닌 첫 모드를 찾아, 거기서부터 위로 그린다."""
    clear_canvas()
    base = len(stack) - 1
    while base > 0 and getattr(stack[base], 'OVERLAY', False):
        base -= 1
    for mode in stack[base:]:
        mode.draw()
    update_canvas()


def run(start_mode, height):
    global running, frame_time
    running = True
    stack.append(start_mode)
    start_mode.init()
    last = time.time()
    while running:
        for e in get_events():
            dispatch(e, height)
            if not running:
                break
        if not running:
            break
        top().update()
        render()
        now = time.time()
        spare = 1 / FPS - (now - last)
        if spare > 0:
            time.sleep(spare)
            now = time.time()
        frame_time, last = now - last, now
    if on_change and stack:
        on_change(next((m for m in reversed(stack) if not getattr(m, 'OVERLAY', False)), stack[0]))  # 끌 때 저장
    while stack:
        stack.pop().finish()


if __name__ == '__main__':
    class Fake:
        def __init__(self, name, log, **attrs):
            self.name, self.log = name, log
            self.__dict__.update(attrs)

        def __getattr__(self, n):
            if n in ('init', 'finish', 'pause', 'resume', 'handle_event', 'update', 'draw'):
                return lambda *a: self.log.append(f'{self.name}.{n}')
            raise AttributeError(n)

    class Ev:
        def __init__(self, type, key=0, x=0, y=0):
            self.type, self.key, self.x, self.y = type, key, x, y

    log = []
    a, b = Fake('a', log), Fake('b', log)
    p = Fake('p', log, ESC='back', OVERLAY=True)
    pause_mode = p
    stack.append(a)
    change_mode(b)
    assert stack == [b] and log == ['a.finish', 'b.init']
    log.clear()
    dispatch(Ev(SDL_KEYDOWN, SDLK_ESCAPE), 720)     # ESC → 일시정지가 위에 쌓임
    assert stack == [b, p] and log == ['b.pause', 'p.init']
    dispatch(Ev(SDL_MOUSEMOTION, x=10, y=20), 720)   # 마우스는 캔버스 좌표로 바뀌고 맨 위로 전달
    assert mouse == (10, 699) and log[-1] == 'p.handle_event'
    log.clear()
    import pico2d
    clear_canvas = update_canvas = lambda: None
    render()                                          # 오버레이는 아래 모드부터 그린다
    assert log == ['b.draw', 'p.draw']
    log.clear()
    dispatch(Ev(SDL_KEYDOWN, SDLK_ESCAPE), 720)     # 일시정지에서 ESC → 닫힘
    assert stack == [b] and log == ['p.finish', 'b.resume']
    b.ESC = 'quit'
    dispatch(Ev(SDL_KEYDOWN, SDLK_ESCAPE), 720)
    assert not running
    print('framework ok')
