"""책상 꾸미기 화면: 창고 재고에서 끌어다 벽 · 책상 위에 자유롭게 놓는다 (같은 레이어끼리만 안 겹치면 됨).
놓인 소품을 클릭하면 선택되고, 색을 바꿀 수 있는 소품은 색 칩이 뜬다. P = 사진 찍기. 케이블은 배선 탭에서."""
from pico2d import *

import game_framework
import photos
import sound
import state
import ui
import cables as cab
from common import WIDTH, HEIGHT, ITEMS, box, outline, text, inside, sprite, draw_fit
from room import LAYER_NAMES, COLORS, drop_target, size_of

SHOP_W, ROW_H, ROW_TOP = 270, 31, 600
ROOM_RECT = (SHOP_W, 0, WIDTH, HEIGHT - 70)
PC_RECT = (1095, 210, 1255, 470)
BTN_DONE = (1100, 10, 1270, 50)
PER_PAGE = 16
BTN_PREV, BTN_NEXT = (14, 66, 64, 96), (206, 66, 256, 96)

held = None      # 끌고 있는 소품 id
moving = None    # 책상에서 집어 든 소품 (실패하면 제자리 그대로, 케이블 연결도 유지)
origin = None    # 집어 든 순간의 마우스 위치
selected = None  # 클릭해서 고른 소품 (색 바꾸기)
toast = ''
page = 0


def init():
    global held, moving, selected, toast
    held, moving, selected, toast = None, None, None, ''


def finish():
    pass


def art(p):
    """놓인 소품의 그림 이름 (색을 바꿨으면 그 색 그림)."""
    return p['id'] + (f"__c{p['color']}" if p.get('color') else '')


def all_ids():
    """창고에 있는 소품 (아이템 목록 순)."""
    return [i for i in ITEMS if state.stock.get(i, 0) > 0 or (i == held and not moving)]


def shop_ids():
    return all_ids()[page * PER_PAGE:(page + 1) * PER_PAGE]


def shop_row(i):
    y = ROW_TOP - i * ROW_H
    return 10, y - ROW_H + 4, SHOP_W - 10, y


def chip_rect(p, k):
    x1, _, x2, y2 = state.room.rect(p)
    cx = (x1 + x2) // 2 - (COLORS * 40) // 2 + k * 40
    y = min(y2 + 8, HEIGHT - 70 - 40)
    return cx, y, cx + 36, y + 36


def snapshot(name=None):
    """방만 다시 그려서 사진으로 저장 (UI 없이)."""
    draw_room(clean=True)
    return photos.capture(ROOM_RECT, name)


def deliver():
    """납품: 책상 사진을 앨범에 남기고 결과 화면으로."""
    import result_mode
    if state.room.placed:
        snapshot(f"day{state.day}_{state.order_index + 1}_{state.request()['face']}")
    game_framework.change_mode(result_mode)


