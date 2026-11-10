"""상품 상세 페이지 (쇼핑 화면 위에 겹쳐 뜸). 큰 그림 · 설명 · 사양 · 수량을 보고 장바구니에 담는다."""
from pico2d import *

import game_framework
import state
import ui
from common import WIDTH, HEIGHT, ITEMS, PARTS, THEME_NAMES, box, outline, text, inside, draw_fit
from room import LAYER_NAMES

OVERLAY = True
ESC = 'back'
PANEL = (180, 90, 1100, 610)
BTN_MINUS, BTN_PLUS = (640, 150, 690, 196), (770, 150, 820, 196)
BTN_ADD = (840, 150, 1080, 196)
BTN_CLOSE = (1030, 560, 1090, 600)
BTN_SELL = (640, 210, 820, 246)
TYPE_NAMES = {'CASE': '케이스', 'MB': '메인보드', 'CPU': 'CPU', 'COOLER': '쿨러', 'SSD': 'SSD', 'GPU': '그래픽카드', 'RAM': 'RAM', 'PSU': '파워'}
PORT_NAMES = {'DP': 'DP 케이블', 'USB': 'USB 케이블', 'AUDIO': '오디오 케이블'}

tid = None
qty = 1
toast = ''


def open_(thing_id):
    global tid, qty, toast
    tid, qty, toast = thing_id, 1, ''
    game_framework.push_mode(__import__('product_mode'))


def init():
    pass


def finish():
    pass


def spec():
    return ITEMS.get(tid) or PARTS[tid]


def spec_lines():
    p = spec()
    if tid in ITEMS:
        conn = PORT_NAMES.get(p.get('port'), '')
        if p.get('dongle'):
            conn = 'USB 동글 (무선)'
        return [f"놓는 곳  {LAYER_NAMES[p['layer']]} · {p['size']}칸",
                f"연결  {conn or '필요 없음'}",
                f"분위기  {' · '.join(THEME_NAMES[t] for t in p['tags'])}"]
    t = p['type']
    rows = {'CASE': lambda: [f"보드 {p['mb_max']}까지", f"그래픽카드 {p['gpu_max']}mm까지", f"쿨러 높이 {p['cooler_max']}mm까지"],
            'MB': lambda: [f"소켓 {p['socket']} · {p['size']}", f"RAM 슬롯 {p['ram_slots']}개 · M.2 1개", f"뒷면 USB {p['usb']}개 · 오디오 2개"],
            'CPU': lambda: [f"소켓 {p['socket']}", f"성능 {p['perf']} · 발열 {p['watt']}W"],
            'COOLER': lambda: [f"{p['tdp']}W까지 식힘", f"높이 {p['height']}mm"],
            'SSD': lambda: [f"용량 {p['capacity']}", 'M.2 슬롯에 장착 · 없으면 부팅 불가'],
            'GPU': lambda: [f"성능 {p['perf']} · 전력 {p['watt']}W", f"길이 {p['length']}mm · DP {p['dp']}개", f"보조 전원선 {p['pcie']}개 필요"],
            'RAM': lambda: [f"성능 +{p['perf']}", '같은 RAM 2장이면 듀얼 채널'],
            'PSU': lambda: [f"용량 {p['capacity']}W", f"그래픽카드 전원선 {p['pcie']}개"]}[t]()
    return [f"종류  {TYPE_NAMES[t]}"] + rows


def handle_event(e):
    global qty, toast
    if e.type != SDL_MOUSEBUTTONDOWN:
        if e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
            add()
        return
    x, y = game_framework.mouse
    if inside(x, y, BTN_CLOSE) or not inside(x, y, PANEL):
        game_framework.pop_mode()
    elif inside(x, y, BTN_MINUS):
        qty = max(1, qty - 1)
    elif inside(x, y, BTN_PLUS):
        qty = min(9, qty + 1)
    elif inside(x, y, BTN_ADD):
        add()
    elif inside(x, y, BTN_SELL):
        toast = '반품했어요 (산 값의 절반 환불)' if state.sell_back(tid) else '창고에 없어요'


def add():
    global toast
    if state.add_to_cart(tid, qty):
        game_framework.pop_mode()
    else:
        toast = '가게 업그레이드가 필요해요 (영업 마감 화면에서 구매)'


def update():
    pass


def draw():
    p = spec()
    box(0, 0, WIDTH, HEIGHT, (10, 6, 22), 160)
    box(*PANEL, (28, 20, 60))
    outline(*PANEL, (255, 77, 141))
    # 큰 그림
    box(210, 260, 600, 580, (18, 12, 38))
    icon = tid if tid in ITEMS or p['type'] == 'CASE' else 'part_' + p['type']
    draw_fit(icon, 405, 420, 340, 280)
    text(640, 560, p['name'], 28)
    text(640, 520, f"{p['price']}만 원", 26, (255, 214, 92))
    text(640, 482, p['desc'], 15, (200, 192, 240))
    for i, line in enumerate(spec_lines()):
        text(640, 440 - i * 30, line, 16, (232, 226, 255))
    have = state.stock.get(tid, 0)
    text(210, 230, f"창고 보유 {have}개  ·  장바구니 {state.cart.get(tid, 0)}개", 15, (46, 230, 214))
    if have:
        ui.button(BTN_SELL, '반품 1개', (124, 92, 255))
    ui.button(BTN_MINUS, '−', (124, 92, 255))
    text(722, 173, str(qty), 22)
    ui.button(BTN_PLUS, '+', (124, 92, 255))
    locked = not state.unlocked(p)
    ui.button(BTN_ADD, f"장바구니 담기  {p['price'] * qty}만", (90, 78, 130) if locked else (255, 77, 141))
    ui.button(BTN_CLOSE, 'X', (90, 78, 130))
    if locked:
        text(840, 120, '업그레이드 필요', 14, (255, 77, 141))
    if toast:
        text(210, 120, toast, 15, (255, 77, 141))
