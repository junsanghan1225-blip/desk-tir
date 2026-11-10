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
    text(WIDTH - 330, HEIGHT - 24, f"손님 예산 {req['budget']}만", 18, QUIET)
    text(WIDTH - 330, HEIGHT - 52, f"남은 예산 {left}만 원", 20, AMBER if left >= 0 else PINK)


def button(rect, label, color=AMBER):
    box(*rect, color)
    outline(*rect)
    text(rect[0] + 14, (rect[1] + rect[3]) // 2, label, 18, DARK)


def clicked(rect, x, y):
    return inside(x, y, rect)