def on_down(x, y, button):
    global held, toast, page, moving, origin, selected
    if inside(x, y, BTN_PREV) or inside(x, y, BTN_NEXT):
        last = max(0, (len(all_ids()) - 1) // PER_PAGE)
        page = max(0, page - 1) if inside(x, y, BTN_PREV) else min(last, page + 1)
        return
    tab = ui.tab_at(x, y)
    if tab:
        ui.goto_tab(tab)
        return
    if inside(x, y, BTN_DONE):
        deliver()
        return
    if selected and ITEMS[selected['id']].get('tint') and button == SDL_BUTTON_LEFT:
        for k in range(COLORS):
            if inside(x, y, chip_rect(selected, k)):
                selected['color'] = k
                sound.play('click')
                return
    if button == SDL_BUTTON_RIGHT:
        p = state.room.item_at(x, y)
        if p:
            state.room.placed.remove(p)
            state.give_back(p['id'])  # 창고로 돌아감
            selected = None
            sound.play('pick')
        return
    for i, item_id in enumerate(shop_ids()):
        if inside(x, y, shop_row(i)):
            if ITEMS[item_id]['price'] > state.money_left():
                toast = '손님 예산을 넘어요!'
                sound.play('error')
            else:
                held, moving, selected, toast = item_id, None, None, ''
                sound.play('pick')
            return
    p = state.room.item_at(x, y)
    if p:
        held, moving, origin = p['id'], p, (x, y)
        sound.play('pick')
    else:
        selected = None
        if inside(x, y, PC_RECT):
            ui.goto_tab('build')


def on_up(x, y):
    global held, toast, moving, selected
    if not held:
        return
    if moving and abs(x - origin[0]) + abs(y - origin[1]) < 6:  # 움직이지 않은 클릭 = 선택
        selected = None if selected is moving else moving
        held, moving = None, None
        return
    target = drop_target(held, x, y)
    ok = target and state.room.fits_at(held, *target, ignore=moving)
    if moving:  # 옮기기: 같은 항목을 새 자리로, 실패하면 원래 자리 그대로
        if ok:
            moving['x'], moving['y'] = target[1], target[2]
            sound.play('place')
        else:
            toast = '그 자리엔 못 놓아서 원래 자리에 뒀어요'
            sound.play('error')
    elif ok and state.take(held):
        selected = state.room.place_at(held, *target)
        toast = ''
        sound.play('place')
    elif target or inside(x, y, ROOM_RECT):
        toast = f"{ITEMS[held]['name']}은(는) '{LAYER_NAMES[ITEMS[held]['layer']]}'의 빈 곳에 놓아 주세요"
        sound.play('error')
    held, moving = None, None


def handle_event(e):
    global toast
    if ui.tab_key(e):
        ui.goto_tab(ui.tab_key(e))
    elif e.type == SDL_KEYDOWN and e.key == SDLK_p:
        ok = snapshot()
        sound.play('photo')
        toast = '사진을 앨범에 저장했어요 (타이틀 → 앨범)' if ok else '사진을 저장하지 못했어요'
    elif e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        deliver()
    elif e.type == SDL_MOUSEBUTTONDOWN:
        on_down(*game_framework.mouse, e.button)
    elif e.type == SDL_MOUSEBUTTONUP and e.button == SDL_BUTTON_LEFT:
        on_up(*game_framework.mouse)


def update():
    state.cables = cab.prune(state.cables, state.room, state.pc)  # 치운 기기 · 사라진 포트의 선은 자동으로 뽑힘


def draw_room(clean=False):
    """방 · 소품 · PC. clean이면 사진용: 끌고 있는 것 · 안내선 없이."""
    sprite('room_bg_' + state.today()['weather']).draw(SHOP_W + (WIDTH - SHOP_W) // 2, (HEIGHT - 70) // 2)
    for p in sorted(state.room.placed, key=lambda p: p['layer'] == 'desk'):  # 벽 먼저, 책상 위가 앞
        if p is moving and not clean:
            continue
        x1, y1, x2, y2 = state.room.rect(p)
        sprite(art(p)).draw((x1 + x2) // 2, (y1 + y2) // 2)
    case = state.pc.get('CASE')
    if case or not clean:
        img = sprite(case or 'case_empty')
        img.draw((PC_RECT[0] + PC_RECT[2]) // 2, PC_RECT[1] + img.h // 2)
    if clean:
        return
    text(PC_RECT[0] + 20, PC_RECT[3] + 16, '부팅 OK' if state.pc.boots() else 'PC 조립 필요', 14, (46, 230, 214))
    if held:  # 놓일 자리 미리 보기
        target = drop_target(held, *game_framework.mouse)
        if target:
            w, h = size_of(held)
            ok = state.room.fits_at(held, *target, ignore=moving)
            outline(target[1], target[2], target[1] + w, target[2] + h, (46, 230, 214) if ok else (255, 77, 141))
    if selected and selected in state.room.placed:
        outline(*state.room.rect(selected), (255, 214, 92))
        if ITEMS[selected['id']].get('tint'):
            for k in range(COLORS):
                r = chip_rect(selected, k)
                box(*r, (24, 16, 52))
                outline(*r, (255, 214, 92) if selected.get('color', 0) == k else (124, 92, 255))
                draw_fit(selected['id'] + (f"__c{k}" if k else ''), (r[0] + r[2]) // 2, (r[1] + r[3]) // 2, 30, 30)


def draw_unplugged():
    """케이블이 안 꽂힌 기기 위에 깜빡이는 점 (배선은 배선 탭에서)."""
    if int(get_time() * 3) % 2:
        plugged = {id(c['dev']) for c in state.cables}
        for p in state.room.placed:
            if cab.needs_cable(p) and id(p) not in plugged and p is not moving:
                x1, y1, x2, _ = state.room.rect(p)
                draw_circle((x1 + x2) // 2, y1 + 8, 6, 255, 77, 141, 255, True)


def draw_shop():
    box(0, 0, SHOP_W, HEIGHT - 70, (34, 24, 70))
    text(14, ROW_TOP + 20, '창고 재고  (드래그해서 배치)', 18)
    left = state.money_left()
    if not shop_ids():
        text(14, ROW_TOP - 20, '소품 재고가 없어요', 15, (140, 128, 200))
        text(14, ROW_TOP - 44, '쇼핑 탭(1)에서 사 오세요', 13, (90, 78, 130))
    total = len(all_ids())
    if total > PER_PAGE:
        ui.button(BTN_PREV, '▲', (124, 92, 255))
        ui.button(BTN_NEXT, '▼', (124, 92, 255))
        text(92, 81, f"{page + 1}/{(total - 1) // PER_PAGE + 1}", 13, (170, 160, 220))
    for i, item_id in enumerate(shop_ids()):
        it = ITEMS[item_id]
        x1, y1, x2, y2 = shop_row(i)
        draw_fit(item_id, x1 + 14, (y1 + y2) // 2, 28, 25)
        text(x1 + 34, (y1 + y2) // 2, it['name'], 15, (90, 78, 130) if it['price'] > left else (232, 226, 255))
        text(x2 - 96, (y1 + y2) // 2, f"{it['price']}만 · x{state.stock.get(item_id, 0)}", 13, (140, 128, 200))


def draw():
    draw_room()
    draw_unplugged()
    draw_shop()
    ui.top_bar()
    ui.button(BTN_DONE, '완료 [Enter]', (255, 77, 141))
    ui.work_tabs('decorate')
    text(SHOP_W + 10, 30, '클릭: 선택 · 색 바꾸기   우클릭: 창고로   P: 사진', 14, (170, 160, 220))
    if toast:
        text(SHOP_W + 10, 62, toast, 16, (255, 77, 141))
    if held:
        x, y = game_framework.mouse
        sprite(art(moving) if moving else held).draw(x, y)
