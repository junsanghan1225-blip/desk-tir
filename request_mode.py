"""손님 등장: 애매한 주문만 말한다. 테마 · 필수 · 성능은 숨겨져 있고, 말에서 읽어 내야 한다.
다시 온 단골은 지난번 별점에 따라 표정과 첫마디가 달라진다."""
from pico2d import *

import game_framework
import shop_mode
import sound
import state
from common import WIDTH, HEIGHT, box, outline, text, sprite


def init():
    state.reset_order()
    sound.play('door')


def finish():
    pass


def handle_event(e):
    if e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
        game_framework.change_mode(shop_mode)


def update():
    pass


def mood():
    req = state.request()
    if not req.get('returns'):
        return 'neutral'
    return 'happy' if state.history.get(req['customer'], 0) >= 2 else 'sad'


def draw():
    req = state.request()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    n = len(state.todays_requests())
    text(80, 650, f"{state.day}일차  ·  손님 {state.order_index + 1}/{n}", 20, (46, 230, 214))
    sprite(f"face_{req['face']}_{mood()}").draw(220, 450)
    outline(80, 300, 360, 600, (255, 77, 141))
    text(80, 260, req['customer'], 30)
    if req.get('returns'):
        box(80, 206, 190, 236, (255, 214, 92))
        text(92, 221, '단골 손님', 15, (18, 12, 38))
    box(420, 330, 1200, 600, (34, 24, 70))  # 말풍선
    outline(420, 330, 1200, 600, (255, 77, 141))
    for i, line in enumerate(state.lines()):
        text(460, 550 - i * 56, f"\"{line}\"" if i == 0 else line, 24)
    text(460, 380, f"예산은 {req['budget']}만 원 정도 생각하고 있어요.", 20, (255, 214, 92))
    text(420, 200, '무엇을 원하는지 말 속에서 찾아보세요.', 18, (170, 160, 220))
    text(420, 120, '클릭해서 주문 받기 → 쇼핑으로', 18, (140, 128, 200))
