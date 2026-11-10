"""PC 조립 화면 (케이스 옆판을 연 시점). 왼쪽 재고에서 부품을 끌어다 제자리에 꽂고, 파워의 전원선을 끌어 소켓에 꽂는다.
끌고 있는 동안 갈 자리가 하늘색(가능) / 분홍(불가 + 이유)으로 표시된다. 전원 테스트는 CPU → DRAM → VGA → BOOT 디버그 LED로 결과를 보여 준다."""
from pico2d import *

import game_framework
import decorate_mode
import state
import ui
from common import WIDTH, HEIGHT, PARTS, box, outline, text, to_canvas_y, inside, draw_fit, sprite
from pcbuild import POST_STAGES

ORDER = ['CASE', 'MB', 'CPU', 'COOLER', 'RAM', 'SSD', 'GPU', 'PSU']
TYPE_NAMES = {'CASE': '케이스', 'MB': '메인보드', 'CPU': 'CPU', 'COOLER': '쿨러', 'RAM': 'RAM', 'SSD': 'M.2 SSD', 'GPU': '그래픽카드', 'PSU': '파워'}
CABLE_NAMES = {'24pin': '메인 24핀', 'cpu8': 'CPU 8핀', 'pcie0': 'GPU 8핀 #1', 'pcie1': 'GPU 8핀 #2', 'front': '전원 버튼선'}
PSU_CABLES = ['24pin', 'cpu8', 'pcie0', 'pcie1']
FRONT_SRC = (820, 84, 890, 112)  # 케이스 앞면 버튼에서 나오는 선

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


def ssd_rect():
    mx1, my1, _, _ = mb_rect()
    return mx1 + 60, my1 + 88, mx1 + 190, my1 + 104


def lever_rect():
    x1, y1, x2, y2 = cpu_rect()
    return x1 - 30, y1, x1 - 14, y2


def socket_rect(cable):
    mx1, my1, mx2, my2 = mb_rect()
    if cable == 'front':
        return mx2 - 60, my1 + 110, mx2 - 12, my1 + 130
    if cable == '24pin':
        return mx2 - 30, my2 - 150, mx2 - 10, my2 - 40
    if cable == 'cpu8':
        return mx1 + 16, my2 - 30, mx1 + 90, my2 - 10
    gx1, gy1, gx2, gy2 = gpu_rect()
    i = int(cable[-1])
    return gx2 - 70 + i * 34, gy2 - 4, gx2 - 42 + i * 34, gy2 + 14


def psu_port(cable):
    if cable == 'front':
        return FRONT_SRC
    i = PSU_CABLES.index(cable)
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
            'SSD': grow(ssd_rect(), 16), 'GPU': grow(gpu_rect(), 16), 'PSU': grow(PSU_BAY, 16)}[t]
    return (t, None) if inside(x, y, zone) else None


# ---------- 재고 ----------
INV_PER_PAGE = 14
inv_page = 0
BTN_INV_PREV, BTN_INV_NEXT = (14, 70, 64, 100), (206, 70, 256, 100)
PASTE_ROW = (10, ROW_TOP - ROW_H + 4, INV_W - 10, ROW_TOP)  # 서멀 구리스: 항상 있는 도구


def inv_all():
    return [p for t in ORDER for p in PARTS if PARTS[p]['type'] == t and state.stock.get(p, 0) > 0]


def inv_ids():
    """지금 쪽에 보이는 재고 (첫 줄은 서멀 구리스 도구)."""
    return inv_all()[inv_page * INV_PER_PAGE:(inv_page + 1) * INV_PER_PAGE]


