"""케이블 연결: 주변기기를 PC 뒷면 포트(DP · USB · 오디오)에 잇는다. 선이 교차하면 감점.
좌표는 배선 정리 화면(wire_mode) 기준: 위 = 책상 위 기기(책상 순서 그대로), 아래 = 포트 한 줄."""
from common import ITEMS, PARTS

PORT_COUNT = {'AUDIO': 2}                  # DP는 그래픽카드, USB는 메인보드가 정함
MAX_PORTS = {'DP': 3, 'USB': 6, 'AUDIO': 2}
PORT_COLOR = {'DP': (255, 77, 141), 'USB': (46, 230, 214), 'AUDIO': (255, 214, 92)}
PORT_NAMES = {'DP': 'DP', 'USB': 'USB', 'AUDIO': '오디오'}
ORDER = ['DP', 'USB', 'AUDIO']               # PC 뒷면 포트는 한 줄: 기기 순서와 포트 순서가 엇갈리면 선이 꼬인다
PORT_Y, PORT_X0, PORT_GAP = 170, 200, 88
SLOT_OFFSET = {'DP': 0, 'USB': 3, 'AUDIO': 9}  # DP 최대 3 · USB 최대 6 · 오디오 2
PANEL = (PORT_X0 - 50, PORT_Y - 56, PORT_X0 + PORT_GAP * 10 + 50, PORT_Y + 44)
PLUG_Y = 405
DEV_X0, DEV_GAP = 150, 145                     # 책상 슬롯 → 배선 화면 x


def port_count(t, pc):
    if t == 'DP':
        return PARTS[pc.get('GPU')]['dp'] if pc.get('GPU') else 0
    if t == 'USB':
        return PARTS[pc.get('MB')]['usb'] if pc.get('MB') else 0
    return PORT_COUNT[t]


def port_pos(t, i):
    return PORT_X0 + (SLOT_OFFSET[t] + i) * PORT_GAP, PORT_Y


def plug_pos(room, p):
    return DEV_X0 + (p['slot'] + ITEMS[p['id']]['size'] / 2) * DEV_GAP, PLUG_Y


def port_at(x, y, pc):
    for t in ORDER:
        for i in range(port_count(t, pc)):
            px, py = port_pos(t, i)
            if abs(x - px) <= 30 and abs(y - py) <= 22:
                return t, i
    return None


def needs_cable(p):
    """포트에 연결해야 켜지는 기기 (케이블이든 무선 동글이든)."""
    return 'port' in ITEMS[p['id']]


def is_dongle(c):
    return ITEMS[c['dev']['id']].get('dongle', False)


def prune(cables, room, pc):
    """사라진 기기 · 없어진 포트(그래픽카드 교체 등)에 꽂힌 선은 뽑는다."""
    return [c for c in cables if any(c['dev'] is p for p in room.placed) and c['port'] < port_count(c['type'], pc)]


def _cross(a, b, c, d):
    def orient(p, q, r):
        return (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
    return orient(a, b, c) * orient(a, b, d) < 0 and orient(c, d, a) * orient(c, d, b) < 0


def crossings(cables, room):
    segs = [(plug_pos(room, c['dev']), port_pos(c['type'], c['port'])) for c in cables if not is_dongle(c)]  # 동글은 선이 없어 안 꼬인다
    return sum(_cross(*segs[i], *segs[j]) for i in range(len(segs)) for j in range(i + 1, len(segs)))


def wiring_score(cables, room):
    """10점: 연결된 기기 비율 × 10 − 교차 1번당 2점."""
    devices = [p for p in room.placed if needs_cable(p)]
    if not devices:
        return 10, 0, 0
    connected = sum(any(c['dev'] is p for c in cables) for p in devices)
    x = crossings(cables, room)
    return max(0, 10 * connected / len(devices) - 2 * x), len(devices) - connected, x


if __name__ == '__main__':
    from room import Room
    room = Room()
    room.place('monitor', 'desk', 0)
    room.place('keyboard', 'desk', 2)
    mon, kb = room.placed
    pc = {'GPU': 'gpu1', 'MB': 'mb1'}
    assert port_count('DP', pc) == 1 and port_count('DP', {}) == 0 and port_count('USB', pc) == 4 and port_count('USB', {'MB': 'mb3'}) == 6
    ok = [{'dev': mon, 'type': 'DP', 'port': 0}, {'dev': kb, 'type': 'USB', 'port': 0}]
    assert wiring_score(ok, room) == (10, 0, 0), wiring_score(ok, room)
    # 왼쪽 기기를 오른쪽 포트에, 오른쪽 기기를 왼쪽 포트에 → 교차
    room.place('speaker', 'desk', 4)
    sp = room.placed[2]
    tangled = [{'dev': kb, 'type': 'AUDIO', 'port': 1}, {'dev': sp, 'type': 'USB', 'port': 0}]
    assert crossings(tangled, room) == 1
    assert prune(ok, room, {'MB': 'mb1'}) == [ok[1]]  # GPU를 빼면 DP 선이 뽑힘
    room.place('mouse_gaming', 'desk', 5)
    ms = room.placed[3]
    dongled = tangled + [{'dev': ms, 'type': 'USB', 'port': 3}]
    assert crossings(dongled, room) == 1                  # 동글은 선이 없어서 꼬임에 안 들어감
    print('cables ok')
