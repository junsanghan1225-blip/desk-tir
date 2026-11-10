from pico2d import *

import game_framework
import market_mode
import state
from common import WIDTH, HEIGHT, box, text, sprite

message = ''


def init():
    pass


def finish():
    pass


def handle_events():
    for e in get_events():
        if e.type == SDL_QUIT or (e.type == SDL_KEYDOWN and e.key == SDLK_ESCAPE):
            game_framework.quit()
        elif e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
            state.new_game()
            game_framework.change_mode(market_mode)


def update():
    pass


def draw():
    clear_canvas()
    sprite('title_bg').draw(WIDTH // 2, HEIGHT // 2)
    text(120, 470, '데스크테리어 의뢰소', 64, (255, 77, 141))
    text(124, 400, '손님의 애매한 주문을 읽고, 책상을 꾸미고 PC를 조립해 주세요', 22, (200, 192, 240))
    text(124, 350, '클릭하거나 Enter를 눌러 시작', 22, (46, 230, 214))
    if message:
        text(124, 610, message, 20, (120, 255, 170))
    update_canvas()
