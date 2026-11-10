"""PC 조립 화면 (케이스 옆판을 연 시점). 왼쪽 재고에서 부품을 끌어다 제자리에 꽂고, 파워의 전원선을 끌어 소켓에 꽂는다.
끌고 있는 동안 갈 자리가 하늘색(가능) / 분홍(불가 + 이유)으로 표시된다. 전원 테스트는 CPU → DRAM → VGA → BOOT 디버그 LED로 결과를 보여 준다."""
from pico2d import *

import game_framework
import decorate_mode
import state
import ui
from common import WIDTH, HEIGHT, PARTS, box, outline, text, to_canvas_y, inside, draw_fit
from pcbuild import POST_STAGES

ORDER = ['CASE', 'MB', 'CPU', 'COOLER', 'RAM', 'GPU', 'PSU']
TYPE_NAMES = {'CASE': '케이스', 'MB': '메인보드', 'CPU': 'CPU', 'COOLER': '쿨러', 'RAM': 'RAM', 'GPU': '그래픽카드', 'PSU': '파워'}
CABLE_NAMES = {'24pin': '메인 24핀', 'cpu8': 'CPU 8핀', 'pcie0': 'GPU 8핀 #1', 'pcie1': 'GPU 8핀 #2'}

INV_W, ROW_H, ROW_TOP = 270, 34, 600
CASE_AREA = (290, 70, 900, 636)
PSU_BAY = (306, 84, 520, 196)
BTN_POST = (930, 70, 1270, 116)

INK = (232, 226, 255)
QUIET = (170, 160, 220)
DIM = (90, 78, 130)
CYAN = (46, 230, 214)
PINK = (255, 77, 141)
GOLD = (255, 214, 92)
GREEN = (120, 255, 170)

held = None       # ('part', pid) | ('cable', name)
toast = ''
post_result = None  # 마지막 전원 테스트 결과 (단계, 메시지)


def init():
    global held, toast, post_result
    held, toast, post_result = None, '', None


def finish():
    pass


# ---------- 좌표 ----------
def mb_rect():
    mb = state.pc.spec('MB')
    if mb and mb['size'] == 'mATX':
        return 330, 300, 700, 600
    return 330, 236, 790, 600  # ATX (빈 자리 표시도 ATX 크기)


def cpu_rect():
    mx1, _, _, my2 = mb_rect()
    return mx1 + 60, my2 - 150, mx1 + 160, my2 - 50


def cooler_rect():
    x1, y1, x2, y2 = cpu_rect()
    return x1 - 18, y1 - 18, x2 + 18, y2 + 18


def ram_rect(i):
    mx1, _, _, my2 = mb_rect()
    x = mx1 + 214 + i * 26
    return x, my2 - 196, x + 14, my2 - 24


def pcie_rect():
    mx1, my1, mx2, _ = mb_rect()
    return mx1 + 20, my1 + 56, mx2 - 40, my1 + 70


def gpu_rect():
    gpu = state.pc.spec('GPU') or (PARTS[held[1]] if held and held[0] == 'part' and PARTS[held[1]]['type'] == 'GPU' else None)
    length = gpu['length'] if gpu else 280
    mx1, my1, _, _ = mb_rect()
    return mx1 + 10, my1 + 4, mx1 + 10 + int(length * 1.25), my1 + 64


def socket_rect(cable):
    mx1, my1, mx2, my2 = mb_rect()
    if cable == '24pin':
        return mx2 - 30, my2 - 230, mx2 - 10, my2 - 110
    if cable == 'cpu8':
        return mx1 + 16, my2 - 30, mx1 + 90, my2 - 10
    gx1, gy1, gx2, gy2 = gpu_rect()
    i = int(cable[-1])
    return gx2 - 70 + i * 34, gy2 - 4, gx2 - 42 + i * 34, gy2 + 14


def psu_port(cable):
    i = list(CABLE_NAMES).index(cable)
    return PSU_BAY[2] + 14, PSU_BAY[3] - 24 - i * 26, PSU_BAY[2] + 96, PSU_BAY[3] - 6 - i * 26


