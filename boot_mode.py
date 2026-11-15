"""부팅 연출 (PC 조립 화면 위에 겹쳐 뜸): 전원 테스트 성공 → 바이오스 글자가 한 줄씩 → 바탕화면. 클릭 · 아무 키로 닫기."""
from pico2d import *

import game_framework
import state
from common import WIDTH, HEIGHT, PARTS, box, outline, text, sprite

OVERLAY = True
ESC = 'back'
SCREEN = (240, 110, 1040, 610)
STEP = 0.35  # 바이오스 한 줄이 뜨는 간격(초)
t = 0.0


def init():
    global t
    t = 0.0


def finish():
    pass


def lines():
    pc = state.pc
    ram = ' + '.join(PARTS[r]['name'].replace('RAM ', '') for r in pc.ram if r)
    return ['DESK-BIOS v1.0', f"CPU   {pc.spec('CPU')['name']} ... OK", f"RAM   {ram}{' (듀얼 채널)' if pc.dual_channel() else ''} ... OK",
            f"VGA   {pc.spec('GPU')['name']} ... OK", f"M.2   {pc.spec('SSD')['name']} ... OK", '부팅 중 ...']


def handle_event(e):
    if e.type in (SDL_MOUSEBUTTONDOWN, SDL_KEYDOWN) and t > 0.3:
        game_framework.pop_mode()


def update():
    global t
    t += game_framework.frame_time


def draw():
    x1, y1, x2, y2 = SCREEN
    box(0, 0, WIDTH, HEIGHT, (10, 6, 22), 170)
    box(x1 - 14, y1 - 14, x2 + 14, y2 + 14, (30, 26, 50))   # 모니터 테두리
    box(x1, y1, x2, y2, (4, 4, 10))
    bios = lines()
    if t < STEP * (len(bios) + 1.5):
        for i, line in enumerate(bios[:int(t / STEP) + 1]):
            text(x1 + 30, y2 - 40 - i * 34, line, 18, (120, 255, 170))
        return
    sprite('title_bg').draw((x1 + x2) // 2, (y1 + y2) // 2, x2 - x1, y2 - y1)   # 바탕화면
    for i, (name, color) in enumerate([('내 PC', (46, 230, 214)), ('게임', (255, 77, 141)), ('작업', (255, 214, 92))]):
        box(x1 + 30, y2 - 90 - i * 90, x1 + 80, y2 - 40 - i * 90, color)
        text(x1 + 28, y2 - 104 - i * 90, name, 13, (255, 255, 255))
    box(x1, y1, x2, y1 + 36, (18, 12, 38))
    text(x1 + 14, y1 + 18, f"성능 {'★' * state.pc.stars() or '-'}  ·  전력 {state.pc.watt()}W / {state.pc.capacity()}W", 15, (232, 226, 255))
    text(x2 - 180, y1 + 18, '클릭해서 닫기', 15, (170, 160, 220))
