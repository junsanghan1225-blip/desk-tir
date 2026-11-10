from pico2d import open_canvas, close_canvas

import game_framework
import pause_mode
import save_game
import title_mode
from common import WIDTH, HEIGHT

open_canvas(WIDTH, HEIGHT)
game_framework.pause_mode = pause_mode
game_framework.on_change = save_game.save
game_framework.run(title_mode, HEIGHT)
close_canvas()