def grow(r, m):
    return r[0] - m, r[1] - m, r[2] + m, r[3] + m


def target_for(pid, x, y):
    """(slot, ram_slot) — 놓은 위치가 그 부품의 자리 위인지. 아니면 None."""
    t = PARTS[pid]['type']
    if t == 'RAM':
        for i in range(4):
            if inside(x, y, grow(ram_rect(i), 10)):
                return 'RAM', i
        return None
    zone = {'CASE': CASE_AREA, 'MB': mb_rect(), 'CPU': grow(cpu_rect(), 20), 'COOLER': grow(cooler_rect(), 10),
            'GPU': grow(gpu_rect(), 16), 'PSU': grow(PSU_BAY, 16)}[t]
    return (t, None) if inside(x, y, zone) else None


# ---------- 재고 ----------
def inv_ids():
    return [p for t in ORDER for p in PARTS if PARTS[p]['type'] == t and state.stock.get(p, 0) > 0]


def inv_row(i):
    y = ROW_TOP - i * ROW_H
    return 10, y - ROW_H + 4, INV_W - 10, y


def icon_of(pid):
    t = PARTS[pid]['type']
    return pid if t == 'CASE' else 'part_' + t


# ---------- 입력 ----------
def placed_at(x, y):
    """클릭한 곳에 끼워진 부품 (위에 올라간 것 먼저)."""
    for i in range(4):
        if state.pc.ram[i] and inside(x, y, ram_rect(i)):
            return 'RAM', i
    checks = [('COOLER', cooler_rect()), ('CPU', cpu_rect()), ('GPU', gpu_rect()), ('PSU', PSU_BAY), ('MB', mb_rect()), ('CASE', CASE_AREA)]
    for slot, r in checks:
        if state.pc.get(slot) and inside(x, y, r):
            return slot, None
    return None


def pull_out(slot, ram_slot):
    for pid in state.pc.remove(slot, ram_slot):
        state.give_back(pid)


def on_down(x, y, button):
    global held, toast, post_result
    tab = ui.tab_at(x, y)
    if tab:
        ui.goto_tab(tab)
        return
    if inside(x, y, BTN_POST):
        post_result = state.pc.post()
        return
    for c in CABLE_NAMES:  # 파워 전원선
        if 'PSU' in state.pc.parts and inside(x, y, psu_port(c)):
            if button == SDL_BUTTON_RIGHT:
                state.pc.cables.discard(c)
            elif c in state.pc.cable_targets():
                held, toast = ('cable', c), ''
            else:
                toast = '지금은 이 선을 꽂을 데가 없어요'
            post_result = None
            return
    for i, pid in enumerate(inv_ids()):
        if inside(x, y, inv_row(i)):
            held, toast = ('part', pid), ''
            return
    hit = placed_at(x, y)
    if hit:
        slot, rs = hit
        pid = state.pc.ram[rs] if slot == 'RAM' else state.pc.get(slot)
        pull_out(slot, rs)
        post_result = None
        if button == SDL_BUTTON_LEFT:
            held = ('part', pid)  # 집어서 옮기기 (위에 있던 부품은 재고로)


def on_up(x, y):
    global held, toast, post_result
    if not held:
        return
    kind, what = held
    held = None
    post_result = None
    if kind == 'cable':
        if inside(x, y, grow(socket_rect(what), 12)):
            toast = state.pc.plug(what) or ''
        return
    target = target_for(what, x, y)
    if not target:
        if inside(x, y, CASE_AREA):
            toast = f"{TYPE_NAMES[PARTS[what]['type']]} 자리가 아니에요"
        return
    reason = state.pc.check(what, target[1])
    if reason:
        toast = reason
    elif PARTS[what]['price'] > state.money_left():
        toast = '손님 예산을 넘어요!'
    elif not state.take(what):
        toast = '재고가 없어요'
    else:
        state.pc.place(what, target[1])
        toast = ''


