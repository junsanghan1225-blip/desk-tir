"""전체 플레이 자동 테스트: 실제 게임 루프에 마우스 · 키 입력을 순서대로 넣어 하루 영업을 끝까지 돌린다.
    python tools/smoke_test.py            # 확인만
    python tools/smoke_test.py docs/screens   # 화면 캡처도 저장
창 없이 돌고(SDL dummy), 저장 파일은 임시 폴더를 쓴다."""
import ctypes, os, sys, tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
sys.path.insert(0, ROOT)
os.chdir(ROOT)
os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['DESK_TIR_SAVE'] = os.path.join(tempfile.mkdtemp(), 'save.json')
OUT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else None

import pico2d.pico2d as p2
from pico2d import *
from sdl2 import SDL_RenderReadPixels, SDL_PIXELFORMAT_RGB24, SDL_CreateRenderer

open_canvas(1280, 720)
if not p2.renderer:
    p2.renderer = SDL_CreateRenderer(p2.window, -1, 0)

import game_framework as gf
import album_mode, boot_mode, build_mode as bm, day_end_mode, decorate_mode as dm, news_mode, pause_mode, photos, product_mode
import receipt_mode, request_mode, result_mode, save_game, shop_mode, state, title_mode, ui, wire_mode
import cables as cab
from common import ITEMS, PARTS
from room import DESK_Y

H = 720
gf.pause_mode, gf.on_change = pause_mode, save_game.save


class Ev:
    def __init__(self, type, key=0, x=0, y=0, button=SDL_BUTTON_LEFT):
        self.type, self.key, self.x, self.y, self.button = type, key, x, y, button


def key(k): return [Ev(SDL_KEYDOWN, k)]
def move(x, y): return [Ev(SDL_MOUSEMOTION, x=int(x), y=int(H - 1 - y))]
def down(x, y, b=SDL_BUTTON_LEFT): return move(x, y) + [Ev(SDL_MOUSEBUTTONDOWN, x=int(x), y=int(H - 1 - y), button=b)]
def up(x, y): return move(x, y) + [Ev(SDL_MOUSEBUTTONUP, x=int(x), y=int(H - 1 - y))]
def click(x, y, b=SDL_BUTTON_LEFT): return down(x, y, b) + up(x, y)
def drag(a, b): return down(*a) + up(*b)
def c(r): return (r[0] + r[2]) // 2, (r[1] + r[3]) // 2
def shot(name): return [('snap', name)]
def check(fn, msg): return [('check', fn, msg)]


def buy(tid, n=1):
    """카테고리 → (부품이면 종류) → 상품 카드 → 상세 페이지 → 수량 → 담기."""
    p = ITEMS.get(tid) or PARTS[tid]
    cat = p['cat'] if tid in ITEMS else 'parts'
    yield click(*c(shop_mode.cat_rect([k for k, _ in shop_mode.CATS].index(cat))))
    if cat == 'parts':
        yield click(*c(shop_mode.sub_rect([k for k, _ in shop_mode.PART_TYPES].index(p['type']))))
    while tid not in shop_mode.visible():
        yield click(*c(shop_mode.BTN_NEXT))
    yield click(*c(shop_mode.card_rect(shop_mode.visible().index(tid))))
    for _ in range(n - 1):
        yield click(*c(product_mode.BTN_PLUS))
    yield click(*c(product_mode.BTN_ADD))
    yield check(lambda: gf.top() is shop_mode and state.cart.get(tid) == n, f'장바구니 {tid} x{n}')


