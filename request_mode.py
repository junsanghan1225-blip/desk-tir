"""손님 등장: 애매한 주문만 말한다. 테마 · 필수 · 성능은 숨겨져 있고, 말에서 읽어 내야 한다."""
from pico2d import *

import game_framework
import decorate_mode
import state
from common import WIDTH, HEIGHT, box, outline, text


def init():
    state.reset_order()


def finish():
    pass


def handle_events():
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
            game_framework.change_mode(decorate_mode)


def update():
    pass


def draw():
    req = state.request()
    clear_canvas()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    n = len(state.todays_requests())
    text(80, 650, f"{state.day}일차  ·  손님 {state.order_index + 1}/{n}", 20, (46, 230, 214))
    box(80, 300, 360, 600, (34, 24, 70))   # 손님 초상화 자리 (AI 생성 캐릭터로 교체 예정)
    outline(80, 300, 360, 600)
    text(150, 450, '손님 그림', 18, (90, 78, 130))
    text(80, 260, req['customer'], 30)
    box(420, 330, 1200, 600, (34, 24, 70))  # 말풍선
    outline(420, 330, 1200, 600, (255, 77, 141))
    for i, line in enumerate(req['lines']):
        text(460, 550 - i * 56, f"\"{line}\"" if i == 0 else line, 24)
    text(460, 380, f"예산은 {req['budget']}만 원 정도 생각하고 있어요.", 20, (255, 214, 92))
    text(420, 200, '무엇을 원하는지 말 속에서 찾아보세요.', 18, (170, 160, 220))
    text(420, 120, '클릭해서 주문 받기', 18, (140, 128, 200))
    update_canvas()
