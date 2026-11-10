"""자동 저장 · 이어하기. 화면이 바뀔 때마다, 그리고 게임을 끌 때 저장한다.
저장 위치: 사용자 폴더/.desk-tir/save.json (DESK_TIR_SAVE 환경 변수로 바꿀 수 있음)."""
import json
import os

import state
from pcbuild import PCBuild
from room import Room

PATH = os.environ.get('DESK_TIR_SAVE') or os.path.join(os.path.expanduser('~'), '.desk-tir', 'save.json')
RESUMABLE = {'request_mode', 'shop_mode', 'decorate_mode', 'build_mode', 'wire_mode', 'day_end_mode'}
VERSION = 1


def to_dict(mode_name):
    placed = state.room.placed
    order_index = state.order_index
    if mode_name == 'result_mode':  # 정산은 이미 끝났으니 다음 단계부터 이어간다
        more = order_index + 1 < len(state.todays_requests())
        mode_name, order_index = ('request_mode', order_index + 1) if more else ('day_end_mode', order_index)
    pc = state.pc
    return {
        'version': VERSION, 'mode': mode_name,
        'money': state.money, 'day': state.day, 'stock': state.stock, 'upgrades': sorted(state.upgrades),
        'stars_total': state.stars_total, 'ledger': state.ledger, 'order_index': order_index,
        'order': None if mode_name in ('request_mode', 'day_end_mode') else {
            'cart': state.cart,
            'placed': placed,
            'pc': {'parts': pc.parts, 'ram': pc.ram, 'cables': sorted(pc.cables), 'lever_open': pc.lever_open, 'paste': pc.paste},
            'cables': [{'dev': placed.index(c['dev']), 'type': c['type'], 'port': c['port']} for c in state.cables if c['dev'] in placed],
        },
    }


def from_dict(d):
    """상태를 되살리고, 이어서 열 화면 이름을 돌려준다."""
    state.money, state.day, state.stock = d['money'], d['day'], dict(d['stock'])
    state.upgrades, state.stars_total = set(d['upgrades']), d['stars_total']
    state.ledger, state.order_index = list(d['ledger']), d['order_index']
    state.reset_order()
    o = d['order']
    if o:
        state.cart = dict(o['cart'])
        state.room = Room()
        state.room.placed = [dict(p) for p in o['placed']]
        pc = PCBuild()
        pc.parts, pc.ram = dict(o['pc']['parts']), list(o['pc']['ram'])
        pc.cables, pc.lever_open, pc.paste = set(o['pc']['cables']), o['pc']['lever_open'], o['pc']['paste']
        state.pc = pc
        state.cables = [{'dev': state.room.placed[c['dev']], 'type': c['type'], 'port': c['port']} for c in o['cables']]
    return d['mode']


def save(mode):
    name = getattr(mode, '__name__', str(mode))
    if name not in RESUMABLE and name != 'result_mode':
        return
    try:
        os.makedirs(os.path.dirname(PATH), exist_ok=True)
        tmp = PATH + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(to_dict(name), f, ensure_ascii=False)
        os.replace(tmp, PATH)  # 쓰다가 꺼져도 예전 저장은 남는다
    except OSError as e:
        print('저장 실패:', e)


def peek():
    """저장이 있으면 (일차, 가게 돈, 레벨용 별) 요약, 없거나 깨졌으면 None."""
    try:
        with open(PATH, encoding='utf-8') as f:
            d = json.load(f)
        return d if d.get('version') == VERSION else None
    except (OSError, ValueError):
        return None


def load():
    d = peek()
    return from_dict(d) if d else None


def delete():
    try:
        os.remove(PATH)
    except OSError:
        pass


if __name__ == '__main__':
    import tempfile
    PATH = os.path.join(tempfile.mkdtemp(), 'save.json')
    from pcbuild import full
    state.new_game()
    state.add_to_cart('monitor'); state.checkout(); state.add_to_cart('book')
    state.take('monitor'); state.room.place('monitor', 'desk', 2)
    state.pc = full()
    state.cables = [{'dev': state.room.placed[0], 'type': 'DP', 'port': 0}]
    state.stars_total = 5
    saved = json.loads(json.dumps(to_dict('build_mode')))
    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(saved, f)
    state.new_game()                                   # 다 지우고
    assert load() == 'build_mode'                      # 되살리면 그대로
    assert state.cart == {'book': 1} and state.stars_total == 5 and state.money == 200 - 25
    assert state.pc.boots() and state.pc.dual_channel() and state.cables[0]['dev'] is state.room.placed[0]
    assert to_dict('result_mode')['mode'] == 'request_mode' and to_dict('result_mode')['order_index'] == 1
    state.order_index = 2
    assert to_dict('result_mode')['mode'] == 'day_end_mode'
    with open(PATH, 'w') as f:
        f.write('{broken')
    assert peek() is None                              # 깨진 저장은 무시
    print('save ok')
