# PixelLab 그림 모아보기: resource/pixellab/*.png → build/pixellab_sheet.png
# 어두운 배경(#18122C), 2배 nearest 확대, 아래에 id. 목록(json) 순서대로, 없는 건 빈칸.
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "resource", "pixellab")
OUT = os.path.join(ROOT, "build", "pixellab_sheet.png")
CELL, LABEL, COLS = 256, 34, 8

ids = [it["id"] for it in json.load(open(os.path.join(ROOT, "tools", "pixellab_list.json"), encoding="utf-8"))]
rows = (len(ids) + COLS - 1) // COLS
sheet = Image.new("RGBA", (COLS * CELL, rows * (CELL + LABEL)), "#18122C")
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype("arial.ttf", 22)
for n, pid in enumerate(ids):
    x, y = n % COLS * CELL, n // COLS * (CELL + LABEL)
    path = os.path.join(SRC, pid + ".png")
    if os.path.exists(path):
        im = Image.open(path).convert("RGBA")
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        sheet.alpha_composite(im, (x + (CELL - im.width) // 2, y + (CELL - im.height) // 2))
    draw.text((x + CELL // 2, y + CELL + 4), pid, fill="#E8E0FF" if os.path.exists(path) else "#6A5F8A", font=font, anchor="ma")
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT)
print(OUT)
