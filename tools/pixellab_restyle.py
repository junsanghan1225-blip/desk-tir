# PixelLab 그림이 없는 아이콘을 같은 화풍으로 바꿈: 기존 그림 → 128px 투명 캔버스, 위 밝고 아래 어두운 음영, 2px 어두운 외곽선.
#   python tools/pixellab_restyle.py           (대응표 · PixelLab 목록에 없는 소품 전부 + 어항 · 우드 케이스)
#   python tools/pixellab_restyle.py cactus    (하나만)
# 원본은 게임이 쓰던 순서 그대로: resource/real/<id>.png → resource/<id>.png. 결과는 resource/pixellab/<id>.png
import json, os, re, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixellab_draw import outline, OUT

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIT = 112   # 외곽선 2px 양쪽 + 여유


def src(name):
    real = os.path.join(ROOT, "resource", "real", name + ".png")
    return real if os.path.exists(real) else os.path.join(ROOT, "resource", name + ".png")


def restyle(name):
    im = Image.open(src(name)).convert("RGBA")
    im = im.crop(im.getbbox())
    k = FIT / max(im.size)
    if k >= 1:   # 작은 도트는 정수배 nearest로 키워 픽셀 그대로
        k = int(k)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    else:        # 큰 그림은 줄이되 알파는 0/255로 잘라 도트처럼
        im = im.resize((max(1, round(im.width * k)), max(1, round(im.height * k))), Image.BOX)
        im.putalpha(im.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    h = im.height
    px = im.load()
    for y in range(h):   # 위 +12% → 아래 -15% 음영
        f = 1.12 - 0.27 * y / max(1, h - 1)
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)), a)
    can = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    can.alpha_composite(im, ((128 - im.width) // 2, (128 - im.height) // 2))
    outline(can).save(os.path.join(OUT, name + ".png"))


def todo():
    s = open(os.path.join(ROOT, "godot", "db.gd"), encoding="utf-8").read()
    mapped = set(re.findall(r'"(\w+)": "\w+"', s[s.index("const PX :="):s.index("const PX_TYPE")]))
    items = json.load(open(os.path.join(ROOT, "data", "items.json"), encoding="utf-8"))
    mapped |= {it["id"] for it in json.load(open(os.path.join(ROOT, "tools", "pixellab_list.json"), encoding="utf-8"))}   # PixelLab 원본은 덮어쓰지 않음
    return [i["id"] for i in items if i["id"] not in mapped] + ["case4", "case5"]


def keyboards():   # 옆모습이라 실처럼 얇던 키보드는 위에서 본 PixelLab 키보드로: 화이트 = 그대로, 60% 미니 = 왼쪽만 잘라 붙임
    kb = Image.open(os.path.join(OUT, "kb_office.png"))
    kb.save(os.path.join(OUT, "kb_white.png"))
    l, t, r, b = kb.getbbox()
    w = int((r - l) * 0.62)
    mini = Image.new("RGBA", (w + 6, b - t), (0, 0, 0, 0))          # 왼쪽 62% + 원래 오른쪽 끝 6px(테두리)
    mini.paste(kb.crop((l, t, l + w, b)), (0, 0))
    mini.paste(kb.crop((r - 6, t, r, b)), (w, 0))
    can = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    can.alpha_composite(mini, ((128 - mini.width) // 2, (128 - mini.height) // 2))
    can.save(os.path.join(OUT, "kb_mini.png"))


if __name__ == "__main__":
    for n in sys.argv[1:] or todo():
        restyle(n)
    if not sys.argv[1:]:
        keyboards()
    print("완료")
