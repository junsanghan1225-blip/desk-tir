"""하루 시작: 오늘의 날씨와 뉴스 한 줄 (오늘 올 손님에 대한 힌트)."""
from pico2d import *

import game_framework
import request_mode
import state
from common import WIDTH, HEIGHT, box, outline, text, sprite

WEATHER_NAMES = {'rain': '비', 'night': '맑은 밤', 'sunset': '노을', 'snow': '눈', 'sunny': '맑음'}


def init():
    state.start_day()


def finish():
    pass


def handle_event(e):
    if e.type == SDL_MOUSEBUTTONDOWN or (e.type == SDL_KEYDOWN and e.key == SDLK_RETURN):
        game_framework.change_mode(request_mode)


def update():
    pass


def draw():
    d = state.today()
    box(0, 0, WIDTH, HEIGHT, (18, 12, 38))
    sprite('room_bg_' + d['weather']).clip_draw(28, 650 - 432, 744, 190, WIDTH // 2, 470, 1040, 266)  # 창밖 풍경만 크게
    text(120, 660, f"{state.day}일차 아침  ·  오늘 날씨: {WEATHER_NAMES[d['weather']]}", 24, (46, 230, 214))
    box(120, 180, 1160, 310, (34, 24, 70))
    outline(120, 180, 1160, 310, (255, 77, 141))
    text(150, 270, d['news'], 22)
    text(150, 222, d['hint'], 17, (255, 214, 92))
    text(120, 130, f"가게 돈 {state.money}만 원  ·  가게 레벨 {state.level()}  ·  오늘 손님 {len(state.todays_requests())}명", 17, (170, 160, 220))
    text(120, 80, '클릭해서 가게 열기', 18, (140, 128, 200))
