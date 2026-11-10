"""게임 진행 상태.
가게(여러 날 유지): 돈 · 날짜 · 창고 재고 · 업그레이드 · 오늘 장부.
주문(손님 한 명 동안): 장바구니 · 배치 · PC · 케이블.
흐름: 주문을 듣고 → 쇼핑(장바구니 → 결제 → 창고로 배송) → 꾸미기 · 조립 · 배선 → 납품. 남은 물건은 창고에 남아 다음 주문에 쓴다."""
from common import ITEMS, PARTS, REQUESTS, UPGRADES
from room import Room
from pcbuild import PCBuild

START_MONEY = 200
LEVELS = [0, 4, 10, 18, 28]   # 가게 레벨 n이 되려면 필요한 누적 별 (Lv1 = 0개)
TIP_RATE = [5, 6, 8, 10, 12]  # 레벨별 별 1개당 팁 (예산의 %)
LAST_DAY = max(r['day'] for r in REQUESTS)

# 가게
money = START_MONEY
day = 1
stock = {}        # 창고: 소품 · 부품 id -> 개수 (이미 돈을 낸 물건)
upgrades = set()  # 산 업그레이드 id
stars_total = 0   # 지금까지 받은 별 (가게 평판)
ledger = []       # 오늘 영업 기록: {'customer', 'stars', 'pay', 'tip', 'cost'}
order_index = 0   # 오늘 몇 번째 손님인지

# 주문
cart = {}       # 장바구니: id -> 개수 (결제 전)
room = Room()
pc = PCBuild()  # 조립 중인 PC
cables = []     # {'dev': room.placed의 항목, 'type': 'DP'|'USB'|'AUDIO', 'port': 번호}


def new_game():
    global money, day, stock, upgrades, stars_total
    money, day, stock, upgrades, stars_total = START_MONEY, 1, {}, set(), 0
    start_day()


def start_day():
    global ledger, order_index
    ledger, order_index = [], 0


def todays_requests():
    return [r for r in REQUESTS if r['day'] == day]


def request():
    return todays_requests()[order_index]


def reset_order():
    global room, pc, cables, cart
    cart = {}
    room = Room()
    pc = PCBuild()
    cables = []


def unlocked(thing):
    return thing.get('line') is None or thing['line'] in upgrades


def catalog():
    """쇼핑몰에서 살 수 있는 것: 소품 + 부품 (잠긴 라인은 업그레이드 후)."""
    return [i for i in ITEMS if unlocked(ITEMS[i])] + [p for p in PARTS if unlocked(PARTS[p])]


def price_of(thing_id):
    return (ITEMS.get(thing_id) or PARTS[thing_id])['price']


def add_to_cart(thing_id, n=1):
    """장바구니에 담기 (n이 음수면 빼기). 잠긴 상품은 못 담는다."""
    if thing_id not in catalog():
        return False
    cart[thing_id] = cart.get(thing_id, 0) + n
    if cart[thing_id] <= 0:
        del cart[thing_id]
    return True


def cart_total():
    return sum(price_of(t) * n for t, n in cart.items())


def checkout():
    """결제: 가게 돈에서 빠지고 물건은 창고로. 돈이 모자라면 아무것도 안 바뀌고 False."""
    global money
    total = cart_total()
    if not cart or total > money:
        return None
    money -= total
    receipt = dict(cart)
    for t, n in cart.items():
        stock[t] = stock.get(t, 0) + n
    cart.clear()
    return receipt, total


def sell_back(thing_id):
    """창고 물건 반품: 산 값의 절반을 돌려받는다."""
    global money
    if stock.get(thing_id, 0) <= 0:
        return False
    stock[thing_id] -= 1
    money += price_of(thing_id) // 2
    return True


def level():
    return sum(1 for need in LEVELS if stars_total >= need)


def next_level_stars():
    """다음 레벨까지 필요한 누적 별 (최고 레벨이면 None)."""
    return LEVELS[level()] if level() < len(LEVELS) else None


def buy_upgrade(uid):
    global money
    up = UPGRADES[uid]
    if uid in upgrades or up['price'] > money or level() < up['level']:
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
    """이번 주문에 들어간 물건 값 합 (손님 예산을 넘으면 안 된다)."""
    return sum(ITEMS[p['id']]['price'] for p in room.placed) + sum(PARTS[pid]['price'] for pid in pc.ids())


def money_left():
    return request()['budget'] - spent()


def settle(result):
    """납품 정산 (좋은 피자처럼 정가 + 팁): 손님은 자기 예산만큼 내고, 별 1개당 예산의 5%를 팁으로 준다.
    별 0개면 절반만 낸다. 물건 값은 살 때 이미 냈으니, 싸게 맞출수록 남는다."""
    global money, stars_total
    budget = request()['budget']
    pay = budget if result['stars'] else budget // 2
    tip = result['stars'] * budget * TIP_RATE[level() - 1] // 100
    stars_total += result['stars']
    money += pay + tip
    ledger.append({'customer': request()['customer'], 'stars': result['stars'], 'pay': pay, 'tip': tip, 'cost': spent()})
    return pay, tip


def next_customer():
    """다음 손님이 있으면 True, 오늘 영업이 끝났으면 False."""
    global order_index
    order_index += 1
    return order_index < len(todays_requests())


if __name__ == '__main__':
    new_game()
    assert money == START_MONEY and len(todays_requests()) == 3
    assert not add_to_cart('cpu3')                     # 하이엔드 라인은 업그레이드 전엔 못 담는다
    assert add_to_cart('monitor', 2) and add_to_cart('monitor', -1) and cart == {'monitor': 1}
    receipt, total = checkout()
    assert receipt == {'monitor': 1} and total == 25 and money == START_MONEY - 25 and stock['monitor'] == 1 and cart == {}
    add_to_cart('cpu6', 100)
    assert checkout() is None and stock.get('cpu6') is None  # 돈이 모자라면 결제 안 됨
    cart.clear()
    assert sell_back('monitor') and money == START_MONEY - 25 + 12 and stock['monitor'] == 0
    assert not buy_upgrade('gamer')                  # 레벨 2부터
    stars_total = 4
    assert level() == 2 and buy_upgrade('gamer') and 'mic' in catalog()
    stars_total = 0
    add_to_cart('lamp_warm'); checkout()
    reset_order()
    assert take('lamp_warm') and not take('lamp_warm')
    room.place('lamp_warm', 'desk', 0)
    before = money
    pay, tip = settle({'stars': 2})
    assert pay == 100 and tip == 10 and money == before + pay + tip and ledger[-1]['cost'] == 4
    assert settle({'stars': 0}) == (50, 0) and stars_total == 2
    assert next_customer() and next_customer() and not next_customer()
    print('state ok')
