"""결제 영수증 (쇼핑 화면 위에 겹쳐 뜸). 확인하면 닫힌다. 산 물건은 이미 창고에 들어가 있다."""
from pico2d import *

import game_framework
import state
import ui
from common import WIDTH, HEIGHT, ITEMS, PARTS, box, outline, text, inside

OVERLAY = True
ESC = 'back'
PANEL = (400, 80, 880, 640)
BTN_OK = (540, 100, 740, 146)

lines = {}
total = 0


def show(receipt, paid):
    global lines, total
    lines, total = receipt, paid
    game_framework.push_mode(__import__('receipt_mode'))


def init():
    pass


def finish():
    pass


def handle_event(e):
    if e.type == SDL_MOUSEBUTTONDOWN and inside(*game_framework.mouse, BTN_OK) or e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        game_framework.pop_mode()


def update():
    pass


def draw():
    box(0, 0, WIDTH, HEIGHT, (10, 6, 22), 160)
    box(*PANEL, (245, 242, 255))
    ink, quiet = (30, 24, 50), (110, 100, 140)
    text(PANEL[0] + 30, PANEL[3] - 40, '데스크몰 영수증', 24, ink)
    text(PANEL[0] + 30, PANEL[3] - 70, f"{state.day}일차 · {state.request()['customer']} 주문용", 14, quiet)
    for i, (tid, n) in enumerate(list(lines.items())[:12]):
        p = ITEMS.get(tid) or PARTS[tid]
        y = PANEL[3] - 110 - i * 30
        text(PANEL[0] + 30, y, f"{p['name']} × {n}", 16, ink)
        text(PANEL[2] - 110, y, f"{p['price'] * n}만", 16, ink)
    if len(lines) > 12:
        text(PANEL[0] + 30, 230, f"외 {len(lines) - 12}개", 14, quiet)
    for x in range(PANEL[0] + 30, PANEL[2] - 30, 12):
        box(x, 206, x + 6, 208, quiet)
    text(PANEL[0] + 30, 186, f"결제 금액  {total}만 원", 20, ink)
    text(PANEL[0] + 30, 160, f"남은 가게 돈  {state.money}만 원  ·  창고로 배송 완료", 14, quiet)
    ui.button(BTN_OK, '확인 [Enter]', (255, 77, 141))
