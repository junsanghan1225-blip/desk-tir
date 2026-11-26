# PixelLab 크레딧이 떨어진 그림을 같은 화풍(128px 투명 · 어두운 외곽선 · 위 밝고 아래 어두운 음영)으로 직접 그림.
#   python tools/pixellab_draw.py            (전부)
#   python tools/pixellab_draw.py psu        (하나만)
# 결과는 resource/pixellab/<id>.png 를 덮어씀.
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "resource", "pixellab")
LINE = (18, 12, 30, 255)
GOLD, GOLD_D = (230, 186, 70), (160, 112, 40)
PCB, PCB_D = (40, 110, 70), (24, 70, 44)
RAINBOW = [(255, 70, 90), (255, 160, 60), (250, 230, 80), (90, 220, 120), (70, 170, 255), (170, 100, 255)]


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3]) + (255,)


def box(d, r, c, bevel=True):
    """평면 상자: 위 2px 밝게, 아래 2px 어둡게."""
    x0, y0, x1, y1 = r
    d.rectangle(r, fill=shade(c, 1))
    if bevel:
        d.rectangle([x0, y0, x1, y0 + 1], fill=shade(c, 1.35))
        d.rectangle([x0, y1 - 1, x1, y1], fill=shade(c, 0.65))


def fan(d, cx, cy, rad, c=(60, 60, 72)):
    d.ellipse([cx - rad, cy - rad, cx + rad, cy + rad], fill=shade(c, 0.6))
    d.ellipse([cx - rad + 3, cy - rad + 3, cx + rad - 3, cy + rad - 3], fill=shade(c, 0.9))
    for a in range(0, 360, 60):   # 날개 6장
        t = math.radians(a)
        d.line([cx, cy, cx + math.cos(t) * (rad - 4), cy + math.sin(t) * (rad - 4)], fill=shade(c, 1.5), width=3)
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=shade(c, 0.5))


def outline(im, px=2):
    a = im.getchannel("A")
    grown = a
    for _ in range(px):
        grown = grown.filter(ImageFilter.MaxFilter(3))
    ring = ImageChops.subtract(grown, a)
    base = Image.new("RGBA", im.size, LINE)
    base.putalpha(ring)
    base.alpha_composite(im)
    return base


def gpu_low(d):   # 옆에서 본 짧은 저가 그래픽카드: 검은 덮개 + 팬 1개, 브래킷, 금색 단자
    box(d, [20, 40, 104, 84], (44, 44, 52))
    fan(d, 62, 62, 18)
    d.rectangle([104, 34, 110, 92], fill=(170, 172, 182))            # 브래킷
    d.rectangle([104, 34, 110, 35], fill=(220, 222, 230))
    box(d, [26, 84, 96, 90], PCB, False)
    for x in range(40, 94, 4):
        d.rectangle([x, 90, x + 2, 95], fill=GOLD)


def ram_rgb(d):   # 가로로 누운 RAM 한 개: 검은 방열판 + 위 무지개 띠 + 아래 금색 단자
    box(d, [10, 50, 118, 82], (38, 38, 46))
    for i, c in enumerate(RAINBOW):
        d.rectangle([10 + i * 18, 42, 10 + (i + 1) * 18 - 1, 49], fill=c)
    d.rectangle([10, 42, 117, 43], fill=(255, 255, 255, 255))
    d.rectangle([40, 60, 88, 70], fill=(70, 70, 84))                 # 로고 판
    box(d, [12, 82, 116, 88], PCB, False)
    for x in range(14, 114, 4):
        if x != 62:                                                  # 가운데 홈
            d.rectangle([x, 88, x + 2, 94], fill=GOLD)


