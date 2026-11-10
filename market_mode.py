"""아침 시장: 오늘 올 손님을 모른 채 재고를 사고, 가게 업그레이드를 산다. (좋은 피자, 위대한 피자의 재료 구매)
좌클릭 +1 구매 · 우클릭 -1 되팔기(같은 값)."""
from pico2d import *

import game_framework
import request_mode
import state
import ui
from common import WIDTH, HEIGHT, ITEMS, PARTS, UPGRADES, box, outline, text, to_canvas_y, inside, draw_fit, wholesale

COLS = [(30, 'ITEMS'), (440, 'PARTS')]
ROW_H, ROW_TOP, ROW_W = 30, 606, 390
UP_X = 850
BTN_OPEN = (1060, 14, 1260, 58)
TYPE_NAMES = {'CPU': 'CPU', 'GPU': '그래픽카드', 'RAM': 'RAM', 'PSU': '파워', 'CASE': '케이스'}
toast = ''


def init():
    global toast
    toast = '오늘 어떤 손님이 올지 몰라요. 넉넉히, 하지만 돈은 아껴서!'


def finish():
    pass


def rows():
    """(id, rect) — 왼쪽 열 소품, 가운데 열 부품."""
    for (x, kind) in COLS:
        ids = list(ITEMS) if kind == 'ITEMS' else list(PARTS)
        for i, tid in enumerate(ids):
            y = ROW_TOP - i * ROW_H
            yield tid, (x, y - ROW_H + 3, x + ROW_W, y)


def up_rect(i):
    y = 560 - i * 150
    return UP_X, y - 130, UP_X + 400, y


def on_click(x, y, button):
    global toast
    if inside(x, y, BTN_OPEN):
        state.start_day()
        game_framework.change_mode(request_mode)
        return
    for i, uid in enumerate(UPGRADES):
        if inside(x, y, up_rect(i)) and button == SDL_BUTTON_LEFT:
            if uid in state.upgrades:
                toast = '이미 들여놨어요'
            elif state.buy_upgrade(uid):
                toast = f"{UPGRADES[uid]['name']} 완료!"
            else:
                toast = '돈이 부족해요'
            return
    for tid, rect in rows():
        if inside(x, y, rect):
            if tid not in state.catalog():
                toast = '오른쪽 업그레이드를 사면 들여올 수 있어요'
            elif not state.buy(tid, 1 if button == SDL_BUTTON_LEFT else -1):
                toast = '돈이 부족해요' if button == SDL_BUTTON_LEFT else '팔 재고가 없어요'
            else:
                toast = ''
            return


def handle_events():
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
            on_click(*BTN_OPEN[:2], SDL_BUTTON_LEFT)
        elif e.type == SDL_MOUSEBUTTONDOWN:
            on_click(e.x, to_canvas_y(e.y), e.button)


def update():
    pass


def name_of(tid):
    if tid in ITEMS:
        return ITEMS[tid]['name']
    return PARTS[tid]['name']


def draw():
    clear_canvas()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    ui.shop_bar('아침 시장')
    text(30, 630, '소품  (좌클릭 구매 · 우클릭 되팔기)', 16, ui.QUIET)
    text(440, 630, 'PC 부품', 16, ui.QUIET)
    open_ = set(state.catalog())
    for tid, (x1, y1, x2, y2) in rows():
        locked = tid not in open_
        have = state.stock.get(tid, 0)
        thing = ITEMS.get(tid) or PARTS[tid]
        box(x1, y1, x2, y2, (34, 24, 70) if have else (24, 16, 52))
        icon = tid if tid in ITEMS or thing['type'] == 'CASE' else 'part_' + thing['type']
        draw_fit(icon, x1 + 16, (y1 + y2) // 2, 26, 24)
        ink = (90, 78, 130) if locked else (232, 226, 255)
        text(x1 + 36, (y1 + y2) // 2, name_of(tid), 14, ink)
        price = '잠김' if locked else f"{wholesale(thing['price'])}만"
        text(x2 - 150, (y1 + y2) // 2, price, 13, (90, 78, 130) if locked else ui.QUIET)
        if have:
            text(x2 - 70, (y1 + y2) // 2, f"x {have}", 15, ui.AMBER)
    text(UP_X, 600, '가게 업그레이드', 18, ui.PINK)
    for i, uid in enumerate(UPGRADES):
        up = UPGRADES[uid]
        x1, y1, x2, y2 = up_rect(i)
        owned = uid in state.upgrades
        box(x1, y1, x2, y2, (124, 92, 255) if owned else (34, 24, 70))
        outline(x1, y1, x2, y2)
        text(x1 + 16, y2 - 26, up['name'], 18)
        text(x1 + 16, y2 - 56, '보유 중' if owned else f"{up['price']}만 원", 16, ui.AMBER)
        words = up['desc'].split(' · ')
        half = (len(words) + 1) // 2
        text(x1 + 16, y2 - 86, ' · '.join(words[:half]), 13, ui.QUIET)
        text(x1 + 16, y2 - 106, ' · '.join(words[half:]), 13, ui.QUIET)
    text(UP_X, 190, f"오늘 손님 {len(state.todays_requests())}명 예정", 16, ui.QUIET)
    if toast:
        text(30, 36, toast, 16, ui.PINK)
    ui.button(BTN_OPEN, '영업 시작 [Enter]', ui.PINK)
    update_canvas()
