"""영업 마감: 오늘 손님별 별점 · 받은 돈 · 마진, 가게 레벨(누적 별), 가게 업그레이드 구매. 마지막 날이면 결과 후 타이틀로."""
from pico2d import *

import game_framework
import request_mode
import ui
import title_mode
import state
from common import WIDTH, HEIGHT, UPGRADES, box, outline, text, inside

BTN_NEXT = (900, 30, 1240, 76)
toast = ''


def up_rect(i):
    x = 120 + i * 420
    return x, 110, x + 400, 200


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
        state.start_day()
        game_framework.change_mode(request_mode)


def handle_event(e):
    global toast
    if e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        next_mode()
    if e.type != SDL_MOUSEBUTTONDOWN:
        return
    x, y = game_framework.mouse
    if inside(x, y, BTN_NEXT):
        next_mode()
        return
    for i, uid in enumerate(UPGRADES):
        if inside(x, y, up_rect(i)):
            up = UPGRADES[uid]
            if uid in state.upgrades:
                toast = '이미 들여놨어요'
            elif state.level() < up['level']:
                toast = f"가게 레벨 {up['level']}부터 살 수 있어요"
            elif not state.buy_upgrade(uid):
                toast = '돈이 부족해요'
            else:
                toast = f"{up['name']} 완료! 내일부터 쇼핑몰에 새 상품이 들어와요"


def update():
    pass


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    text(120, 670, f"{state.day}일차 영업 마감", 34, (255, 77, 141))
    # 가게 레벨
    lv, need = state.level(), state.next_level_stars()
    prev = state.LEVELS[lv - 1]
    text(700, 680, f"가게 레벨 {lv}", 22, (46, 230, 214))
    box(700, 640, 1160, 660, (50, 38, 96))
    if need:
        box(700, 640, 700 + int(460 * (state.stars_total - prev) / (need - prev)), 660, (46, 230, 214))
        text(700, 622, f"별 {state.stars_total} / {need}  ·  팁 {state.TIP_RATE[lv - 1]}% → {state.TIP_RATE[lv]}%", 14, (170, 160, 220))
    else:
        box(700, 640, 1160, 660, (46, 230, 214))
        text(700, 622, f"최고 레벨 · 팁 {state.TIP_RATE[lv - 1]}%", 14, (170, 160, 220))
    # 장부
    box(120, 250, 1160, 600, (34, 24, 70))
    outline(120, 250, 1160, 600)
    for x, h in [(160, '손님'), (500, '별점'), (650, '받은 돈'), (820, '물건 값'), (990, '마진')]:
        text(x, 570, h, 17, (170, 160, 220))
    for i, row in enumerate(state.ledger):
        y = 520 - i * 52
        text(160, y, row['customer'], 20)
        text(500, y, '★' * row['stars'] + '☆' * (3 - row['stars']), 20, (255, 214, 92))
        text(650, y, f"{row['pay'] + row['tip']}만", 20)
        text(820, y, f"{row['cost']}만", 20, (200, 192, 240))
        m = row['pay'] + row['tip'] - row['cost']
        text(990, y, f"{m:+}만", 20, (120, 255, 170) if m >= 0 else (255, 77, 141))
    total = sum(r['pay'] + r['tip'] - r['cost'] for r in state.ledger)
    text(160, 285, f"오늘 마진 {total:+}만 원   ·   가게 돈 {state.money}만 원", 22, (46, 230, 214))
    # 업그레이드
    text(120, 222, '가게 업그레이드', 18, (255, 77, 141))
    for i, uid in enumerate(UPGRADES):
        up = UPGRADES[uid]
        x1, y1, x2, y2 = up_rect(i)
        owned = uid in state.upgrades
        locked = state.level() < up['level']
        box(x1, y1, x2, y2, (124, 92, 255) if owned else (34, 24, 70))
        outline(x1, y1, x2, y2, (90, 78, 130) if locked else (124, 92, 255))
        text(x1 + 14, y2 - 22, up['name'], 17, (90, 78, 130) if locked else (232, 226, 255))
        status = '보유 중' if owned else (f"레벨 {up['level']} 필요" if locked else f"{up['price']}만 원 · 클릭해서 구매")
        text(x1 + 14, y2 - 48, status, 14, (255, 214, 92))
        text(x1 + 14, y2 - 74, up['desc'][:30], 12, (170, 160, 220))
    if toast:
        text(120, 60, toast, 16, (255, 77, 141))
    last = state.day >= state.LAST_DAY
    ui.button(BTN_NEXT, '타이틀로 [Enter]' if last else '다음 날 영업 [Enter]', (255, 77, 141))
