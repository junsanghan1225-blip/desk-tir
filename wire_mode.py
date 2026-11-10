"""배선 정리 화면 (책상 뒤 시점): 위에는 책상 위 기기(책상 순서 그대로), 아래는 PC 후면 포트 한 줄.
기기를 끌어 같은 색 포트에 꽂는다. 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다."""
from pico2d import *

import game_framework
import decorate_mode
import result_mode
import state
import ui
import cables as cab
from common import WIDTH, HEIGHT, ITEMS, box, outline, text, to_canvas_y, inside, draw_fit

BTN_DONE = (1100, 10, 1270, 50)
HINT = {'DP': '모니터는 DP 포트에', 'USB': 'USB 기기는 USB 포트에', 'AUDIO': '스피커 · 헤드셋은 오디오 포트에'}
DEV_Y = 480  # 기기 아이콘 중심

wiring = None  # 선을 끌고 있는 기기 (room.placed 항목)
toast = ''


def init():
    global wiring, toast
    wiring, toast = None, ''


def finish():
    pass


def devices():
    return [p for p in state.room.placed if cab.needs_cable(p)]


def device_at(x, y):
    for p in devices():
        px, _ = cab.plug_pos(state.room, p)
        if abs(x - px) <= 60 and cab.PLUG_Y - 20 <= y <= DEV_Y + 60:
            return p
    return None


def on_down(x, y, button):
    global wiring, toast
    tab = ui.tab_at(x, y)
    if tab:
        ui.goto_tab(tab)
        return
    if inside(x, y, BTN_DONE):
        game_framework.change_mode(result_mode)
        return
    port = cab.port_at(x, y, state.pc)
    p = device_at(x, y)
    if button == SDL_BUTTON_RIGHT:  # 우클릭: 포트나 기기의 선 뽑기
        state.cables = [c for c in state.cables if (c['type'], c['port']) != port and c['dev'] is not p]
    elif p:
        state.cables = [c for c in state.cables if c['dev'] is not p]
        wiring, toast = p, ''


def on_up(x, y):
    global wiring, toast
    if not wiring:
        return
    need = ITEMS[wiring['id']]['port']
    port = cab.port_at(x, y, state.pc)
    if port and port[0] != need:
        toast = HINT[need] + ' 꽂아야 해요'
    elif port and any((c['type'], c['port']) == port for c in state.cables):
        toast = '이미 쓰고 있는 포트예요'
    elif port:
        state.cables.append({'dev': wiring, 'type': port[0], 'port': port[1]})
    wiring = None


def handle_event(e):
    if ui.tab_key(e):
        ui.goto_tab(ui.tab_key(e))
    elif e.type == SDL_KEYDOWN and e.key in (SDLK_c, SDLK_TAB):
        game_framework.change_mode(decorate_mode)
    elif e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        game_framework.change_mode(result_mode)
    elif e.type == SDL_MOUSEBUTTONDOWN:
        on_down(*game_framework.mouse, e.button)
    elif e.type == SDL_MOUSEBUTTONUP and e.button == SDL_BUTTON_LEFT:
        on_up(*game_framework.mouse)


def update():
    state.cables = cab.prune(state.cables, state.room, state.pc)


def thick_line(points, color):
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        for d in (-2, -1, 0, 1, 2):
            draw_line(x1, y1 + d, x2, y2 + d, *color)


def cable_points(a, b):
    """처지는 선: a → b 3차 베지어 (위아래로 늘어진 모양)."""
    (x0, y0), (x3, y3) = a, b
    mid = (y0 + y3) / 2
    pts = []
    for i in range(25):
        t = i / 24
        u = 1 - t
        pts.append((u ** 3 * x0 + 3 * u * u * t * x0 + 3 * u * t * t * x3 + t ** 3 * x3,
                    u ** 3 * y0 + 3 * u * u * t * mid + 3 * u * t * t * mid + t ** 3 * y3))
    return pts


def draw_ports():
    x1, y1, x2, y2 = cab.PANEL
    box(x1, y1, x2, y2, (14, 9, 30))
    outline(x1, y1, x2, y2)
    text(x1 + 12, y2 - 16, 'PC 후면 포트', 16, (170, 160, 220))
    used = {(c['type'], c['port']) for c in state.cables}
    for t in cab.ORDER:
        n = cab.port_count(t, state.pc)
        for i in range(3 if t == 'DP' else cab.PORT_COUNT[t]):
            px, py = cab.port_pos(t, i)
            color = cab.PORT_COLOR[t] if i < n else (60, 50, 90)
            box(px - 28, py - 18, px + 28, py + 18, color if (t, i) in used else (24, 16, 52))
            outline(px - 28, py - 18, px + 28, py + 18, color)
            box(px - 12, py - 5, px + 12, py + 5, (14, 9, 30))
        lx, _ = cab.port_pos(t, 0)
        label = cab.PORT_NAMES[t] + (' (GPU를 장착하세요)' if t == 'DP' and not n else '')
        text(lx - 28, y1 + 16, label, 16, cab.PORT_COLOR[t])


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    for gx in range(0, WIDTH, 40):
        draw_line(gx, 0, gx, HEIGHT - 70, 30, 22, 60)
    ui.top_bar()
    text(40, 610, '배선 정리  ·  책상 뒤', 24, (255, 77, 141))
    text(40, 578, '기기를 끌어 같은 색 포트에 꽂으세요. 선이 엇갈리면 꼬임 감점! (우클릭: 선 뽑기)', 15, (170, 160, 220))

    plugged = {id(c['dev']) for c in state.cables}
    for p in devices():
        x, y = cab.plug_pos(state.room, p)
        color = cab.PORT_COLOR[ITEMS[p['id']]['port']]
        box(x - 62, DEV_Y - 58, x + 62, DEV_Y + 58, (28, 20, 58))
        outline(x - 62, DEV_Y - 58, x + 62, DEV_Y + 58, color if id(p) in plugged else (90, 78, 130))
        draw_fit(p['id'], x, DEV_Y + 6, 100, 90)
        text(x - 56, DEV_Y - 46, ITEMS[p['id']]['name'], 13)
        draw_circle(x, y, 9, *color, 255, True)
    if not devices():
        text(360, 520, '책상 위에 모니터 · 키보드 · 스피커 같은 기기를 먼저 놓으세요', 18, (255, 214, 92))

    draw_ports()
    for c in state.cables:
        thick_line(cable_points(cab.plug_pos(state.room, c['dev']), cab.port_pos(c['type'], c['port'])), cab.PORT_COLOR[c['type']])
    if wiring:
        thick_line(cable_points(cab.plug_pos(state.room, wiring), game_framework.mouse), cab.PORT_COLOR[ITEMS[wiring['id']]['port']])

    _, unplugged, tangles = cab.wiring_score(state.cables, state.room)
    ok = not unplugged and not tangles
    text(880, 610, f"미연결 {unplugged}   꼬임 {tangles}", 22, (120, 255, 170) if ok else (255, 214, 92))
    if ok and devices():
        text(880, 578, "깔끔해요! 배선 만점", 16, (120, 255, 170))
    if toast:
        text(40, 80, toast, 18, (255, 77, 141))
    ui.work_tabs('wire')
    ui.button(BTN_DONE, '완료 [Enter]', (255, 77, 141))
