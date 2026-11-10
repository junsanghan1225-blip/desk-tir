"""채점: 테마 25 + 필수/금지 20 + PC 성능 20 + 시너지 15 + 배선 10 + 예산 10 = 100점."""
from common import ITEMS, PARTS
import cables as cab

STAR_CUTS = [(90, 3), (75, 2), (60, 1)]


def synergies(placed, pc):
    ids = [p['id'] for p in placed]
    tags = [t for i in ids for t in ITEMS[i]['tags']]
    case = pc.get('CASE')
    found = []

    def adjacent(a, b):
        return a['layer'] == b['layer'] and (
            a['slot'] + ITEMS[a['id']]['size'] == b['slot'] or b['slot'] + ITEMS[b['id']]['size'] == a['slot'])

    lamps = [p for p in placed if p['id'] in ('lamp_warm', 'lamp_cool')]
    books = [p for p in placed if p['id'] == 'book']
    if any(adjacent(l, b) for l in lamps for b in books):
        found.append('독서 콤보')
    if tags.count('plant') >= 3:
        found.append('플랜테리어')
    if case == 'case3' and 'rgb_bar' in ids and 'gaming_kb' in ids:
        found.append('풀 RGB 셋업')
    if case == 'case2' and tags.count('minimal') >= 3:
        found.append('화이트 셋업')
    if 1 <= sum(p['layer'] == 'desk' for p in placed) <= 3:
        found.append('미니멀리즘')
    if 'wall_light' in ids and lamps:
        found.append('균형 조명')
    return found


def score(request, room, pc, spent, cables=()):
    """pc: pcbuild.PCBuild"""
    placed = room.placed
    ids = [p['id'] for p in placed]
    theme = set(request['theme'])

    objects = [ITEMS[i]['tags'] for i in ids] + ([PARTS[pc.get('CASE')]['tags']] if pc.get('CASE') else [])
    theme_s = 25 * sum(bool(theme & set(t)) for t in objects) / len(objects) if objects else 0

    reqs = request['required']
    met = sum(min(1, sum(ids.count(i) for i in r['any']) / r['count']) for r in reqs)
    req_s = 20 * met / len(reqs) if reqs else 20
    req_s = max(0, req_s - 10 * sum(ids.count(f) for f in request['forbidden']))

    stage, post_msg = pc.post()
    boot = 'ok' if stage == 4 else post_msg
    pc_s = 0 if boot != 'ok' else max(0, 20 - 8 * max(0, request['perf'] - pc.stars()))

    syn = synergies(placed, pc)
    syn_s = min(15, 8 * len(syn))
    wire_s, unplugged, tangles = cab.wiring_score(list(cables), room)

    budget_s = 10 * max(0, request['budget'] - spent) / request['budget']

    parts = {'테마 일치': theme_s, '필수 · 금지': req_s, 'PC 성능': pc_s, '조합 시너지': syn_s, '배선': wire_s, '예산 절약': budget_s}
    total = round(sum(parts.values()))
    stars = next((s for cut, s in STAR_CUTS if total >= cut), 0)
    return {'parts': parts, 'total': total, 'stars': stars, 'synergies': syn, 'boot': boot,
            'line': reaction(request, parts, boot, unplugged, tangles)}


MAX = {'테마 일치': 25, '필수 · 금지': 20, 'PC 성능': 20, '조합 시너지': 15, '배선': 10, '예산 절약': 10}
LINES = {
    '테마 일치': '음… 제가 말한 분위기랑은 좀 달라요.',
    '필수 · 금지': '부탁드린 게 빠졌거나, 싫다는 게 들어갔어요.',
    'PC 성능': '켜지긴 하는데 좀 느리네요…',
    '조합 시너지': '하나하나는 좋은데, 어울림이 아쉬워요.',
    '배선': '선이 너무 엉켜 있어요… 정리 좀 해 주세요.',
    '예산 절약': '좋긴 한데… 돈을 너무 많이 쓰셨어요.',
}


def reaction(request, parts, boot, unplugged=0, tangles=0):
    if boot != 'ok':
        return f"PC가 안 켜져요… ({boot})"
    if unplugged:
        return f'기기 {unplugged}개가 안 켜져요. 케이블이 안 꽂혀 있어요!'
    worst = min(parts, key=lambda k: parts[k] / MAX[k])
    if parts[worst] / MAX[worst] >= 0.8:
        return '상상한 그대로예요! 단골 할게요.'
    return LINES[worst]


if __name__ == '__main__':
    from common import REQUESTS
    from room import Room
    from pcbuild import full
    dev = next(r for r in REQUESTS if r['customer'] == '밤샘 개발자')
    good_pc = full()                                     # 중급 CPU · 중급 GPU · 16GB 듀얼 · 600W
    room = Room()
    for iid, layer, slot in [('lamp_warm', 'desk', 0), ('book', 'desk', 1), ('monitor', 'desk', 2), ('monitor', 'desk', 4),
                             ('wall_light', 'wall', 0)]:
        room.place(iid, layer, slot)
    mons = [p for p in room.placed if p['id'] == 'monitor']
    wired = [{'dev': mons[0], 'type': 'DP', 'port': 0}, {'dev': mons[1], 'type': 'DP', 'port': 1}]
    assert set(synergies(room.placed, good_pc)) == {'독서 콤보', '균형 조명'}
    r = score(dev, room, good_pc, 170, wired)
    assert r['parts']['필수 · 금지'] == 20 and r['parts']['PC 성능'] == 20 and r['parts']['배선'] == 10, r
    unplugged = score(dev, room, good_pc, 170, [])
    assert unplugged['parts']['배선'] == 0 and '케이블' in unplugged['line']
    room.place('lamp_cool', 'desk', 6)
    bad = score(dev, room, full(psu='psu1'), 200, wired)   # 400W 파워엔 그래픽카드 전원선이 없음
    assert bad['parts']['PC 성능'] == 0 and bad['parts']['필수 · 금지'] == 10 and 'VGA' in bad['line']
    print('scorer ok', r['total'], r['stars'])
