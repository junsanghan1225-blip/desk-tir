"""영업 마감 정산: 오늘 손님별 별점 · 대금 · 팁. 마지막 날이면 결과 후 타이틀로."""
from pico2d import *

import game_framework
import market_mode
import title_mode
import state
from common import WIDTH, HEIGHT, box, outline, text


def init():
    pass


def finish():
    pass


def next_mode():
    if state.day >= state.LAST_DAY:
        title_mode.message = f"영업 {state.LAST_DAY}일 완료! 최종 가게 돈 {state.money}만 원"
        game_framework.change_mode(title_mode)
    else:
        state.day += 1
        game_framework.change_mode(market_mode)


def handle_events():
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
            next_mode()


def update():
    pass


def draw():
    clear_canvas()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    text(120, 640, f"{state.day}일차 영업 마감", 36, (255, 77, 141))
    box(120, 220, 1160, 580, (34, 24, 70))
    outline(120, 220, 1160, 580)
    for x, h in [(160, '손님'), (560, '별점'), (760, '대금'), (940, '팁')]:
        text(x, 545, h, 18, (170, 160, 220))
    for i, row in enumerate(state.ledger):
        y = 490 - i * 56
        text(160, y, row['customer'], 22)
        text(560, y, '★' * row['stars'] + '☆' * (3 - row['stars']), 22, (255, 214, 92))
        text(760, y, f"{row['pay']}만", 22)
        text(940, y, f"+{row['tip']}만", 22, (120, 255, 170))
    total = sum(r['pay'] + r['tip'] for r in state.ledger)
    text(160, 260, f"오늘 번 돈 {total}만 원   ·   가게 돈 {state.money}만 원", 24, (46, 230, 214))
    last = state.day >= state.LAST_DAY
    text(120, 150, '클릭해서 타이틀로' if last else '클릭해서 다음 날 아침 시장으로', 18, (140, 128, 200))
    update_canvas()
