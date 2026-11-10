"""화면 크기, 데이터, 폰트, 그리기 도우미. 스프라이트는 resource/ (tools/make_sprites.js로 생성)."""
import json
import os

from pico2d import draw_rectangle, load_font, load_image

WIDTH, HEIGHT = 1280, 720
BASE = os.path.dirname(os.path.abspath(__file__))


def load_json(name):
    with open(os.path.join(BASE, 'data', name), encoding='utf-8') as f:
        return json.load(f)


ITEMS = {it['id']: it for it in load_json('items.json')}
PARTS = {p['id']: p for p in load_json('parts.json')}
REQUESTS = load_json('requests.json')
UPGRADES = {u['id']: u for u in load_json('upgrades.json')}


THEME_NAMES = {'cozy': '아늑', 'focus': '집중', 'gamer': '게이머', 'minimal': '미니멀', 'plant': '플랜테리어'}

FONT_CANDIDATES = [
    os.path.join(BASE, 'resource', 'font.ttf'),
    'C:/Windows/Fonts/malgun.ttf',
    '/System/Library/Fonts/AppleSDGothicNeo.ttc',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
]
_fonts = {}


def font(size=18):
    if size not in _fonts:
        path = next(p for p in FONT_CANDIDATES if os.path.exists(p))
        _fonts[size] = load_font(path, size)
    return _fonts[size]


def box(x1, y1, x2, y2, color, alpha=255):
    if alpha < 255:  # pico2d는 기본으로 알파를 섞지 않아서 반투명일 때만 블렌드 모드를 켠다
        import pico2d.pico2d as p2
        from sdl2 import SDL_SetRenderDrawBlendMode, SDL_BLENDMODE_BLEND, SDL_BLENDMODE_NONE
        SDL_SetRenderDrawBlendMode(p2.renderer, SDL_BLENDMODE_BLEND)
        draw_rectangle(x1, y1, x2, y2, *color, alpha, True)
        SDL_SetRenderDrawBlendMode(p2.renderer, SDL_BLENDMODE_NONE)
        return
    draw_rectangle(x1, y1, x2, y2, *color, alpha, True)


def outline(x1, y1, x2, y2, color=(124, 92, 255)):
    draw_rectangle(x1, y1, x2, y2, *color, 255, False)


def text(x, y, s, size=18, color=(232, 226, 255)):
    font(size).draw(x, y, s, color)


def to_canvas_y(event_y):
    return HEIGHT - 1 - event_y


def inside(x, y, rect):
    x1, y1, x2, y2 = rect
    return x1 <= x <= x2 and y1 <= y <= y2


_images = {}


def sprite(name):
    if name not in _images:
        _images[name] = load_image(os.path.join(BASE, 'resource', name + '.png'))
    return _images[name]


def draw_fit(name, cx, cy, max_w, max_h):
    """비율을 유지한 채 상자 안에 맞춰 그린다 (상점 썸네일 · 부품 아이콘용)."""
    img = sprite(name)
    k = min(max_w / img.w, max_h / img.h)
    img.draw(cx, cy, img.w * k, img.h * k)
