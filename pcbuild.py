"""PC 조립 규칙 (그리기 없음). 케이스 → 메인보드 → CPU → 쿨러 → RAM → 그래픽카드 → 파워 → 전원선 순서로 꽂고,
전원 테스트(POST)는 실제 메인보드처럼 CPU → DRAM → VGA → BOOT 순서로 검사해 처음 막힌 단계를 알려 준다."""
from common import PARTS

SLOTS = ['CASE', 'MB', 'CPU', 'COOLER', 'GPU', 'PSU']    # 하나씩 들어가는 자리 (RAM은 슬롯 여러 개)
NEEDS = {'MB': 'CASE', 'CPU': 'MB', 'COOLER': 'CPU', 'GPU': 'MB', 'PSU': 'CASE', 'RAM': 'MB'}
SIZE_RANK = {'mATX': 0, 'ATX': 1}
POST_STAGES = ['CPU', 'DRAM', 'VGA', 'BOOT']
STAR_CUTS = [(19, 3), (12, 2), (6, 1)]
THROTTLE = 3  # 쿨러가 CPU 발열을 못 따라가면 성능 -3


class PCBuild:
    def __init__(self):
        self.parts = {}        # SLOTS 중 하나 -> part id
        self.ram = [None] * 4  # 슬롯 0~3 (보드의 ram_slots 만큼만 쓸 수 있음)
        self.cables = set()    # '24pin', 'cpu8', 'pcie0', 'pcie1'

    # --- 조회 (예전 dict 방식 호출과 호환: build.get('GPU')) ---
    def get(self, slot, default=None):
        return self.parts.get(slot, default)

    def spec(self, slot):
        pid = self.parts.get(slot)
        return PARTS[pid] if pid else None

    def ids(self):
        return list(self.parts.values()) + [r for r in self.ram if r]

    def ram_slots(self):
        mb = self.spec('MB')
        return mb['ram_slots'] if mb else 0

    def pcie_needed(self):
        gpu = self.spec('GPU')
        return gpu['pcie'] if gpu else 0

    def cable_targets(self):
        """지금 꽂을 수 있는 전원선 목록."""
        if 'PSU' not in self.parts or 'MB' not in self.parts:
            return []
        out = ['24pin']
        if 'CPU' in self.parts:
            out.append('cpu8')
        out += [f'pcie{i}' for i in range(min(self.pcie_needed(), self.spec('PSU')['pcie']))]
        return out

    # --- 장착 ---
    def check(self, pid, ram_slot=None):
        """끼울 수 있으면 None, 아니면 이유(한국어)."""
        p = PARTS[pid]
        t = p['type']
        need = NEEDS.get(t)
        if need and need not in self.parts:
            names = {'CASE': '케이스', 'MB': '메인보드', 'CPU': 'CPU'}
            return f"{names[need]}부터 끼워야 해요"
        case, mb, cpu = self.spec('CASE'), self.spec('MB'), self.spec('CPU')
        if t == 'RAM':
            if ram_slot is None or ram_slot >= self.ram_slots():
                return '이 보드엔 그 RAM 슬롯이 없어요'
            if self.ram[ram_slot]:
                return '이미 RAM이 꽂혀 있어요'
            return None
        if t in self.parts:
            return '이미 끼워져 있어요. 먼저 빼 주세요'
        if t == 'MB' and SIZE_RANK[p['size']] > SIZE_RANK[case['mb_max']]:
            return f"{p['size']} 보드는 {case['name']}에 안 들어가요"
        if t == 'CPU' and p['socket'] != mb['socket']:
            return f"소켓이 안 맞아요 (CPU {p['socket']} · 보드 {mb['socket']})"
        if t == 'COOLER' and p['height'] > case['cooler_max']:
            return f"쿨러가 높아서 옆판이 안 닫혀요 ({p['height']}mm > {case['cooler_max']}mm)"
        if t == 'GPU' and p['length'] > case['gpu_max']:
            return f"그래픽카드가 너무 길어요 ({p['length']}mm > {case['gpu_max']}mm)"
        return None

    def place(self, pid, ram_slot=None):
        reason = self.check(pid, ram_slot)
        if reason:
            return reason
        if PARTS[pid]['type'] == 'RAM':
            self.ram[ram_slot] = pid
        else:
            self.parts[PARTS[pid]['type']] = pid
        return None

    def remove(self, slot, ram_slot=None):
        """부품을 뺀다. 그 위에 올라가 있던 부품 · 전원선도 같이 빠진다. 빠진 part id 목록을 돌려준다."""
        out = []
        if slot == 'RAM':
            if self.ram[ram_slot]:
                out.append(self.ram[ram_slot])
                self.ram[ram_slot] = None
            return out
        if slot not in self.parts:
            return out
        out.append(self.parts.pop(slot))
        for child, parent in NEEDS.items():
            if parent == slot:
                if child == 'RAM':
                    out += [r for r in self.ram if r]
                    self.ram = [None] * 4
                else:
                    out += self.remove(child)
        self.cables &= set(self.cable_targets())
        return out

    def plug(self, cable):
        if cable not in self.cable_targets():
            return '지금은 꽂을 데가 없어요'
        self.cables.add(cable)
        return None

    # --- 성능 · 전력 ---
    def dual_channel(self):
        sticks = [r for r in self.ram if r]
        if len(sticks) != 2 or sticks[0] != sticks[1]:
            return False
        if self.ram_slots() == 2:
            return True
        return bool(self.ram[1] and self.ram[3])  # 4슬롯 보드는 2번 · 4번 슬롯이 정답 (A2 · B2)

    def throttled(self):
        cpu, cooler = self.spec('CPU'), self.spec('COOLER')
        return bool(cpu and cooler and cooler['tdp'] < cpu['watt'])

    def perf(self):
        total = sum(PARTS[i].get('perf', 0) for i in self.ids())
        total += 1 if self.dual_channel() else 0
        total -= THROTTLE if self.throttled() else 0
        return max(0, total)

    def stars(self):
        return next((s for cut, s in STAR_CUTS if self.perf() >= cut), 0)

    def watt(self):
        return sum(PARTS[i].get('watt', 0) for i in self.ids())

    def capacity(self):
        psu = self.spec('PSU')
        return psu['capacity'] if psu else 0

    # --- 전원 테스트 ---
    def post(self):
        """(통과한 단계 수 0~4, 메시지). 4면 부팅 성공. 디버그 LED처럼 처음 막힌 곳에서 멈춘다."""
        if 'CASE' not in self.parts or 'MB' not in self.parts:
            return -1, '메인보드가 없어요'
        if 'PSU' not in self.parts or '24pin' not in self.cables:
            return -1, '전원이 안 들어와요 (파워 · 24핀 확인)'
        if 'CPU' not in self.parts or 'cpu8' not in self.cables:
            return 0, 'CPU 불이 켜졌어요 (CPU · CPU 8핀 확인)'
        if 'COOLER' not in self.parts:
            return 0, '켜지자마자 과열로 꺼졌어요 (쿨러 없음)'
        if not any(self.ram):
            return 1, 'DRAM 불이 켜졌어요 (RAM 없음)'
        if 'GPU' not in self.parts:
            return 2, 'VGA 불이 켜졌어요 (그래픽카드 없음)'
        if self.pcie_needed() > self.spec('PSU')['pcie']:
            return 2, f"VGA 불이 켜졌어요 (이 파워엔 그래픽카드 전원선이 {self.spec('PSU')['pcie']}개뿐)"
        if any(f'pcie{i}' not in self.cables for i in range(self.pcie_needed())):
            return 2, 'VGA 불이 켜졌어요 (그래픽카드 전원선 확인)'
        if self.watt() > self.capacity():
            return 3, f"부팅 중 꺼졌어요 (전력 {self.watt()}W > 파워 {self.capacity()}W)"
        msg = '부팅 성공!' + (' 단, 쿨러가 약해서 성능이 떨어져요' if self.throttled() else '')
        return 4, msg

    def boots(self):
        return self.post()[0] == 4


