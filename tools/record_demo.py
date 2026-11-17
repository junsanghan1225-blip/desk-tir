"""발표용 데모 영상 녹화: 실제 게임 루프에 사람처럼 천천히 움직이는 마우스 입력을 넣고, 매 프레임을 30fps 영상으로 저장.
    python tools/record_demo.py 출력.mp4
화면 없이(SDL dummy) 돌고, 게임 시간도 영상 시간(1/30초)에 맞춰 흐르게 한다. 마우스 커서는 그려 넣는다."""
import ctypes, os, subprocess, sys, tempfile, types

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, ROOT)
os.chdir(ROOT)
os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['SDL_AUDIODRIVER'] = 'dummy'
os.environ['DESK_TIR_SAVE'] = os.path.join(tempfile.mkdtemp(), 'save.json')
OUT = sys.argv[1]
FPS = 30

import pico2d.pico2d as p2
from pico2d import *
from sdl2 import SDL_RenderReadPixels, SDL_PIXELFORMAT_RGB24, SDL_CreateRenderer
from PIL import Image, ImageDraw

open_canvas(1280, 720)
if not p2.renderer:
    p2.renderer = SDL_CreateRenderer(p2.window, -1, 0)

import game_framework as gf
import build_mode as bm, decorate_mode as dm, pause_mode, product_mode, save_game, shop_mode, state, title_mode, ui
import cables as cab
from common import ITEMS, PARTS
from room import DESK_Y

H = 720
gf.pause_mode, gf.on_change = pause_mode, save_game.save
clock = [0.0]   # 게임 시간 = 영상 시간
gf.time = types.SimpleNamespace(time=lambda: clock[0], sleep=lambda s: None)


class Ev:
    def __init__(self, type, key=0, x=0, y=0, button=SDL_BUTTON_LEFT):
        self.type, self.key, self.x, self.y, self.button = type, key, x, y, button


mouse = [640.0, 360.0]


def ev_move(x, y):
    mouse[:] = [x, y]
    return Ev(SDL_MOUSEMOTION, x=int(x), y=int(H - 1 - y))


def wait(sec):
    for _ in range(int(sec * FPS)):
        yield []


def glide(x, y, sec=0.35):
    """현재 위치에서 (x, y)까지 부드럽게 이동."""
    x0, y0 = mouse
    n = max(1, int(sec * FPS))
    for i in range(1, n + 1):
        t = i / n
        t = t * t * (3 - 2 * t)
        yield [ev_move(x0 + (x - x0) * t, y0 + (y - y0) * t)]


def click(x, y, b=SDL_BUTTON_LEFT, after=0.25):
    yield from glide(x, y)
    yield [Ev(SDL_MOUSEBUTTONDOWN, x=int(x), y=int(H - 1 - y), button=b)]
    yield [Ev(SDL_MOUSEBUTTONUP, x=int(x), y=int(H - 1 - y))]
    yield from wait(after)


def drag(a, b, sec=0.5, after=0.25):
    yield from glide(*a)
    yield [Ev(SDL_MOUSEBUTTONDOWN, x=int(a[0]), y=int(H - 1 - a[1]))]
    yield from glide(*b, sec=sec)
    yield [Ev(SDL_MOUSEBUTTONUP, x=int(b[0]), y=int(H - 1 - b[1]))]
    yield from wait(after)


def key(k, after=0.3):
    yield [Ev(SDL_KEYDOWN, k)]
    yield from wait(after)


def c(r):
    return (r[0] + r[2]) // 2, (r[1] + r[3]) // 2


def open_cat(tid):
    p = ITEMS.get(tid) or PARTS[tid]
    cat = p['cat'] if tid in ITEMS else 'parts'
    yield from click(*c(shop_mode.cat_rect([k for k, _ in shop_mode.CATS].index(cat))), after=0.15)
    if cat == 'parts':
        yield from click(*c(shop_mode.sub_rect([k for k, _ in shop_mode.PART_TYPES].index(p['type']))), after=0.15)
    while tid not in shop_mode.visible():
        yield from click(*c(shop_mode.BTN_NEXT), after=0.1)


def quick_buy(tid):
    """우클릭 = 바로 담기 (빠르게 여러 개)."""
    yield from open_cat(tid)
    yield from click(*c(shop_mode.card_rect(shop_mode.visible().index(tid))), b=SDL_BUTTON_RIGHT, after=0.15)


