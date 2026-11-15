"""정면 뷰 책상: 벽 · 책상 위 2레이어에 자유 배치. 책상 위 소품은 상판에 서고(좌우만 자유), 벽 소품은 위아래도 자유.
같은 레이어끼리는 겹칠 수 없다. 소품 크기는 그림 크기 그대로."""
from common import ITEMS, sprite_size

AREA_X1, AREA_X2 = 300, 1070      # 놓을 수 있는 가로 범위 (오른쪽은 PC 자리)
DESK_Y = 210                      # 책상 상판 높이
WALL_Y1, WALL_Y2 = 400, 640       # 벽 소품 세로 범위
SLOT_X0, SLOT_W, SLOT_COUNT = 300, 110, 7   # 예전 칸 좌표 (place/fits의 slot 인자: 테스트 · 자동 배치용)
LAYER_NAMES = {'wall': '벽', 'desk': '책상 위'}
COLORS = 4                        # 색을 바꿀 수 있는 소품의 색 가짓수 (0 = 원래 색)


def size_of(item_id):
    return sprite_size(item_id)


def rect_of(p):
    w, h = size_of(p['id'])
    return p['x'], p['y'], p['x'] + w, p['y'] + h


def slot_pos(item_id, layer, slot):
    """예전 칸 번호 → 자유 좌표 (왼쪽 아래)."""
    return SLOT_X0 + slot * SLOT_W + 6, DESK_Y if layer == 'desk' else 495 - size_of(item_id)[1] // 2


class Room:
    def __init__(self):
        self.placed = []  # {'id', 'layer', 'x', 'y', 'color'?}

    def fits_at(self, item_id, layer, x, y, ignore=None):
        w, h = size_of(item_id)
        if ITEMS[item_id]['layer'] != layer or x < AREA_X1 or x + w > AREA_X2 + 1:
            return False
        if layer == 'wall' and (y < WALL_Y1 or y + h > WALL_Y2):
            return False
        for p in self.placed:
            if p is ignore or p['layer'] != layer:
                continue
            x1, y1, x2, y2 = rect_of(p)
            if x < x2 - 2 and x1 < x + w - 2 and y < y2 - 2 and y1 < y + h - 2:
                return False
        return True

    def fits(self, item_id, layer, slot):
        if slot < 0 or slot + ITEMS[item_id]['size'] > SLOT_COUNT:
            return False
        return self.fits_at(item_id, layer, *slot_pos(item_id, layer, slot))

    def place_at(self, item_id, layer, x, y):
        p = {'id': item_id, 'layer': layer, 'x': x, 'y': y}
        self.placed.append(p)
        return p

    def place(self, item_id, layer, slot):
        return self.place_at(item_id, layer, *slot_pos(item_id, layer, slot))

    def rect(self, p):
        return rect_of(p)

    def item_at(self, x, y):
        for p in sorted(self.placed, key=lambda p: p['layer'] == 'desk', reverse=True):  # 앞에 있는 책상 소품 먼저
            x1, y1, x2, y2 = rect_of(p)
            if x1 <= x <= x2 and y1 <= y <= y2:
                return p
        return None

    def ids(self):
        return [p['id'] for p in self.placed]


def adjacent(a, b, gap=30):
    """같은 레이어에서 옆에 붙어 있는지 (가로 간격 gap 이하, 세로로 겹침)."""
    if a['layer'] != b['layer']:
        return False
    ax1, ay1, ax2, ay2 = rect_of(a)
    bx1, by1, bx2, by2 = rect_of(b)
    return max(ax1, bx1) - min(ax2, bx2) <= gap and ay1 < by2 and by1 < ay2


def drop_target(item_id, x, y):
    """마우스 위치(물건 중심) -> 놓일 (layer, x, y). 그 소품의 레이어 근처가 아니면 None."""
    layer = ITEMS[item_id]['layer']
    w, h = size_of(item_id)
    left = int(min(max(x - w / 2, AREA_X1), AREA_X2 - w))
    if layer == 'desk':
        return (layer, left, DESK_Y) if DESK_Y - 60 <= y <= DESK_Y + 240 else None
    if y < WALL_Y1 - 30:
        return None
    return layer, left, int(min(max(y - h / 2, WALL_Y1), WALL_Y2 - h))


if __name__ == '__main__':
    r = Room()
    assert r.fits('monitor', 'desk', 0) and not r.fits('monitor', 'wall', 0) and not r.fits('monitor', 'desk', 6)
    a = r.place('lamp_warm', 'desk', 0)
    assert not r.fits('book', 'desk', 0) and r.fits('book', 'desk', 1)
    b = r.place_at('book', 'desk', a['x'] + size_of('lamp_warm')[0] + 10, DESK_Y)   # 칸 사이 자유 위치
    assert adjacent(a, b) and not r.fits_at('mug', 'desk', b['x'] + 20, DESK_Y)
    assert r.fits_at('mug', 'desk', b['x'] + 20, DESK_Y, ignore=b)
    assert drop_target('frame', 500, 100) is None and drop_target('frame', 500, 700)[2] == WALL_Y2 - size_of('frame')[1]
    assert drop_target('mug', 10, 300) == ('desk', AREA_X1, DESK_Y)
    r.place_at('frame', 'wall', 400, 410)
    assert not r.fits_at('cork', 'wall', 420, 430)
    print('room ok')
