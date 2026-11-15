from pico2d import open_canvas, close_canvas, SDLK_m

import game_framework
import pause_mode
import save_game
import sound
import title_mode
from common import WIDTH, HEIGHT

open_canvas(WIDTH, HEIGHT)
sound.start_bgm()
game_framework.pause_mode = pause_mode
game_framework.on_change = save_game.save
game_framework.hotkeys = {SDLK_m: sound.toggle_mute}
game_framework.run(title_mode, HEIGHT)
close_canvas()
