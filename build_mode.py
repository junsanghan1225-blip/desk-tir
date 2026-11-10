"""PC 조립 화면: 부품 종류마다 하나씩 골라 장착. 소비전력이 파워 용량을 넘으면 부팅 실패."""
from pico2d import *

import game_framework
import decorate_mode
import state
import ui
from common import WIDTH, HEIGHT, PARTS, box, outline, text, to_canvas_y, inside, draw_fit
from scorer import PC_TYPES, pc_stats, boot_status

COL_X0, COL_W, CARD_H = 70, 230, 80
BTN_BACK = (1080, 10, 1270, 50)
TYPE_NAMES = {'CPU': 'CPU', 'GPU': '그래픽카드', 'RAM': 'RAM', 'PSU': '파워', 'CASE': '케이스'}
toast = ''


def init():
    global toast
    toast = ''


def finish():
    pass


def card_rect(t_index, row):
    x = COL_X0 + t_index * COL_W
    y = 540 - row * (CARD_H + 14)
    return x, y - CARD_H, x + COL_W - 20, y


def cards():
    for ti, t in enumerate(PC_TYPES):
        for row, pid in enumerate(p for p in PARTS if PARTS[p]['type'] == t):
            yield pid, card_rect(ti, row)


def on_click(x, y):
    global toast
    if inside(x, y, BTN_BACK):
        game_framework.change_mode(decorate_mode)
        return
    for pid, rect in cards():
        if inside(x, y, rect):
            t = PARTS[pid]['type']
            if state.pc.get(t) == pid:
                state.give_back(state.pc.pop(t))
                return
            old = PARTS[state.pc[t]]['price'] if t in state.pc else 0
            if PARTS[pid]['price'] - old > state.money_left():
                toast = '손님 예산을 넘어요!'
            elif not state.take(pid):
                toast = '재고가 없어요. 아침 시장에서 사 두세요'
            else:
                if t in state.pc:
                    state.give_back(state.pc[t])
                state.pc[t], toast = pid, ''
            return


def handle_events():
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_KEYDOWN and e.key == SDLK_TAB:
            game_framework.change_mode(decorate_mode)
        elif e.type == SDL_MOUSEBUTTONDOWN and e.button == SDL_BUTTON_LEFT:
            on_click(e.x, to_canvas_y(e.y))


def update():
    pass


def describe(p):
    if 'capacity' in p:
        return f"용량 {p['capacity']}W"
    if p['type'] == 'CASE':
        return '외형 · 시너지용'
    dp = f" · DP {p['dp']}" if 'dp' in p else ''
    return f"성능 +{p['perf']} · {p['watt']}W{dp}"


def gauge(y, label, value, max_value, color, caption):
    text(70, y + 12, label, 18)
    box(200, y, 900, y + 24, (50, 38, 96))
    box(200, y, 200 + int(700 * min(1, value / max_value)), y + 24, color)
    text(920, y + 12, caption, 18, color)


def draw():
    clear_canvas()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    ui.top_bar()
    text(70, 610, 'PC 조립  ·  부품을 클릭해서 장착 / 다시 클릭하면 해제', 22)
    for ti, t in enumerate(PC_TYPES):
        text(COL_X0 + ti * COL_W, 565, TYPE_NAMES[t], 20, (255, 77, 141))
    for pid, (x1, y1, x2, y2) in cards():
        p = PARTS[pid]
        on = state.pc.get(p['type']) == pid
        have = state.stock.get(pid, 0)
        box(x1, y1, x2, y2, (124, 92, 255) if on else (34, 24, 70) if have else (24, 16, 52))
        outline(x1, y1, x2, y2)
        draw_fit(pid if p['type'] == 'CASE' else 'part_' + p['type'], x1 + 32, (y1 + y2) // 2, 48, 56)
        text(x1 + 64, y2 - 26, p['name'], 17, (232, 226, 255) if on or have else (90, 78, 130))
        text(x2 - 34, y2 - 26, f"x{have}", 13, (46, 230, 214))
        text(x1 + 64, y2 - 54, f"{p['price']}만 · {describe(p)}", 13, (170, 160, 220))

    perf, watt, cap, stars = pc_stats(state.pc)
    need = state.request()['perf']
    gauge(170, '성능', perf, 22, (46, 230, 214), f"{'★' * stars or '-'}  (요구 {'★' * need})")
    over = watt > cap
    gauge(120, '소비전력', watt, max(cap, 1) if cap else 800, (255, 77, 141) if over else (120, 255, 170),
          f"{watt}W / {cap or '?'}W")
    status = {'ok': '부팅 OK', 'power': '파워 부족! 부팅 실패', 'missing': '부품 5종을 모두 장착하세요'}[boot_status(state.pc)]
    text(70, 70, status, 20, (255, 77, 141) if status != '부팅 OK' else (120, 255, 170))
    if toast:
        text(500, 70, toast, 18, (255, 77, 141))
    ui.button(BTN_BACK, '책상으로 [Tab]')
    update_canvas()
