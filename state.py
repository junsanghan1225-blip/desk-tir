"""게임 진행 상태.
가게(여러 날 유지): 돈 · 날짜 · 재고 · 업그레이드 · 오늘 장부.
주문(손님 한 명 동안): 배치 · PC · 케이블."""
from common import ITEMS, PARTS, REQUESTS, UPGRADES, wholesale
from room import Room
from pcbuild import PCBuild

START_MONEY = 250
LAST_DAY = max(r['day'] for r in REQUESTS)

# 가게
money = START_MONEY
day = 1
stock = {}        # 소품 · 부품 id -> 남은 개수
upgrades = set()  # 산 업그레이드 id
ledger = []       # 오늘 영업 기록: {'customer', 'stars', 'pay', 'tip'}
order_index = 0   # 오늘 몇 번째 손님인지

# 주문
room = Room()
pc = PCBuild()  # 조립 중인 PC
cables = []  # {'dev': room.placed의 항목, 'type': 'DP'|'USB'|'AUDIO', 'port': 번호}


def new_game():
    global money, day, stock, upgrades
    money, day, stock, upgrades = START_MONEY, 1, {}, set()
    start_day()


def start_day():
    global ledger, order_index
    ledger, order_index = [], 0


def todays_requests():
    return [r for r in REQUESTS if r['day'] == day]


def request():
    return todays_requests()[order_index]


def reset_order():
    global room, pc, cables
    room = Room()
    pc = PCBuild()
    cables = []


def unlocked(thing):
    return thing.get('line') is None or thing['line'] in upgrades


def catalog():
    """아침 시장에서 살 수 있는 것: 소품 + 부품 (잠긴 라인은 업그레이드 후)."""
    return [i for i in ITEMS if unlocked(ITEMS[i])] + [p for p in PARTS if unlocked(PARTS[p])]


def price_of(thing_id):
    return (ITEMS.get(thing_id) or PARTS[thing_id])['price']


def buy(thing_id, n=1):
    """도매가로 재고 구매. n이 음수면 되팔기(같은 값). 성공하면 True."""
    global money
    cost = wholesale(price_of(thing_id)) * n
    if thing_id not in catalog() or n > 0 and cost > money or stock.get(thing_id, 0) + n < 0:
        return False
    money -= cost
    stock[thing_id] = stock.get(thing_id, 0) + n
    return True


def buy_upgrade(uid):
    global money
    up = UPGRADES[uid]
    if uid in upgrades or up['price'] > money:
        return False
    money -= up['price']
    upgrades.add(uid)
    return True


def take(thing_id):
    """재고에서 하나 꺼내 주문에 쓴다."""
    if stock.get(thing_id, 0) <= 0:
        return False
    stock[thing_id] -= 1
    return True


def give_back(thing_id):
    stock[thing_id] = stock.get(thing_id, 0) + 1


def spent():
    """손님에게 청구되는 소매가 합 (손님 예산과 비교)."""
    return sum(ITEMS[p['id']]['price'] for p in room.placed) + sum(PARTS[pid]['price'] for pid in pc.ids())


def money_left():
    return request()['budget'] - spent()


def settle(result):
    """납품 정산 (좋은 피자처럼 정가 + 팁): 손님은 자기 예산만큼 내고, 별 1개당 예산의 5%를 팁으로 준다.
    별 0개면 절반만 낸다. 쓴 재고는 아침에 이미 낸 비용이라, 싸게 맞출수록 남는다."""
    global money
    budget = request()['budget']
    pay = budget if result['stars'] else budget // 2
    tip = result['stars'] * budget * 5 // 100
    money += pay + tip
    ledger.append({'customer': request()['customer'], 'stars': result['stars'], 'pay': pay, 'tip': tip})
    return pay, tip


def next_customer():
    """다음 손님이 있으면 True, 오늘 영업이 끝났으면 False."""
    global order_index
    order_index += 1
    return order_index < len(todays_requests())


if __name__ == '__main__':
    new_game()
    assert money == START_MONEY and len(todays_requests()) == 3
    assert not buy('cpu3')                       # 하이엔드 라인은 업그레이드 전엔 못 산다
    assert buy('monitor') and stock['monitor'] == 1 and money == START_MONEY - wholesale(25)
    assert buy('monitor', -1) and money == START_MONEY and stock['monitor'] == 0
    assert not buy('monitor', -1)                # 없는 재고는 못 판다
    assert 'mic' not in catalog() and buy_upgrade('gamer') and 'mic' in catalog()
    buy('lamp_warm')
    reset_order()
    assert take('lamp_warm') and not take('lamp_warm')
    room.place('lamp_warm', 'desk', 0)
    before = money
    pay, tip = settle({'stars': 2})
    assert pay == 100 and tip == 10 and money == before + pay + tip
    assert settle({'stars': 0}) == (50, 0)  # 같은 손님(예산 100) 별 0개 → 절반
    assert next_customer() and next_customer() and not next_customer()
    print('state ok')