def plan():
    yield from wait(1.5)                                   # 타이틀
    yield from key(SDLK_RETURN, after=2.0)                 # 하루 뉴스
    yield from click(640, 360, after=3.0)                  # 손님: 애매한 주문
    yield from click(640, 360, after=0.6)                  # → 쇼핑
    yield from open_cat('lamp_warm')                       # 상품 상세 페이지 보고 담기
    yield from click(*c(shop_mode.card_rect(shop_mode.visible().index('lamp_warm'))), after=1.2)
    yield from click(*c(product_mode.BTN_ADD), after=0.4)
    for tid in ['book', 'mug', 'monitor', 'mini_plant', 'wall_light', 'case5', 'mb1', 'cpu1', 'cool1', 'ram1', 'ssd1', 'gpu1', 'psu1']:
        yield from quick_buy(tid)
    yield from wait(0.6)
    yield from key(SDLK_RETURN, after=1.6)                 # 결제 → 영수증
    yield from key(SDLK_RETURN, after=0.3)
    yield from key(SDLK_2, after=0.5)                      # 책상
    for iid, x in [('monitor', 640), ('lamp_warm', 360), ('book', 470), ('mini_plant', 820), ('mug', 950)]:   # 스탠드 옆에 책 = 독서 콤보
        yield from drag(c(dm.shop_row(dm.shop_ids().index(iid))), (x, DESK_Y + 60))
    yield from drag(c(dm.shop_row(dm.shop_ids().index('wall_light'))), (430, 520))   # 벽 조명 + 스탠드 = 균형 조명
    mug = next(p for p in state.room.placed if p['id'] == 'mug')
    yield from click(*c(state.room.rect(mug)), after=0.4)  # 선택 → 색 바꾸기
    yield from click(*c(dm.chip_rect(mug, 2)), after=0.4)
    yield from click(*c(dm.chip_rect(mug, 3)), after=0.8)
    yield from click(*c(ui.tab_rect(2)), after=0.6)        # PC 조립

    def put(pid, zone, after=0.25):
        yield from drag(c(bm.inv_row(bm.inv_ids().index(pid))), c(zone()), after=after)
    yield from put('case5', lambda: bm.CASE_AREA)
    yield from put('mb1', bm.mb_rect)
    yield from put('cpu1', bm.cpu_rect, after=1.0)          # 레버를 안 열면 안 들어감
    yield from click(*c(bm.lever_rect()), after=0.3)
    yield from put('cpu1', bm.cpu_rect)
    yield from click(*c(bm.lever_rect()), after=0.3)
    yield from drag(c(bm.PASTE_ROW), c(bm.cpu_rect()))
    yield from put('cool1', bm.cooler_rect)
    yield from put('ram1', lambda: bm.ram_rect(0))
    yield from put('ssd1', bm.ssd_rect)
    yield from put('gpu1', bm.gpu_rect)
    yield from put('psu1', lambda: bm.PSU_BAY)
    for name in ['24pin', 'cpu8']:
        yield from drag(c(bm.psu_port(name)), c(bm.socket_rect(name)))
    yield from drag(c(bm.FRONT_SRC), c(bm.socket_rect('front')), after=0.4)
    yield from key(SDLK_SPACE, after=4.5)                  # 전원 → 바이오스 → 바탕화면
    yield from key(SDLK_SPACE, after=0.4)
    yield from key(SDLK_4, after=0.5)                      # 배선
    for iid, port in [('monitor', ('DP', 0))]:
        p = next(q for q in state.room.placed if q['id'] == iid)
        yield from drag(cab.plug_pos(state.room, p), cab.port_pos(*port), sec=0.6, after=0.4)
    yield from wait(0.6)
    yield from key(SDLK_RETURN, after=3.5)                 # 납품 → 별점 · 손님 반응 · 숨은 조건 공개
    yield [Ev(SDL_QUIT)]


steps = plan()


def fake_events():
    try:
        return next(steps)
    except StopIteration:
        return [Ev(SDL_QUIT)]


ff = subprocess.Popen(['ffmpeg', '-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', '1280x720', '-r', str(FPS), '-i', '-',
                       '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '16', OUT], stdin=subprocess.PIPE)
real_update = gf.update_canvas
ARROW = [(0, 0), (0, 22), (6, 17), (10, 26), (14, 24), (10, 15), (17, 15)]


def capture():
    buf = (ctypes.c_ubyte * (1280 * 720 * 3))()
    SDL_RenderReadPixels(p2.renderer, None, SDL_PIXELFORMAT_RGB24, buf, 1280 * 3)
    img = Image.frombytes('RGB', (1280, 720), bytes(buf))
    mx, my = mouse[0], H - 1 - mouse[1]
    ImageDraw.Draw(img).polygon([(mx + x, my + y) for x, y in ARROW], fill=(255, 255, 255), outline=(0, 0, 0))
    ff.stdin.write(img.tobytes())
    clock[0] += 1 / FPS
    real_update()


gf.get_events, gf.update_canvas, gf.FPS = fake_events, capture, 1000
gf.run(title_mode, H)
ff.stdin.close()
ff.wait()
import result_mode
print(f'녹화 끝: {clock[0]:.1f}초 → {OUT}  ·  결과 {result_mode.result}')
