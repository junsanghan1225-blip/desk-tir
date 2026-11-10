"""쇼핑 탭 (온라인 도매몰 '데스크몰'). 손님 주문을 들은 뒤 필요한 걸 골라 산다.
카테고리 → 상품 카드 → 클릭하면 상세 페이지(product_mode) → 장바구니 → 결제(receipt_mode) → 창고로 배송."""
from pico2d import *

import game_framework
import product_mode
import receipt_mode
import state
import ui
from common import WIDTH, HEIGHT, ITEMS, PARTS, THEME_NAMES, box, outline, text, inside, draw_fit

CATS = [('screen', '모니터 · 화면'), ('input', '키보드 · 마우스'), ('light', '조명'), ('audio', '오디오'),
        ('plant', '식물'), ('decor', '소품'), ('wall', '벽 장식'), ('parts', 'PC 부품')]
PART_TYPES = [('CASE', '케이스'), ('MB', '메인보드'), ('CPU', 'CPU'), ('COOLER', '쿨러'), ('SSD', 'SSD'),
              ('GPU', '그래픽카드'), ('RAM', 'RAM'), ('PSU', '파워')]
COLS, ROWS = 4, 2
CARD_W, CARD_H, GAP, GRID_X, GRID_TOP = 218, 232, 12, 20, 548
CART = (958, 70, 1270, 640)
BTN_PAY = (978, 84, 1250, 130)
BTN_PREV, BTN_NEXT = (330, 14, 380, 50), (560, 14, 610, 50)

INK, QUIET, DIM = (232, 226, 255), (170, 160, 220), (90, 78, 130)
CYAN, PINK, GOLD = (46, 230, 214), (255, 77, 141), (255, 214, 92)
PANEL = (34, 24, 70)

cat = 'screen'
part_type = 'CASE'
page = 0
toast = ''


def init():
    global toast
    toast = ''


def finish():
    pass


def resume():
    pass


# ---------- 목록 ----------
def products():
    if cat == 'parts':
        ids = [p for p in PARTS if PARTS[p]['type'] == part_type]
    else:
        ids = [i for i in ITEMS if ITEMS[i]['cat'] == cat]
    open_ = set(state.catalog())
    return sorted(ids, key=lambda t: (t not in open_, spec(t)['price']))  # 살 수 있는 것 먼저, 싼 순


def spec(tid):
    return ITEMS.get(tid) or PARTS[tid]


def icon_of(tid):
    if tid in ITEMS:
        return tid
    t = PARTS[tid]['type']
    return tid if t == 'CASE' else 'part_' + t


