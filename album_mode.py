"""앨범: 납품할 때 자동으로 찍힌 책상 사진과 P 키로 찍은 사진을 모아 본다. 타이틀에서 열고 ESC로 닫는다."""
from pico2d import *

import game_framework
import photos
import ui
from common import WIDTH, HEIGHT, box, outline, text, inside

ESC = 'back'
COLS, ROWS, TW, TH = 3, 2, 370, 238
BTN_PREV, BTN_NEXT, BTN_BACK = (500, 20, 560, 60), (720, 20, 780, 60), (1060, 20, 1260, 60)
files, page, _imgs = [], 0, {}


def init():
    global files, page
    files, page = photos.listing(), 0


def finish():
    pass


def pages():
    return max(1, -(-len(files) // (COLS * ROWS)))


def thumb(i):
    x = 50 + (i % COLS) * (TW + 30)
    y2 = 620 - (i // COLS) * (TH + 50)
    return x, y2 - TH, x + TW, y2


def handle_event(e):
    global page
    if e.type != SDL_MOUSEBUTTONDOWN:
        return
    x, y = game_framework.mouse
    if inside(x, y, BTN_BACK):
        game_framework.pop_mode()
    elif inside(x, y, BTN_PREV):
        page = max(0, page - 1)
    elif inside(x, y, BTN_NEXT):
        page = min(pages() - 1, page + 1)


def update():
    pass


def draw():
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    text(50, 680, f"앨범  ·  사진 {len(files)}장", 26, (255, 77, 141))
    if not files:
        text(50, 600, '아직 사진이 없어요. 납품하면 자동으로 찍히고, 책상 화면에서 P를 누르면 직접 찍을 수 있어요.', 17, (170, 160, 220))
    per = COLS * ROWS
    for i, path in enumerate(files[page * per:(page + 1) * per]):
        if path not in _imgs:
            _imgs[path] = load_image(path)
        x1, y1, x2, y2 = thumb(i)
        _imgs[path].draw((x1 + x2) // 2, (y1 + y2) // 2, TW, TH)
        outline(x1, y1, x2, y2, (255, 77, 141))
        text(x1, y1 - 18, photos.caption(path), 15, (232, 226, 255))
    ui.button(BTN_PREV, '◀', (124, 92, 255))
    ui.button(BTN_NEXT, '▶', (124, 92, 255))
    text(600, 40, f"{page + 1} / {pages()}", 16, (170, 160, 220))
    ui.button(BTN_BACK, '돌아가기 [ESC]', (255, 77, 141))