def full(case='case2', mb='mb2', cpu='cpu2', cooler='cool1', ram=('ram2', 'ram2'), gpu='gpu2', psu='psu2'):
    """테스트 · 데모용: 부품을 차례로 끼우고 전원선까지 꽂은 PC."""
    b = PCBuild()
    for pid in (case, mb, cpu, cooler):
        assert b.place(pid) is None, (pid, b.check(pid))
    slots = [1, 3] if b.ram_slots() == 4 else [0, 1]
    for s, r in zip(slots, ram):
        assert b.place(r, s) is None
    for pid in (gpu, psu):
        assert b.place(pid) is None, (pid, b.check(pid))
    for c in b.cable_targets():
        b.plug(c)
    return b


if __name__ == '__main__':
    b = PCBuild()
    assert b.check('mb2') == '케이스부터 끼워야 해요'
    b.place('case1')
    assert '안 들어가요' in b.check('mb3')             # ATX 보드 → 미니 케이스
    b.place('mb2')
    assert '소켓' in b.check('cpu1')                    # AM CPU → LGA 보드
    b.place('cpu2')
    assert '옆판' in b.check('cool2')                   # 타워 쿨러 158mm > 미니 140mm
    assert '너무 길어요' in b.check('gpu2')              # 280mm > 250mm
    assert b.check('ram1', 2) is not None               # 2슬롯 보드의 3번 슬롯 없음
    assert b.post()[0] == -1
    b.place('cool1'); b.place('psu1'); b.plug('24pin')
    assert b.post() == (0, 'CPU 불이 켜졌어요 (CPU · CPU 8핀 확인)')
    b.plug('cpu8')
    assert b.post()[0] == 1                             # RAM 없음
    b.place('ram1', 0); b.place('gpu1')
    assert b.boots() and b.throttled()                  # 기본 쿨러 95 < 중급 CPU 105W → 쓰로틀링
    assert b.perf() == 4 + 1 + 3 - THROTTLE
    assert sorted(b.remove('MB')) == ['cool1', 'cpu2', 'gpu1', 'mb2', 'ram1'] and b.cables == set()

    ok = full()
    assert ok.boots() and ok.dual_channel() and ok.perf() == 4 + 7 + 4 + 1 - THROTTLE
    weak_psu = full(psu='psu1')                          # 400W 파워엔 PCIe 선이 없음
    assert weak_psu.post()[0] == 2 and '전원선이 0개' in weak_psu.post()[1]
    hot = full(cpu='cpu3', mb='mb3', cooler='cool2', gpu='gpu2', psu='psu1')
    assert hot.post()[0] == 2                            # 파워 400W는 PCIe 선 0개
    over = full(case='case3', cpu='cpu3', mb='mb3', cooler='cool2', gpu='gpu3', psu='psu2')
    assert over.post()[0] == 2                           # 고급 GPU는 PCIe 2개, 600W 파워는 1개
    top = full(case='case3', cpu='cpu3', mb='mb3', cooler='cool2', gpu='gpu3', psu='psu3', ram=('ram3', 'ram3'))
    assert top.boots() and top.stars() == 3 and top.watt() == 520
    wrong = PCBuild()
    for pid in ('case2', 'mb3', 'cpu2', 'cool2'):
        wrong.place(pid)
    wrong.place('ram2', 0); wrong.place('ram2', 1)
    assert not wrong.dual_channel()                      # 4슬롯 보드에서 1 · 2번에 꽂으면 듀얼 채널 아님
    print('pcbuild ok', ok.perf(), top.perf())
