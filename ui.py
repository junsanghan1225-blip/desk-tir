"""여러 화면이 함께 쓰는 상단 바와 버튼."""
from common import WIDTH, HEIGHT, box, outline, text, inside
import state

DARK = (18, 12, 38)
BAR = (24, 16, 52)
AMBER = (46, 230, 214)
PINK = (255, 77, 141)
WHITE = (255, 255, 255)
QUIET = (170, 160, 220)


def shop_bar(title):
    """가게 정보만 있는 상단 바 (아침 시장 · 정산)."""
    box(0, HEIGHT - 70, WIDTH, HEIGHT, BAR)
    box(0, HEIGHT - 72, WIDTH, HEIGHT - 70, PINK)
    text(20, HEIGHT - 36, f"{state.day}일차  ·  {title}", 22, AMBER)
    text(WIDTH - 260, HEIGHT - 36, f"가게 돈  {state.money}만 원", 22, WHITE)


def top_bar():
    """주문 중 상단 바: 손님 한마디 + 손님 예산 대비 사용액."""
    req = state.request()
    box(0, HEIGHT - 70, WIDTH, HEIGHT, BAR)
    box(0, HEIGHT - 72, WIDTH, HEIGHT - 70, PINK)
    n = len(state.todays_requests())
    text(20, HEIGHT - 24, f"{state.day}일차 손님 {state.order_index + 1}/{n}  ·  {req['customer']}", 20, AMBER)
    text(20, HEIGHT - 52, f"\"{req['lines'][0]}\"", 16, WHITE)
    left = state.money_left()
    text(WIDTH - 200, HEIGHT - 24, f"손님 예산 {req['budget']}만", 16, QUIET)
    text(WIDTH - 200, HEIGHT - 52, f"남은 예산 {left}만", 18, AMBER if left >= 0 else PINK)


def button(rect, label, color=AMBER):
    box(*rect, color)
    outline(*rect)
    text(rect[0] + 14, (rect[1] + rect[3]) // 2, label, 18, DARK)


def clicked(rect, x, y):
    return inside(x, y, rect)


WORK_TABS = [('shop', '1 쇼핑'), ('decorate', '2 책상'), ('build', '3 PC 조립'), ('wire', '4 배선')]
TAB_Y1, TAB_Y2, TAB_X0, TAB_W = 656, 690, 560, 112


def tab_rect(i):
    x = TAB_X0 + i * (TAB_W + 6)
    return x, TAB_Y1, x + TAB_W, TAB_Y2


def work_tabs(current):
    """주문 작업 화면 사이를 오가는 탭 (상단 바 가운데)."""
    for i, (key, label) in enumerate(WORK_TABS):
        r = tab_rect(i)
        on = key == current
        box(*r, (124, 92, 255) if on else (34, 24, 70))
        outline(*r, AMBER if on else (90, 78, 130))
        text(r[0] + 10, (r[1] + r[3]) // 2, label, 15, WHITE if on else QUIET)
        if key == 'wire' and wiring_issue():
            box(r[2] - 16, r[3] - 16, r[2] - 6, r[3] - 6, PINK)  # 미연결 · 꼬임이 있으면 빨간 점


def wiring_issue():
    import cables
    _, unplugged, tangles = cables.wiring_score(state.cables, state.room)
    return bool(unplugged or tangles)


def tab_at(x, y):
    for i, (key, _) in enumerate(WORK_TABS):
        if inside(x, y, tab_rect(i)):
            return key
    return None


def goto_tab(key):
    """탭 이름 → 그 화면으로 전환 (모듈끼리 서로 import 하지 않게 여기서 늦게 불러온다)."""
    import game_framework, shop_mode, decorate_mode, build_mode, wire_mode
    game_framework.change_mode({'shop': shop_mode, 'decorate': decorate_mode, 'build': build_mode, 'wire': wire_mode}[key])


def tab_key(e):
    """숫자 1 · 2 · 3 · 4 키 → 탭 이름."""
    from pico2d import SDL_KEYDOWN, SDLK_1, SDLK_2, SDLK_3, SDLK_4
    if e.type == SDL_KEYDOWN:
        return {SDLK_1: 'shop', SDLK_2: 'decorate', SDLK_3: 'build', SDLK_4: 'wire'}.get(e.key)
    return None
