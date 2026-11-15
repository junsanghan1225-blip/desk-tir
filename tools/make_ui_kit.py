"""픽셀 UI 부품 (Skul · Dead Cells 느낌): 모서리를 깎은 두꺼운 테두리 판 · 두께 있는 버튼 · 안으로 파인 칸.
16x16 픽셀로 그리고 3배로 키운다 (Godot에서 9-slice, 테두리 12px).  실행: python tools/make_ui_kit.py"""
from PIL import Image

S = 16
SCALE = 3
INK = (5, 3, 12, 255)


def depth(x, y, cut):
    """테두리에서 몇 칸 안쪽인지 (모서리는 cut만큼 깎임). 음수면 바깥."""
    e = [x, y, S - 1 - x, S - 1 - y]
    return min(*e, x + y - cut, S - 1 - x + y - cut, x + S - 1 - y - cut, 2 * S - 2 - x - y - cut)


def lit(x, y):
    """빛이 왼쪽 위에서 온다: 왼쪽 · 위 테두리가 밝다."""
    return x + y < S - 1


def make(name, cut, paint):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    for y in range(S):
        for x in range(S):
            d = depth(x, y, cut)
            if d >= 0:
                img.putpixel((x, y), INK if d == 0 else paint(x, y, d))
    img.resize((S * SCALE, S * SCALE), Image.NEAREST).save(f"resource/{name}.png")


def panel(light, dark, fill):
    def paint(x, y, d):
        if d == 1:
            return light if lit(x, y) else dark
        if d == 2:
            return (11, 7, 24, 255)
        if x % 4 == 0 and y % 4 == 2:  # 바닥 질감 (도트)
            return tuple(min(255, c + 9) for c in fill[:3]) + (255,)
        return fill
    return paint


def button(x, y, d):
    """흰 바탕: Godot에서 색을 곱해 쓴다. 아래 3줄이 버튼 두께."""
    from_bottom = S - 1 - y
    if from_bottom <= 2:
        return (110, 110, 110, 255) if from_bottom else (80, 80, 80, 255)
    if y <= 2:
        return (255, 255, 255, 255)
    if x <= 1:
        return (240, 240, 240, 255)
    if x >= S - 2:
        return (175, 175, 175, 255)
    return (215, 215, 215, 255)


def slot(x, y, d):
    if d == 1:
        return (8, 5, 18, 255) if lit(x, y) else (58, 45, 110, 255)
    return (20, 14, 42, 255)


make("ui_panel", 2, panel((106, 86, 184, 255), (51, 38, 106, 255), (29, 21, 56, 255)))
make("ui_panel_pink", 2, panel((255, 77, 141, 255), (140, 34, 82, 255), (34, 20, 52, 255)))
make("ui_button", 1, button)
make("ui_slot", 1, slot)
print("ui kit ok")
