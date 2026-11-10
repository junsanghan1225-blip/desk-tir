"""납품 결과: 별점 · 점수 내역 · 손님 반응 · 받은 돈, 그리고 손님이 사실 원했던 것을 공개."""
from pico2d import *

import game_framework
import request_mode
import day_end_mode
import scorer
import cables
import state
from common import WIDTH, HEIGHT, ITEMS, PARTS, THEME_NAMES, box, outline, text

result = None
pay = tip = cost = 0
wanted = []


def init():
    global result, pay, tip, wanted, cost
    state.cables = cables.prune(state.cables, state.room, state.pc)
    req = state.request()
    cost = state.spent()
    result = scorer.score(req, state.room, state.pc, state.cables)
    pay, tip = state.settle(result)
    wanted = reveal(req)


def reveal(req):
    """숨겨져 있던 주문 조건을 말로 풀어 쓴다."""
    lines = ['분위기: ' + ' · '.join(THEME_NAMES[t] for t in req['theme'])]
    for r in req['required']:
        lines.append(f"꼭 필요: {'/'.join(ITEMS[i]['name'] for i in r['any'])} {r['count']}개")
    if req['forbidden']:
        lines.append('싫어함: ' + ', '.join(ITEMS[i]['name'] for i in req['forbidden']))
    lines.append('PC 성능: ' + '★' * req['perf'] + ' 이상')
    return lines


def finish():
    pass


def next_mode():
    if state.next_customer():
        game_framework.change_mode(request_mode)
    else:
        game_framework.change_mode(day_end_mode)


def handle_event(e):
    if e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
        next_mode()


def update():
    pass


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    stars = '★' * result['stars'] + '☆' * (3 - result['stars'])
    text(120, 640, state.request()['customer'], 24, (200, 192, 240))
    text(120, 575, stars, 60, (255, 214, 92))
    text(420, 575, f"{result['total']}점", 48, (255, 255, 255))
    for i, (k, v) in enumerate(result['parts'].items()):
        y = 490 - i * 40
        text(120, y, k, 19, (200, 192, 240))
        text(320, y, f"{v:.0f} / {scorer.MAX[k]}", 19, (255, 255, 255))
    syn = ', '.join(result['synergies']) or '없음'
    text(120, 220, f"달성 시너지: {syn}", 17, (120, 255, 170))
    note = '  (별 0개: 절반만 냄)' if not result['stars'] else ''
    text(120, 180, f"받은 돈  {pay}만 + 팁 {tip}만" + note, 20, (46, 230, 214))
    margin = pay + tip - cost
    text(120, 148, f"물건 값 {cost}만  →  이번 주문 마진 {margin:+}만", 18, (120, 255, 170) if margin >= 0 else (255, 77, 141))

    box(640, 470, 1180, 610, (34, 24, 70))
    outline(640, 470, 1180, 610, (255, 77, 141))
    text(665, 540, f"\"{result['line']}\"", 19)
    text(640, 430, '손님이 사실 원했던 것', 18, (255, 77, 141))
    for i, line in enumerate(wanted):
        text(640, 395 - i * 34, line, 17, (232, 226, 255))
    text(120, 100, '클릭해서 다음 손님 받기' if state.order_index + 1 < len(state.todays_requests()) else '클릭해서 영업 마감',
         18, (140, 128, 200))