def plan():
    yield shot('1_title')
    yield key(SDLK_RETURN)
    yield check(lambda: gf.top() is news_mode, '타이틀 → 하루 뉴스')
    yield shot('0_news')
    yield click(640, 360)
    yield check(lambda: gf.top() is request_mode, '뉴스 → 손님')
    yield shot('2_request')
    yield click(640, 360)
    yield check(lambda: gf.top() is shop_mode, '손님 → 쇼핑')
    for tid, n in [('lamp_warm', 1), ('book', 1), ('mug', 1), ('mood_lamp', 1), ('monitor', 1), ('case1', 1), ('mb1', 1), ('cpu1', 1),
                   ('cool1', 1), ('ram1', 1), ('ssd1', 1), ('gpu1', 1), ('psu1', 1)]:
        yield from buy(tid, n)
    yield shot('9_shop')
    yield key(SDLK_RETURN)
    yield check(lambda: gf.top() is receipt_mode and state.stock['monitor'] == 1 and not state.cart, '결제 → 영수증 · 창고 도착')
    yield key(SDLK_RETURN)
    yield key(SDLK_2)
    yield check(lambda: gf.top() is dm, '2 → 책상')
    for iid, x in [('lamp_warm', 360), ('book', 480), ('monitor', 640), ('mug', 800), ('mood_lamp', 900)]:   # 자유 위치에 놓기
        yield drag(c(dm.shop_row(dm.shop_ids().index(iid))), (x, DESK_Y + 60))
    yield check(lambda: len(state.room.placed) == 5 and not dm.toast, '소품 5개 자유 배치 ' + dm.toast)
    mug = next(p for p in state.room.placed if p['id'] == 'mug')
    lamp = next(p for p in state.room.placed if p['id'] == 'lamp_warm')
    yield click(*c(state.room.rect(mug)))
    yield check(lambda: dm.selected is mug, '클릭해서 선택')
    yield click(*c(dm.chip_rect(mug, 2)))
    yield check(lambda: mug.get('color') == 2, '색 바꾸기')
    yield drag(c(state.room.rect(lamp)), (1000, DESK_Y + 60))
    yield check(lambda: lamp['x'] > 900, '놓인 소품 옮기기')
    yield drag(c(state.room.rect(lamp)), (640, DESK_Y + 60))
    yield check(lambda: lamp['x'] > 900 and '원래 자리' in dm.toast, '겹치는 곳에 놓으면 제자리')
    yield shot('3_decorate')
    yield key(SDLK_p)
    yield check(lambda: len(photos.listing()) == 1, 'P → 사진 저장')
    yield key(SDLK_ESCAPE)
    yield check(lambda: gf.stack[-2:] == [dm, pause_mode], 'ESC → 일시정지')
    yield shot('8_pause')
    yield key(SDLK_ESCAPE)
    yield click(*c(ui.tab_rect(2)))
    yield check(lambda: gf.top() is bm, '탭 → PC 조립')

    def put(pid, zone):
        yield drag(c(bm.inv_row(bm.inv_ids().index(pid))), c(zone()))
    yield from put('case1', lambda: bm.CASE_AREA)
    yield from put('mb1', bm.mb_rect)
    yield from put('cpu1', bm.cpu_rect)
    yield check(lambda: '레버' in bm.toast and not state.pc.get('CPU'), '레버를 열어야 CPU가 들어감')
    yield click(*c(bm.lever_rect()))
    yield from put('cpu1', bm.cpu_rect)
    yield click(*c(bm.lever_rect()))
    yield drag(c(bm.PASTE_ROW), c(bm.cpu_rect()))
    yield from put('cool1', bm.cooler_rect)
    yield from put('ram1', lambda: bm.ram_rect(0))
    yield from put('ssd1', bm.ssd_rect)
    yield from put('gpu1', bm.gpu_rect)
    yield from put('psu1', lambda: bm.PSU_BAY)
    for name in ['24pin', 'cpu8']:
        yield drag(c(bm.psu_port(name)), c(bm.socket_rect(name)))
    yield key(SDLK_SPACE)
    yield check(lambda: bm.post_result[0] == -1 and gf.top() is bm, '전원 버튼선 없으면 반응 없음')
    yield drag(c(bm.FRONT_SRC), c(bm.socket_rect('front')))
    yield key(SDLK_SPACE)
    yield check(lambda: bm.post_result[0] == 4 and gf.top() is boot_mode, '부팅 성공 → 부팅 화면')
    yield shot('5d_boot_bios')
    for _ in range(330):   # 바이오스 글자가 다 지나갈 때까지
        yield []
    yield shot('5e_boot_desktop')
    yield key(SDLK_SPACE)
    yield check(lambda: gf.top() is bm, '부팅 화면 닫기')
    yield shot('5_build_ok')
    yield key(SDLK_4)
    mon = next(p for p in state.room.placed if p['id'] == 'monitor')
    yield drag(cab.plug_pos(state.room, mon), cab.port_pos('DP', 0))
    yield check(lambda: cab.wiring_score(state.cables, state.room)[1:] == (0, 0), '배선 완료')
    yield shot('3b_cable')
    yield key(SDLK_RETURN)
    yield check(lambda: gf.top() is result_mode and len(photos.listing()) == 2, '납품 → 결과 · 자동 사진')
    yield shot('6_result')
    yield check(lambda: result_mode.result['stars'] >= 2 and state.money > 200 - 107, f"별 {result_mode.result['stars']}개 · 대금 받음")
    for _ in range(2):   # 나머지 두 손님은 빈손 납품
        yield click(640, 360)
        yield click(640, 360)
        yield key(SDLK_2)
        yield key(SDLK_RETURN)
        yield check(lambda: result_mode.pay == 0, '빈손 납품은 0원')
    yield click(640, 360)
    yield check(lambda: gf.top() is day_end_mode, '영업 마감')
    yield shot('7_day_end')
    yield key(SDLK_RETURN)
    yield check(lambda: gf.top() is news_mode and state.day == 2 and state.today()['weather'] == 'sunset', '다음 날 뉴스 (노을)')
    yield key(SDLK_ESCAPE)
    yield click(*c(pause_mode.btn_rect(1)))
    yield check(lambda: gf.top() is title_mode and title_mode.saved['day'] == 2, '타이틀: 이어하기 2일차')
    yield click(*c(title_mode.BTN_ALBUM))
    yield check(lambda: gf.top() is album_mode and len(album_mode.files) == 2, '앨범에 사진 2장')
    yield shot('9_album')
    yield key(SDLK_ESCAPE)
    yield key(SDLK_RETURN)
    yield check(lambda: gf.top() is news_mode and state.history.get('자취 1년차 대학생', 0) >= 2, '이어하기 → 2일차 · 단골 기록 유지')
    # 4일차 단골: 지난번 별점에 따라 웃는 얼굴 + 좋은 기억 대사
    state.day, state.order_index = 4, 0
    yield click(640, 360)
    yield check(lambda: request_mode.mood() == 'happy' and '학점' in state.lines()[0], '단골 손님 대사')
    yield shot('2b_regular')
    yield [('quit',)]


steps, snaps, passed = plan(), [], 0


def fake_events():
    global passed
    evs = []
    for s in next(steps, [('quit',)]):
        if not isinstance(s, tuple):
            evs.append(s)
        elif s[0] == 'snap':
            snaps.append(s[1])
        elif s[0] == 'check':
            assert s[1](), '실패: ' + s[2]
            passed += 1
        else:
            evs.append(Ev(SDL_QUIT))
    return evs


real_update = gf.update_canvas


def capture():
    while snaps:
        name = snaps.pop()
        if OUT:
            from PIL import Image
            buf = (ctypes.c_ubyte * (1280 * 720 * 3))()
            SDL_RenderReadPixels(p2.renderer, None, SDL_PIXELFORMAT_RGB24, buf, 1280 * 3)
            Image.frombytes('RGB', (1280, 720), bytes(buf)).save(os.path.join(OUT, name + '.png'))
    real_update()


gf.get_events, gf.update_canvas, gf.FPS = fake_events, capture, 100
gf.run(title_mode, H)
print(f'smoke ok: 확인 {passed}개 통과, 가게 돈 {state.money}만, 별 {state.stars_total}개')