def inv_row(i):
    y = ROW_TOP - (i + 1) * ROW_H
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
    checks = [('COOLER', cooler_rect()), ('CPU', cpu_rect()), ('SSD', ssd_rect()), ('GPU', gpu_rect()), ('PSU', PSU_BAY), ('MB', mb_rect()), ('CASE', CASE_AREA)]
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
    global inv_page
    if inside(x, y, BTN_INV_PREV) or inside(x, y, BTN_INV_NEXT):
        last = max(0, (len(inv_all()) - 1) // INV_PER_PAGE)
        inv_page = max(0, inv_page - 1) if inside(x, y, BTN_INV_PREV) else min(last, inv_page + 1)
        return
    if state.pc.get('MB') and inside(x, y, grow(lever_rect(), 8)):
        toast = state.pc.toggle_lever() or ('레버를 열었어요' if state.pc.lever_open else '레버를 닫았어요')
        post_result = None
        return
    if inside(x, y, PASTE_ROW):
        held, toast = ('paste', None), ''
        return
    for c in CABLE_NAMES:  # 파워 전원선 + 케이스 전원 버튼선
        has_src = 'PSU' in state.pc.parts if c != 'front' else 'CASE' in state.pc.parts
        if has_src and inside(x, y, psu_port(c)):
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
    if kind == 'paste':
        if inside(x, y, grow(cpu_rect(), 16)):
            reason = state.pc.apply_paste()
            toast = reason or '서멀 구리스를 발랐어요'
        return
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
    mb = state.pc.spec('MB')
    board = f"  ·  {mb['name']} ({mb['size']})" if mb else ''
    text(x1 + 12, y2 - 16, f"{case['name']}{board}", 13, QUIET)
    for fy in (420, 540):  # 뒷면 케이스 팬
        sprite('inb_casefan').draw(x2 - 50, fy, 80, 80)
    # GPU 길이 한계선
    gx = gpu_rect()[0] + int(case['gpu_max'] * 1.25)
    if gx < x2:
        draw_line(gx, mb_rect()[1] - 6, gx, mb_rect()[1] + 74, *PINK)


def put(name, r):
    """스프라이트를 영역 r에 꽉 맞춰 그린다."""
    x1, y1, x2, y2 = r
    sprite(name).draw((x1 + x2) / 2, (y1 + y2) / 2, x2 - x1, y2 - y1)


def draw_board():
    mb = state.pc.spec('MB')
    mx1, my1, mx2, my2 = mb_rect()
    if not mb:
        if state.pc.get('CASE'):
            outline(mx1, my1, mx2, my2, DIM)
            text(mx1 + 110, (my1 + my2) // 2, '메인보드 자리', 18, DIM)
        return
    put('inb_' + mb['id'], mb_rect())
    # 소켓 레버: 열리면 위로 선다
    lx1, ly1, lx2, ly2 = lever_rect()
    if state.pc.lever_open:
        box(lx1 + 5, ly2, lx2 - 5, ly2 + 56, (216, 216, 224))
        box(lx1 + 2, ly2 + 50, lx2 - 2, ly2 + 58, (216, 216, 224))
    else:
        box(lx1 + 5, ly1 + 4, lx2 - 5, ly2 - 4, (176, 176, 188))
        box(lx1 + 2, ly1, lx2 - 2, ly1 + 8, (176, 176, 188))


def draw_parts():
    pc = state.pc
    cpu, cooler, gpu = pc.spec('CPU'), pc.spec('COOLER'), pc.spec('GPU')
    if cpu:
        put('inb_cpu', cpu_rect())
    if cpu and pc.paste and not cooler:
        put('inb_paste', cpu_rect())
    if pc.get('SSD'):
        put('inb_ssd', ssd_rect())
    if cooler:
        put('inb_' + cooler['id'], cooler_rect())
    for i, r in enumerate(pc.ram):
        if r:
            put('inb_' + r, ram_rect(i))
    if gpu:
        put('inb_' + gpu['id'], gpu_rect())
        for i in range(gpu['pcie']):
            box(*socket_rect(f'pcie{i}'), (20, 20, 28))
            outline(*socket_rect(f'pcie{i}'), (90, 90, 100))
    psu = pc.spec('PSU')
    x1, y1, x2, y2 = PSU_BAY
    if psu:
        put('inb_psu_white' if psu['id'] == 'psu5' else 'inb_psu', PSU_BAY)
        text(x1 + 150, y1 + 18, f"{psu['capacity']}W", 13, INK)
        for c in PSU_CABLES:
            if c.startswith('pcie') and int(c[-1]) >= psu['pcie']:
                continue
            r = psu_port(c)
            on = c in pc.cables
            box(*r, (60, 50, 100) if on else (24, 16, 52))
            outline(*r, CYAN if c in pc.cable_targets() and not on else DIM)
            text(r[0] + 4, (r[1] + r[3]) // 2, CABLE_NAMES[c], 11, INK if on else QUIET)
    elif pc.get('CASE'):
        outline(x1, y1, x2, y2, DIM)
        text(x1 + 60, (y1 + y2) // 2, '파워 자리', 16, DIM)


CHANNEL_GAP = 9  # 통로 안에서 선끼리 간격


def cable_color(c):
    return (230, 190, 80) if c.startswith('pcie') else (220, 140, 60) if c != 'front' else (170, 160, 220)


def cable_path(c, end):
    """파워 포트 → 오른쪽 통로 → 소켓 높이 → 소켓. 실제 선 정리처럼 꺾인 선으로 그린다."""
    order = list(CABLE_NAMES).index(c)
    color = cable_color(c)
    start = mid_right(psu_port(c)) if c != 'front' else ((FRONT_SRC[0] + FRONT_SRC[2]) // 2, FRONT_SRC[3])
    lane = mb_rect()[2] + 22 + order * CHANNEL_GAP
    pts = [start, (lane, start[1]), (lane, end[1]), end]
    for a, b in zip(pts, pts[1:]):
        cable_line(a, b, color, 1)


def cable_line(a, b, color, w=2):
    for d in range(-w, w + 1):
        draw_line(a[0] + (d if a[1] != b[1] else 0), a[1] + (d if a[1] == b[1] else 0),
                  b[0] + (d if a[1] != b[1] else 0), b[1] + (d if a[1] == b[1] else 0), *color)


def mid_right(r):
    return r[2], (r[1] + r[3]) // 2


def center(r):
    return (r[0] + r[2]) // 2, (r[1] + r[3]) // 2


def draw_cables():
    if state.pc.get('CASE'):  # 케이스 앞면 전원 버튼선 출발점
        on = 'front' in state.pc.cables
        box(*FRONT_SRC, (60, 50, 100) if on else (24, 16, 52))
        outline(*FRONT_SRC, CYAN if 'front' in state.pc.cable_targets() else DIM)
        text(FRONT_SRC[0] + 4, (FRONT_SRC[1] + FRONT_SRC[3]) // 2, '버튼선', 11, INK)
    for c in state.pc.cables:
        cable_path(c, center(socket_rect(c)))
        r = socket_rect(c)
        color = cable_color(c)
        box(*r, (24, 20, 30))                    # 커넥터 몸통
        outline(*r, color)
        box(r[0] + 2, r[1] + 2, r[0] + 6, r[3] - 2, color)  # 래치


def hover_spots():
    """(영역, 이름) — 마우스를 올렸을 때만 보여 줄 자리 이름."""
    pc = state.pc
    mb = pc.spec('MB')
    if not mb:
        return []
    spots = [(cpu_rect(), f"CPU 소켓 {mb['socket']}" + (f" · {pc.spec('CPU')['name']}" if pc.get('CPU') else '')),
             (lever_rect(), '소켓 레버 (클릭해서 열고 닫기)'),
             (ssd_rect(), 'M.2 슬롯' + (f" · {pc.spec('SSD')['name']}" if pc.get('SSD') else '')),
             (gpu_rect() if pc.get('GPU') else pcie_rect(), f"{pc.spec('GPU')['name']} · {pc.spec('GPU')['length']}mm" if pc.get('GPU') else 'PCIe x16 (그래픽카드)'),
             (socket_rect('24pin'), '메인 24핀 소켓'), (socket_rect('cpu8'), 'CPU 8핀 소켓'), (socket_rect('front'), '케이스 전원 버튼 핀')]
    for i in range(mb['ram_slots']):
        name = ('A1', 'A2', 'B1', 'B2')[i] if mb['ram_slots'] == 4 else str(i + 1)
        stick = pc.ram[i]
        spots.append((ram_rect(i), f"RAM 슬롯 {name}" + (f" · {PARTS[stick]['name']}" if stick else '')))
    return spots


def draw_hover():
    if held:
        return
    x, y = game_framework.mouse
    for r, label in hover_spots():
        if inside(x, y, grow(r, 4)):
            w = len(label) * 13 + 16
            box(x + 14, y + 10, x + 14 + w, y + 34, (10, 6, 22), 220)
            outline(x + 14, y + 10, x + 14 + w, y + 34, CYAN)
            text(x + 22, y + 22, label, 13, INK)
            return


def draw_drag():
    if not held:
        return
    kind, what = held
    x, y = game_framework.mouse
    if kind == 'paste':
        outline(*grow(cpu_rect(), 6), CYAN if state.pc.get('CPU') and not state.pc.get('COOLER') else PINK)
        draw_circle(x, y, 14, 200, 200, 210, 255, True)
        text(x + 18, y, '서멀 구리스', 13, INK)
        return
    if kind == 'cable':
        r = socket_rect(what)
        outline(*grow(r, 6), CYAN)
        cable_line(mid_right(psu_port(what)) if what != 'front' else center(FRONT_SRC), (x, y), GOLD)
        return
    # 갈 수 있는 자리 미리 보기
    t = PARTS[what]['type']
    zones = [('RAM', i, ram_rect(i)) for i in range(state.pc.ram_slots()) if not state.pc.ram[i]] if t == 'RAM' else \
        [(t, None, {'CASE': CASE_AREA, 'MB': mb_rect(), 'CPU': cpu_rect(), 'COOLER': cooler_rect(), 'SSD': ssd_rect(), 'GPU': gpu_rect(), 'PSU': PSU_BAY}[t])]
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
    psu_lines = [c for c in pc.cable_targets() if c != 'front']
    steps = [('케이스', 'CASE' in pc.parts), ('메인보드', 'MB' in pc.parts), ('CPU (레버 닫기)', 'CPU' in pc.parts and not pc.lever_open),
             ('서멀 구리스', pc.paste), ('쿨러', 'COOLER' in pc.parts), ('RAM', any(pc.ram)), ('M.2 SSD', 'SSD' in pc.parts),
             ('그래픽카드', 'GPU' in pc.parts), ('파워', 'PSU' in pc.parts),
             ('전원선', 'PSU' in pc.parts and set(psu_lines) <= pc.cables), ('전원 버튼선', 'front' in pc.cables)]
    for i, (name, done) in enumerate(steps):
        y = 584 - i * 21
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
    x1, y1, x2, y2 = PASTE_ROW
    box(x1, y1, x2, y2, (46, 40, 90))
    draw_circle(x1 + 16, (y1 + y2) // 2, 9, 200, 200, 210, 255, True)
    text(x1 + 36, (y1 + y2) // 2 + 6, '서멀 구리스', 14)
    text(x1 + 36, (y1 + y2) // 2 - 9, '도구 · CPU 위로 끌기', 11, QUIET)
    ids = inv_ids()
    if not ids:
        text(14, ROW_TOP - 56, '부품 재고가 없어요', 15, QUIET)
        text(14, ROW_TOP - 78, '쇼핑 탭에서 사 오세요', 13, DIM)
    total = len(inv_all())
    if total > INV_PER_PAGE:
        ui.button(BTN_INV_PREV, '▲', (124, 92, 255))
        ui.button(BTN_INV_NEXT, '▼', (124, 92, 255))
        last = (total - 1) // INV_PER_PAGE
        text(92, 85, f"{inv_page + 1}/{last + 1}", 13, QUIET)
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
    draw_hover()
    ui.top_bar()
    text(INV_W + 20, 30, '좌클릭: 집어서 옮기기 · 우클릭: 빼서 재고로 (위에 꽂힌 것도 같이)', 13, QUIET)
    if toast:
        text(INV_W + 20, 54, toast, 16, PINK)
    ui.work_tabs('build')
