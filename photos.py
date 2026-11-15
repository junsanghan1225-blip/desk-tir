"""책상 사진: 화면의 방 부분을 PNG로 저장하고(앨범용) 목록을 돌려준다. 저장 위치는 세이브 파일 옆 photos 폴더."""
import os
import time

import save_game


def folder():
    return os.path.join(os.path.dirname(save_game.PATH), 'photos')


def capture(rect, name=None):
    """rect = (x1, y1, x2, y2) 캔버스 좌표. 성공하면 파일 경로, 실패하면 None (게임은 계속)."""
    try:
        import pico2d.pico2d as p2
        from sdl2 import SDL_Rect, SDL_CreateRGBSurfaceWithFormat, SDL_RenderReadPixels, SDL_FreeSurface, SDL_PIXELFORMAT_RGB24
        from sdl2.sdlimage import IMG_SavePNG
        x1, y1, x2, y2 = rect
        w, h = x2 - x1, y2 - y1
        os.makedirs(folder(), exist_ok=True)
        path = os.path.join(folder(), (name or time.strftime('free_%Y%m%d_%H%M%S')) + '.png')
        surf = SDL_CreateRGBSurfaceWithFormat(0, w, h, 24, SDL_PIXELFORMAT_RGB24)
        SDL_RenderReadPixels(p2.renderer, SDL_Rect(x1, p2.canvas_height - y2, w, h), SDL_PIXELFORMAT_RGB24,
                             surf.contents.pixels, surf.contents.pitch)
        ok = IMG_SavePNG(surf, path.encode('utf-8')) == 0
        SDL_FreeSurface(surf)
        return path if ok else None
    except Exception as e:
        print('사진 저장 실패:', e)
        return None


def listing():
    """최근 것부터 사진 파일 경로."""
    try:
        files = [os.path.join(folder(), f) for f in os.listdir(folder()) if f.endswith('.png')]
    except OSError:
        return []
    return sorted(files, key=os.path.getmtime, reverse=True)


def caption(path):
    name = os.path.basename(path)[:-4]
    if name.startswith('day'):
        d, n = name[3:].split('_')[:2]
        return f"{d}일차 손님 {n} 납품"
    return '자유 촬영'
