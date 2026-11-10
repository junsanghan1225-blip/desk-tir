from pico2d import *
import importlib

import game_framework
import request_mode
import save_game
import state
import ui
from common import WIDTH, HEIGHT, box, text, sprite, inside

message = ''
ESC = 'quit'
BTN_CONTINUE = (124, 300, 524, 352)
BTN_NEW = (124, 230, 524, 282)
saved = None


def init():
    global saved
    saved = save_game.peek()


def finish():
    pass


def continue_game():
    mode = save_game.load()
    if not mode:
        return new_game()
    game_framework.change_mode(importlib.import_module(mode))


def new_game():
    save_game.delete()
    state.new_game()
    game_framework.change_mode(request_mode)


def handle_event(e):
    if e.type == SDL_KEYDOWN and e.key == SDLK_RETURN:
        continue_game() if saved else new_game()
    elif e.type == SDL_MOUSEBUTTONDOWN:
        x, y = game_framework.mouse
        if saved and inside(x, y, BTN_CONTINUE):
            continue_game()
        elif inside(x, y, BTN_NEW if saved else BTN_CONTINUE):
            new_game()


def update():
    pass


def draw():
    sprite('title_bg').draw(WIDTH // 2, HEIGHT // 2)
    text(120, 470, '데스크테리어 의뢰소', 64, (255, 77, 141))
    text(124, 400, '손님의 애매한 주문을 읽고, 책상을 꾸미고 PC를 조립해 주세요', 22, (200, 192, 240))
    if saved:
        ui.button(BTN_CONTINUE, f"이어하기  ·  {saved['day']}일차 · 가게 돈 {saved['money']}만 [Enter]", (255, 77, 141))
        ui.button(BTN_NEW, '새 게임 (저장 기록이 지워져요)', (124, 92, 255))
    else:
        ui.button(BTN_CONTINUE, '새 게임 시작 [Enter]', (255, 77, 141))
    text(124, 196, '진행은 화면이 바뀔 때마다 자동으로 저장돼요', 15, (170, 160, 220))
    if message:
        text(124, 610, message, 20, (120, 255, 170))