def ssd_m2(d):   # 위에서 본 긴 M.2 SSD: 초록 기판 + 검은 스티커 + 한쪽 끝 금색 단자
    box(d, [12, 50, 112, 78], PCB)
    d.rectangle([24, 54, 100, 74], fill=(28, 28, 36))
    d.rectangle([30, 58, 70, 61], fill=(200, 200, 210))
    d.rectangle([30, 65, 56, 67], fill=(120, 120, 136))
    d.ellipse([10, 59, 18, 67], fill=GOLD_D)                         # 나사 구멍
    d.ellipse([12, 61, 16, 65], fill=(0, 0, 0, 0))
    for y in range(52, 77, 3):
        d.rectangle([112, y, 117, y + 1], fill=GOLD)


def ssd_sata(d):   # 위에서 본 납작한 2.5인치 SSD: 회색 금속 + 흰 라벨 + 끝의 SATA 단자
    box(d, [22, 30, 106, 98], (92, 96, 110))
    d.rectangle([34, 42, 94, 80], fill=(236, 236, 244))
    d.rectangle([40, 48, 78, 52], fill=(60, 60, 80))
    d.rectangle([40, 58, 88, 60], fill=(150, 150, 170))
    d.rectangle([40, 64, 70, 66], fill=(150, 150, 170))
    d.rectangle([44, 98, 84, 104], fill=(30, 30, 38))
    for x in range(46, 82, 3):
        d.rectangle([x, 100, x + 1, 103], fill=GOLD)
    for x, y in [(26, 34), (98, 34), (26, 90), (98, 90)]:
        d.rectangle([x, y, x + 3, y + 3], fill=(60, 62, 72))


def psu(d):   # 위에서 본 파워: 검은 상자 + 큰 둥근 팬 그릴 + 뒤쪽 전원 단자
    box(d, [18, 26, 110, 104], (46, 46, 54))
    cx, cy, r = 64, 64, 32
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(24, 24, 30))
    for k in range(r, 4, -6):                                        # 동심원 그릴
        d.ellipse([cx - k, cy - k, cx + k, cy + k], outline=(110, 112, 124), width=2)
    d.line([cx - r, cy, cx + r, cy], fill=(110, 112, 124), width=2)
    d.line([cx, cy - r, cx, cy + r], fill=(110, 112, 124), width=2)
    d.rectangle([24, 30, 40, 38], fill=(240, 196, 60))               # 라벨
    d.rectangle([92, 92, 104, 100], fill=(20, 20, 24))               # 전원 단자
    d.rectangle([95, 95, 101, 97], fill=(90, 90, 100))


def mouse_gaming(d):   # 위에서 본 게이밍 마우스: 검은 몸통 + 가운데 RGB 띠
    d.ellipse([38, 20, 90, 110], fill=(40, 40, 50))
    d.ellipse([42, 22, 86, 60], fill=(56, 56, 68))
    d.line([64, 22, 64, 56], fill=(20, 20, 26), width=2)             # 좌우 버튼 사이
    d.rounded_rectangle([60, 34, 68, 46], 3, fill=(110, 110, 124))   # 휠
    for i, c in enumerate(RAINBOW):                                  # 몸통 RGB 띠
        d.rectangle([46 + i * 6, 76, 46 + i * 6 + 5, 80], fill=c)
    d.ellipse([50, 92, 78, 104], fill=(30, 30, 38))


def light_bar(d):   # 옆에서 본 모니터 라이트바: 가로 막대 + 아래 흰 발광면 + 모니터 위에 거는 집게
    box(d, [14, 44, 114, 56], (60, 60, 70))
    d.rectangle([20, 54, 108, 58], fill=(255, 252, 230))             # 발광면
    box(d, [58, 58, 70, 86], (52, 52, 60))                           # 모니터 뒤로 내려가는 집게
    box(d, [50, 86, 78, 92], (52, 52, 60))


DRAW = {f.__name__: f for f in [gpu_low, ram_rgb, ssd_m2, ssd_sata, psu, mouse_gaming, light_bar]}

if __name__ == "__main__":
    for name in sys.argv[1:] or DRAW:
        im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        DRAW[name](ImageDraw.Draw(im))
        outline(im).save(os.path.join(OUT, name + ".png"))
        print("그림", name)