def handle_event(e):
    global post_result
    if ui.tab_key(e):
        ui.goto_tab(ui.tab_key(e))
    elif e.type == SDL_KEYDOWN and e.key == SDLK_TAB:
        game_framework.change_mode(decorate_mode)
    elif e.type == SDL_KEYDOWN and e.key == SDLK_SPACE:
        post_result = state.pc.post()
    elif e.type == SDL_MOUSEBUTTONDOWN:
        on_down(*game_framework.mouse, e.button)
    elif e.type == SDL_MOUSEBUTTONUP and e.button == SDL_BUTTON_LEFT:
        on_up(*game_framework.mouse)


def update():
    pass


# ---------- 그리기 ----------
def draw_case():
    x1, y1, x2, y2 = CASE_AREA
    case = state.pc.spec('CASE')
    if not case:
        outline(x1, y1, x2, y2, DIM)
        text(x1 + 150, (y1 + y2) // 2, '케이스를 여기에 끌어다 놓으세요', 20, DIM)
        return
    box(x1, y1, x2, y2, (14, 9, 30))
    outline(x1, y1, x2, y2, PINK if case['id'] == 'case3' else (124, 92, 255))
    text(x1 + 12, y2 - 18, f"{case['name']}  ·  보드 {case['mb_max']}까지 · GPU {case['gpu_max']}mm · 쿨러 {case['cooler_max']}mm", 13, QUIET)
    for fy in (420, 540):  # 뒷면 팬
        draw_circle(x2 - 50, fy, 34, 60, 50, 100, 255, False)
    # GPU 길이 한계선
    gx = gpu_rect()[0] + int(case['gpu_max'] * 1.25)
    if gx < x2:
        draw_line(gx, mb_rect()[1] - 6, gx, mb_rect()[1] + 74, *PINK)


def draw_board():
    mb = state.pc.spec('MB')
    mx1, my1, mx2, my2 = mb_rect()
    if not mb:
        if state.pc.get('CASE'):
            outline(mx1, my1, mx2, my2, DIM)
            text(mx1 + 110, (my1 + my2) // 2, '메인보드 자리', 18, DIM)
        return
    box(mx1, my1, mx2, my2, (22, 40, 52))
    outline(mx1, my1, mx2, my2, (40, 90, 100))
    for k in range(6):  # 회로 무늬
        draw_line(mx1 + 10, my1 + 100 + k * 40, mx1 + 50 + k * 20, my1 + 100 + k * 40, 34, 70, 80)
    text(mx1 + 214, my1 + 100, f"{mb['name']} · {mb['size']}", 12, QUIET)
    # 빈 자리들
    x1, y1, x2, y2 = cpu_rect()
    outline(x1, y1, x2, y2, (60, 110, 120))
    text(x1 + 18, (y1 + y2) // 2, f"소켓 {mb['socket']}", 12, (90, 140, 150))
    for i in range(4):
        r = ram_rect(i)
        if i < mb['ram_slots']:
            box(*r, (30, 30, 40))
            text(r[0], r[1] - 12, 'AB'[i // 2] + str(i % 2 + 1) if mb['ram_slots'] == 4 else str(i + 1), 11, QUIET)
    box(*pcie_rect(), (30, 30, 40))
    text(pcie_rect()[0], pcie_rect()[1] - 12, 'PCIe x16', 11, QUIET)
    for c in ('24pin', 'cpu8'):
        box(*socket_rect(c), (40, 40, 52))


def draw_parts():
    cpu, cooler, gpu = state.pc.spec('CPU'), state.pc.spec('COOLER'), state.pc.spec('GPU')
    if cpu:
        x1, y1, x2, y2 = cpu_rect()
        box(x1 + 8, y1 + 8, x2 - 8, y2 - 8, (190, 190, 205))
        text(x1 + 14, (y1 + y2) // 2, cpu['name'][:5], 12, (30, 30, 40))
    if cooler:
        x1, y1, x2, y2 = cooler_rect()
        cx, cy = (x1 + x2) // 2, (y1 + y2) // 2
        if cooler['id'] == 'cool2':
            box(x1, y1, x2, y2, (60, 64, 80))
            for k in range(8):
                draw_line(x1 + 6, y1 + 10 + k * 16, x2 - 6, y1 + 10 + k * 16, 120, 124, 140)
        draw_circle(cx, cy, 44, 40, 40, 60, 255, True)
        draw_circle(cx, cy, 44, *CYAN, 255, False)
        draw_circle(cx, cy, 12, *CYAN, 255, True)
    for i, r in enumerate(state.pc.ram):
        if r:
            x1, y1, x2, y2 = ram_rect(i)
            box(x1, y1, x2, y2, (60, 150, 100) if r != 'ram3' else (124, 92, 255))
            outline(x1, y1, x2, y2, GREEN)
    if gpu:
        x1, y1, x2, y2 = gpu_rect()
        box(x1, y1, x2, y2, (26, 22, 44))
        outline(x1, y1, x2, y2, PINK if gpu['id'] == 'gpu3' else (124, 92, 255))
        fans = 3 if gpu['length'] > 300 else 2 if gpu['length'] > 200 else 1
        for k in range(fans):
            draw_circle(x1 + 50 + k * 100, (y1 + y2) // 2, 24, *QUIET, 255, False)
        text(x1 + 8, y2 - 10, f"{gpu['name']} {gpu['length']}mm", 11, INK)
        for i in range(gpu['pcie']):
            box(*socket_rect(f'pcie{i}'), (40, 40, 52))
    psu = state.pc.spec('PSU')
    x1, y1, x2, y2 = PSU_BAY
    if psu:
        box(x1, y1, x2, y2, (30, 26, 50))
        outline(x1, y1, x2, y2, (124, 92, 255))
        draw_circle(x1 + 60, (y1 + y2) // 2, 36, *QUIET, 255, False)
        text(x1 + 110, (y1 + y2) // 2, f"{psu['capacity']}W", 16, INK)
        for c in CABLE_NAMES:
            if c.startswith('pcie') and int(c[-1]) >= psu['pcie']:
                continue
            r = psu_port(c)
            on = c in state.pc.cables
            box(*r, (60, 50, 100) if on else (24, 16, 52))
            outline(*r, CYAN if c in state.pc.cable_targets() else DIM)
            text(r[0] + 4, (r[1] + r[3]) // 2, CABLE_NAMES[c], 11, INK if on else QUIET)
    elif state.pc.get('CASE'):
        outline(x1, y1, x2, y2, DIM)
        text(x1 + 60, (y1 + y2) // 2, '파워 자리', 16, DIM)


def cable_line(a, b, color):
    for d in (-2, -1, 0, 1, 2):
        draw_line(a[0], a[1] + d, b[0], b[1] + d, *color)


def mid_right(r):
    return r[2], (r[1] + r[3]) // 2


def center(r):
    return (r[0] + r[2]) // 2, (r[1] + r[3]) // 2


def draw_cables():
    for c in state.pc.cables:
        cable_line(mid_right(psu_port(c)), center(socket_rect(c)), GOLD if c.startswith('pcie') else (255, 160, 60))
        box(*socket_rect(c), GOLD)


def draw_drag():
    if not held:
        return
    kind, what = held
    x, y = game_framework.mouse
    if kind == 'cable':
        r = socket_rect(what)
        outline(*grow(r, 6), CYAN)
        cable_line(mid_right(psu_port(what)), (x, y), GOLD)
        return
    # 갈 수 있는 자리 미리 보기
    t = PARTS[what]['type']
    zones = [('RAM', i, ram_rect(i)) for i in range(state.pc.ram_slots()) if not state.pc.ram[i]] if t == 'RAM' else \
        [(t, None, {'CASE': CASE_AREA, 'MB': mb_rect(), 'CPU': cpu_rect(), 'COOLER': cooler_rect(), 'GPU': gpu_rect(), 'PSU': PSU_BAY}[t])]
    for slot, rs, r in zones:
        reason = state.pc.check(what, rs)
        outline(*grow(r, 4), PINK if reason else CYAN)
        if reason and inside(x, y, grow(r, 20)):
            text(x + 20, y - 30, reason, 14, PINK)
    draw_fit(icon_of(what), x, y, 56, 56)


def draw_side():
    x0 = 930
    text(x0, 610, '조립 순서', 18, PINK)
    pc = state.pc
    steps = [('케이스', 'CASE' in pc.parts), ('메인보드', 'MB' in pc.parts), ('CPU', 'CPU' in pc.parts), ('쿨러', 'COOLER' in pc.parts),
             ('RAM', any(pc.ram)), ('그래픽카드', 'GPU' in pc.parts), ('파워', 'PSU' in pc.parts),
             ('전원선', bool(pc.cable_targets()) and set(pc.cable_targets()) <= pc.cables)]
    for i, (name, done) in enumerate(steps):
        y = 578 - i * 26
        text(x0, y, ('●  ' if done else '○  ') + name, 15, GREEN if done else QUIET)
    need = state.request()['perf']
    stars = '★' * pc.stars() or '-'
    y = 344
    text(x0, y, f"성능 {pc.perf()}  {stars}  (요구 {'★' * need})", 16, CYAN)
    over = pc.watt() > pc.capacity()
    text(x0, y - 28, f"전력 {pc.watt()}W / {pc.capacity() or '?'}W", 16, PINK if over and pc.capacity() else INK)
    extra = []
    if pc.dual_channel():
        extra.append('듀얼 채널 +1')
    if pc.throttled():
        extra.append(f'쿨러 부족 -3')
    text(x0, y - 56, '  ·  '.join(extra), 14, GOLD)
    # 디버그 LED
    text(x0, 238, '디버그 LED', 15, QUIET)
    stage = post_result[0] if post_result else None
    for i, name in enumerate(POST_STAGES):
        lx = x0 + i * 84
        if stage is None:
            color = (40, 32, 70)
        elif stage == 4:
            color = GREEN
        elif i < stage:
            color = (60, 120, 90)
        elif i == max(stage, 0):
            color = PINK
        else:
            color = (40, 32, 70)
        box(lx, 180, lx + 72, 218, color)
        text(lx + 10, 199, name, 14, (18, 12, 38) if color in (GREEN, PINK) else INK)
    if post_result:
        msg = post_result[1]
        text(x0, 154, msg[:22], 15, GREEN if stage == 4 else PINK)
        text(x0, 132, msg[22:], 15, GREEN if stage == 4 else PINK)
    ui.button(BTN_POST, '전원 테스트 [Space]', GOLD)


def draw_inventory():
    box(0, 0, INV_W, HEIGHT - 70, (34, 24, 70))
    text(14, ROW_TOP + 22, '부품 재고  (끌어서 장착)', 18)
    ids = inv_ids()
    if not ids:
        text(14, ROW_TOP - 16, '부품 재고가 없어요', 15, QUIET)
    for i, pid in enumerate(ids):
        x1, y1, x2, y2 = inv_row(i)
        p = PARTS[pid]
        draw_fit(icon_of(pid), x1 + 16, (y1 + y2) // 2, 28, 26)
        text(x1 + 36, (y1 + y2) // 2 + 6, p['name'], 14)
        text(x1 + 36, (y1 + y2) // 2 - 9, f"{TYPE_NAMES[p['type']]} · {p['price']}만", 11, QUIET)
        text(x2 - 34, (y1 + y2) // 2, f"x{state.stock[pid]}", 13, CYAN)


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    draw_case()
    if state.pc.get('CASE'):
        draw_board()
        draw_parts()
        draw_cables()
    draw_inventory()
    draw_side()
    draw_drag()
    ui.top_bar()
    text(INV_W + 20, 30, '좌클릭: 집어서 옮기기 · 우클릭: 빼서 재고로 (위에 꽂힌 것도 같이)', 13, QUIET)
    if toast:
        text(INV_W + 20, 54, toast, 16, PINK)
    ui.work_tabs('build')
