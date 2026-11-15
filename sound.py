"""효과음 · 배경음. 소리 장치가 없거나 파일이 없어도 게임은 그대로 돌아간다 (전부 조용히 무시). M 키 = 음소거."""
import os

from common import BASE

DIR = os.path.join(BASE, 'resource', 'sfx')
muted = False
_wavs = {}
_bgm = None
_dead = False  # 소리를 쓸 수 없는 환경


def _ready():
    import pico2d.pico2d as p2
    return not _dead and getattr(p2, 'audio_on', False)


def play(name):
    global _dead
    if muted or not _ready():
        return
    try:
        if name not in _wavs:
            from pico2d import load_wav
            _wavs[name] = load_wav(os.path.join(DIR, name + '.wav'))
            _wavs[name].set_volume(70)
        _wavs[name].play()
    except Exception:
        _dead = True


def start_bgm():
    global _bgm, _dead
    if not _ready() or _bgm:
        return
    try:
        from pico2d import load_music
        _bgm = load_music(os.path.join(DIR, 'bgm.wav'))
        _bgm.set_volume(44)
        _bgm.repeat_play()
    except Exception:
        _dead = True


def toggle_mute():
    global muted
    muted = not muted
    if _bgm:
        _bgm.set_volume(0 if muted else 44)
