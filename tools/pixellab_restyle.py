# PixelLab 그림을 못 쓰는 소품을 같은 화풍으로: 기존 그림에 위 밝고 아래 어두운 음영 + 2px 어두운 외곽선.
# 크기는 그대로(책상 위 실제 비율 그림이라 쇼핑 아이콘 · 책상 배치가 같은 그림을 씀). 색 바꾸기(__c1~3)도 같이.
#   python tools/pixellab_restyle.py           (소품 전부 + 어항 · 우드 케이스)
#   python tools/pixellab_restyle.py cactus    (하나만, 색 포함)
# 원본은 게임이 쓰던 순서 그대로: resource/real/<name>.png → resource/<name>.png. 결과는 resource/styled/<name>.png
import json, os, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_draw import outline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "resource", "styled")


def src(name):
    real = os.path.join(ROOT, "resource", "real", name + ".png")
    return real if os.path.exists(real) else os.path.join(ROOT, "resource", name + ".png")


def restyle(name):
    im = Image.open(src(name)).convert("RGBA")
    px = im.load()
    for y in range(im.height):   # 위 +12% → 아래 -15% 음영
        f = 1.12 - 0.27 * y / max(1, im.height - 1)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)
    can = Image.new("RGBA", (im.width + 4, im.height + 4), (0, 0, 0, 0))   # 외곽선 자리 2px씩
    can.alpha_composite(im, (2, 2))
    outline(can).save(os.path.join(OUT, name + ".png"))


def names(ids):
    return [n for i in ids for n in [i] + [f"{i}__c{k}" for k in (1, 2, 3)] if os.path.exists(src(n))]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    ids = sys.argv[1:] or [i["id"] for i in json.load(open(os.path.join(ROOT, "data", "items.json"), encoding="utf-8"))] + ["case4", "case5"]
    for n in names(ids):
        restyle(n)
    print("완료")