def pages():
    return max(1, -(-len(products()) // (COLS * ROWS)))


def card_rect(i):
    col, row = i % COLS, i // COLS
    x = GRID_X + col * (CARD_W + GAP)
    y2 = GRID_TOP - row * (CARD_H + GAP)
    return x, y2 - CARD_H, x + CARD_W, y2


def visible():
    per = COLS * ROWS
    return products()[page * per:(page + 1) * per]


def cat_rect(i):
    x = 20 + i * 114
    return x, 600, x + 108, 638


def sub_rect(i):
    x = 20 + i * 100
    return x, 560, x + 94, 590


def cart_rows():
    return list(state.cart.items())


CART_ROWS = 9


def cart_row(i):
    y2 = 586 - i * 38
    return CART[0] + 12, y2 - 34, CART[2] - 12, y2


# ---------- 입력 ----------
def handle_event(e):
    global cat, part_type, page, toast
    if ui.tab_key(e):
        ui.goto_tab(ui.tab_key(e))
        return
    if e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        pay()
        return
    if e.type != SDL_MOUSEBUTTONDOWN:
        return
    x, y = game_framework.mouse
    right = e.button == SDL_BUTTON_RIGHT
    tab = ui.tab_at(x, y)
    if tab:
        ui.goto_tab(tab)
        return
    for i, (key, _) in enumerate(CATS):
        if inside(x, y, cat_rect(i)):
            cat, page, toast = key, 0, ''
            return
    if cat == 'parts':
        for i, (key, _) in enumerate(PART_TYPES):
            if inside(x, y, sub_rect(i)):
                part_type, page = key, 0
                return
    if inside(x, y, BTN_PREV):
        page = max(0, page - 1)
        return
    if inside(x, y, BTN_NEXT):
        page = min(pages() - 1, page + 1)
        return
    for i, tid in enumerate(visible()):
        if inside(x, y, card_rect(i)):
            if right:  # 우클릭 = 바로 담기
                toast = f"{spec(tid)['name']} 담음" if state.add_to_cart(tid) else '업그레이드가 필요해요'
            else:
                product_mode.open_(tid)
            return
    for i, (tid, n) in enumerate(cart_rows()[:CART_ROWS]):
        if inside(x, y, cart_row(i)):
            state.add_to_cart(tid, -1 if right or x < cart_row(i)[0] + 40 else 1)
            return
    if inside(x, y, BTN_PAY):
        pay()


def pay():
    global toast
    if not state.cart:
        toast = '장바구니가 비어 있어요'
        return
    result = state.checkout()
    if not result:
        toast = '가게 돈이 모자라요'
        return
    receipt_mode.show(*result)


def update():
    pass


# ---------- 그리기 ----------
def draw_card(i, tid):
    x1, y1, x2, y2 = card_rect(i)
    p = spec(tid)
    locked = not state.unlocked(p)
    box(x1, y1, x2, y2, PANEL)
    outline(x1, y1, x2, y2, (60, 48, 110))
    box(x1 + 10, y2 - 120, x2 - 10, y2 - 10, (24, 16, 52))
    draw_fit(icon_of(tid), (x1 + x2) // 2, y2 - 65, CARD_W - 40, 96)
    text(x1 + 12, y2 - 140, p['name'], 15, DIM if locked else INK)
    text(x1 + 12, y2 - 166, f"{p['price']}만 원", 18, DIM if locked else GOLD)
    if tid in ITEMS:
        tags = ' · '.join(THEME_NAMES[t] for t in p['tags'])
        text(x1 + 12, y2 - 190, tags, 12, QUIET)
    else:
        text(x1 + 12, y2 - 190, short_spec(p), 12, QUIET)
    have = state.stock.get(tid, 0)
    in_cart = state.cart.get(tid, 0)
    if have:
        text(x1 + 12, y1 + 14, f"창고 {have}", 12, CYAN)
    if in_cart:
        text(x2 - 76, y1 + 14, f"담음 {in_cart}", 12, PINK)
    if locked:
        text(x1 + 12, y1 + 14, '업그레이드 필요', 12, PINK)


def short_spec(p):
    t = p['type']
    if t == 'CASE':
        return f"보드 {p['mb_max']} · GPU {p['gpu_max']}mm"
    if t == 'MB':
        return f"{p['socket']} · {p['size']} · RAM {p['ram_slots']} · USB {p['usb']}"
    if t == 'CPU':
        return f"{p['socket']} · 성능 {p['perf']} · {p['watt']}W"
    if t == 'COOLER':
        return f"{p['tdp']}W까지 · 높이 {p['height']}mm"
    if t == 'GPU':
        return f"성능 {p['perf']} · {p['length']}mm · DP {p['dp']}"
    if t == 'RAM':
        return f"성능 +{p['perf']}"
    if t == 'SSD':
        return f"{p['capacity']} · M.2"
    return f"{p['capacity']}W · GPU 전원선 {p['pcie']}"


def draw_cart():
    box(*CART, PANEL)
    outline(*CART, PINK)
    text(CART[0] + 14, CART[3] - 22, f'장바구니  {sum(state.cart.values())}개', 18, PINK)
    rows = cart_rows()
    if not rows:
        text(CART[0] + 14, CART[3] - 60, '상품을 클릭해서 담으세요', 14, QUIET)
        text(CART[0] + 14, CART[3] - 84, '(우클릭하면 바로 담기)', 13, DIM)
    for i, (tid, n) in enumerate(rows[:CART_ROWS]):
        x1, y1, x2, y2 = cart_row(i)
        box(x1, y1, x2, y2, (24, 16, 52))
        text(x1 + 8, (y1 + y2) // 2, '−', 18, PINK)
        text(x1 + 30, (y1 + y2) // 2 + 6, spec(tid)['name'], 13)
        text(x1 + 30, (y1 + y2) // 2 - 9, f"{spec(tid)['price']}만 × {n}", 11, QUIET)
        text(x2 - 56, (y1 + y2) // 2, f"{spec(tid)['price'] * n}만", 14, GOLD)
    if len(rows) > CART_ROWS:
        text(CART[0] + 14, 226, f"외 {len(rows) - CART_ROWS}종 (결제하면 영수증에 전부 표시)", 12, QUIET)
    total = state.cart_total()
    text(CART[0] + 14, 196, f"합계  {total}만 원", 18, GOLD)
    after = state.money - total
    text(CART[0] + 14, 166, f"결제 후 가게 돈  {after}만", 14, INK if after >= 0 else PINK)
    text(CART[0] + 14, 144, f"이 주문 사용  {state.spent()}만 / 예산 {state.request()['budget']}만", 12, QUIET)
    ui.button(BTN_PAY, f"결제하기 [Enter]", PINK if rows else (90, 78, 130))


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    text(20, 644 - 2, '', 1)
    for i, (key, label) in enumerate(CATS):
        r = cat_rect(i)
        on = key == cat
        box(*r, (124, 92, 255) if on else PANEL)
        text(r[0] + 10, (r[1] + r[3]) // 2, label, 13, INK if on else QUIET)
    if cat == 'parts':
        for i, (key, label) in enumerate(PART_TYPES):
            r = sub_rect(i)
            on = key == part_type
            box(*r, (46, 120, 130) if on else (24, 16, 52))
            outline(*r, CYAN if on else (60, 48, 110))
            text(r[0] + 10, (r[1] + r[3]) // 2, label, 13, INK if on else QUIET)
    for i, tid in enumerate(visible()):
        draw_card(i, tid)
    ui.button(BTN_PREV, '◀', (124, 92, 255))
    ui.button(BTN_NEXT, '▶', (124, 92, 255))
    text(420, 32, f"{page + 1} / {pages()} 쪽  ·  {len(products())}개 상품", 14, QUIET)
    draw_cart()
    ui.top_bar()
    ui.work_tabs('shop')
    if toast:
        text(640, 32, toast, 15, PINK)
    text(640, 56, f"가게 돈 {state.money}만 원", 15, CYAN)
