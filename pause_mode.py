"""일시정지 메뉴 (ESC). 아래 화면 위에 겹쳐 그리고(OVERLAY), ESC를 다시 누르면 닫힌다.
주문 중이면 손님이 한 말을 다시 보여 준다 (좋은 피자처럼 주문을 다시 확인)."""
from pico2d import *

import game_framework
import state
import ui
from common import WIDTH, HEIGHT, box, outline, text, inside

OVERLAY = True
ESC = 'back'
PANEL = (340, 140, 940, 600)
BUTTONS = [('resume', '계속하기 [ESC]'), ('title', '타이틀로'), ('quit', '게임 종료')]


def btn_rect(i):
    y = 330 - i * 64
    return 440, y - 46, 840, y


def init():
    pass


def finish():
    pass


def in_order():
    """밑에 깔린 화면이 주문 작업 중인지."""
    import shop_mode, decorate_mode, build_mode, wire_mode
    return len(game_framework.stack) > 1 and game_framework.stack[-2] in (shop_mode, decorate_mode, build_mode, wire_mode)


def handle_event(e):
    if e.type != SDL_MOUSEBUTTONDOWN:
        return
    x, y = game_framework.mouse
    for i, (key, _) in enumerate(BUTTONS):
        if inside(x, y, btn_rect(i)):
            if key == 'resume':
                game_framework.pop_mode()
            elif key == 'title':
                import title_mode
                game_framework.pop_mode()
                game_framework.change_mode(title_mode)
            else:
                game_framework.quit()
            return


def update():
    pass


def draw():
    box(0, 0, WIDTH, HEIGHT, (10, 6, 22), 150)
    box(*PANEL, (34, 24, 70))
    outline(*PANEL, (255, 77, 141))
    text(PANEL[0] + 30, PANEL[3] - 40, '일시정지', 28, (255, 77, 141))
    if in_order():
        req = state.request()
        text(PANEL[0] + 30, PANEL[3] - 84, f"{req['customer']}의 주문", 16, ui.QUIET)
        for i, line in enumerate(req['lines']):
            text(PANEL[0] + 30, PANEL[3] - 116 - i * 30, f"\"{line}\"", 17)
        text(PANEL[0] + 30, PANEL[3] - 180, f"예산 {req['budget']}만 원", 16, (255, 214, 92))
    for i, (_, label) in enumerate(BUTTONS):
        ui.button(btn_rect(i), label, ui.PINK if i == 0 else (124, 92, 255))
