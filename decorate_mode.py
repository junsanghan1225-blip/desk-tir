"""책상 꾸미기 화면: 아침에 사 둔 재고에서 끌어다 벽 · 책상 위에 놓는다. 케이블은 배선 정리 화면(C)에서."""
from pico2d import *

import game_framework
import build_mode
import wire_mode
import result_mode
import state
import ui
import cables as cab
from common import WIDTH, HEIGHT, ITEMS, box, outline, text, to_canvas_y, inside, sprite, draw_fit
from room import LAYERS, LAYER_NAMES, SLOT_X0, SLOT_W, SLOT_COUNT, drop_target

SHOP_W, ROW_H, ROW_TOP = 270, 31, 600
PC_RECT = (1095, 210, 1255, 470)
BTN_PC = (930, 10, 1090, 50)
BTN_DONE = (1100, 10, 1270, 50)
BTN_CABLE = (760, 10, 920, 50)

held = None   # 끌고 있는 소품 id
mouse = (0, 0)
toast = ''


def init():
    global held, toast
    held, toast = None, ''


def finish():
    pass


def shop_ids():
    """보유 재고가 있는 소품만 진열 (재고 순서는 아이템 목록 순)."""
    return [i for i in ITEMS if state.stock.get(i, 0) > 0 or i == held]


def shop_row(i):
    y = ROW_TOP - i * ROW_H
    return 10, y - ROW_H + 4, SHOP_W - 10, y


def on_down(x, y, button):
    global held, toast
    if inside(x, y, BTN_CABLE):
        game_framework.change_mode(wire_mode)
        return
    if button == SDL_BUTTON_RIGHT:
        p = state.room.item_at(x, y)
        if p:
            state.room.placed.remove(p)
            state.give_back(p['id'])  # 재고로 돌아감
        return
    for i, item_id in enumerate(shop_ids()):
        if inside(x, y, shop_row(i)):
            if state.stock.get(item_id, 0) <= 0:
                toast = '재고가 없어요. 내일 아침 시장에서 사 두세요'
            elif ITEMS[item_id]['price'] > state.money_left():
                toast = '손님 예산을 넘어요!'
            else:
                held, toast = item_id, ''
            return
    p = state.room.item_at(x, y)
    if p:
        state.room.placed.remove(p)
        state.give_back(p['id'])
        held = p['id']
    elif inside(x, y, PC_RECT) or inside(x, y, BTN_PC):
        game_framework.change_mode(build_mode)
    elif inside(x, y, BTN_DONE):
        game_framework.change_mode(result_mode)


def on_up(x, y):
    global held, toast
    if not held:
        return
    target = drop_target(held, x, y)
    if target and state.room.fits(held, *target) and state.take(held):
        state.room.place(held, *target)
    elif target:
        toast = f"{ITEMS[held]['name']}은(는) '{LAYER_NAMES[ITEMS[held]['layer']]}'의 빈 칸에만 놓을 수 있어요"
    held = None


def handle_events():
    global mouse
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_KEYDOWN and e.key == SDLK_TAB:
            game_framework.change_mode(build_mode)
        elif e.type == SDL_KEYDOWN and e.key == SDLK_c:
            game_framework.change_mode(wire_mode)
        elif e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
            game_framework.change_mode(result_mode)
        elif e.type == SDL_MOUSEMOTION:
            mouse = (e.x, to_canvas_y(e.y))
        elif e.type == SDL_MOUSEBUTTONDOWN:
            mouse = (e.x, to_canvas_y(e.y))
            on_down(*mouse, e.button)
        elif e.type == SDL_MOUSEBUTTONUP and e.button == SDL_BUTTON_LEFT:
            on_up(e.x, to_canvas_y(e.y))


def update():
    state.cables = cab.prune(state.cables, state.room, state.pc)  # 치운 기기 · 사라진 포트의 선은 자동으로 뽑힘


def draw_sprite(item_id, x1, y1, x2, y2):
    """칸(rect) 안에 소품을 그린다. 책상 위는 상판에 붙이고, 벽은 가운데 정렬."""
    img = sprite(item_id)
    cx = (x1 + x2) // 2
    layer = ITEMS[item_id]['layer']
    if layer == 'wall':
        img.draw(cx, (y1 + y2) // 2)
    else:
        img.draw(cx, y1 + img.h // 2)


def draw_room():
    sprite('room_bg').draw(SHOP_W + (WIDTH - SHOP_W) // 2, (HEIGHT - 70) // 2)
    by_layer = lambda *layers: [p for p in state.room.placed if p['layer'] in layers]
    for p in by_layer('wall') + by_layer('desk'):
        draw_sprite(p['id'], *state.room.rect(p))
    case = state.pc.get('CASE')
    img = sprite(case or 'case_empty')
    img.draw((PC_RECT[0] + PC_RECT[2]) // 2, PC_RECT[1] + img.h // 2)
    label = '부팅 OK' if state.pc.boots() else 'PC 조립 필요'
    text(PC_RECT[0] + 20, PC_RECT[3] + 16, label, 14, (46, 230, 214))
    if held:
        bottom, h = LAYERS[ITEMS[held]['layer']]
        for s in range(SLOT_COUNT):
            if state.room.fits(held, ITEMS[held]['layer'], s):  # 놓을 수 있는 칸만 표시
                outline(SLOT_X0 + s * SLOT_W + 4, bottom, SLOT_X0 + (s + 1) * SLOT_W - 4, bottom + h, (46, 230, 214))


def draw_unplugged():
    """케이블이 안 꽂힌 기기 위에 깜빡이는 점 (배선은 배선 정리 화면에서)."""
    if int(get_time() * 3) % 2:
        plugged = {id(c['dev']) for c in state.cables}
        for p in state.room.placed:
            if cab.needs_cable(p) and id(p) not in plugged:
                x1, y1, x2, _ = state.room.rect(p)
                draw_circle((x1 + x2) // 2, y1 + 8, 6, 255, 77, 141, 255, True)


def draw_shop():
    box(0, 0, SHOP_W, HEIGHT - 70, (34, 24, 70))
    text(14, ROW_TOP + 20, '창고 재고  (드래그해서 배치)', 18)
    left = state.money_left()
    if not shop_ids():
        text(14, ROW_TOP - 20, '소품 재고가 없어요', 15, (140, 128, 200))
    for i, item_id in enumerate(shop_ids()):
        it = ITEMS[item_id]
        x1, y1, x2, y2 = shop_row(i)
        dim = it['price'] > left
        draw_fit(item_id, x1 + 14, (y1 + y2) // 2, 28, 25)
        text(x1 + 34, (y1 + y2) // 2, it['name'], 15, (90, 78, 130) if dim else (232, 226, 255))
        text(x2 - 96, (y1 + y2) // 2, f"{it['price']}만 · x{state.stock.get(item_id, 0)}", 13, (140, 128, 200))


def draw():
    clear_canvas()
    draw_room()
    draw_unplugged()
    draw_shop()
    ui.top_bar()
    ui.button(BTN_PC, 'PC 조립 [Tab]')
    ui.button(BTN_DONE, '완료 [Enter]', (255, 77, 141))
    _, unplugged, tangles = cab.wiring_score(state.cables, state.room)
    ui.button(BTN_CABLE, f"배선 [C]  {'!' if unplugged or tangles else 'OK'}", (124, 92, 255))
    text(SHOP_W + 10, 30, '우클릭: 창고로 되돌리기', 14, (170, 160, 220))
    if toast:
        text(SHOP_W + 10, 62, toast, 16, (255, 77, 141))
    if held:
        x, y = mouse
        sprite(held).draw(x, y)
    update_canvas()
