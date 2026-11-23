"""Stat + menu glyph icons in the same outlined/flat style as make_icons.py (supersampled PIL).

python3 tools/pipeline/make_icons_ui2.py assets/ui
"""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/ui"
os.makedirs(OUT, exist_ok=True)
S = 4
N = 128
OUTL = (40, 22, 10, 255)


def canvas():
    return Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))


def save(img, name, shadow=True):
    if shadow:
        a = img.split()[3]
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.5)))
        sh = sh.filter(ImageFilter.GaussianBlur(S * 3))
        base = Image.new("RGBA", img.size, (0, 0, 0, 0))
        base.alpha_composite(sh, (0, S * 3))
        base.alpha_composite(img)
        img = base
    img.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def P(x, y):
    return (x * S, y * S)


def poly(d, pts, fill, outline=OUTL, w=5):
    d.polygon([P(*p) for p in pts], fill=fill)
    if outline:
        d.line([P(*p) for p in pts + [pts[0]]], fill=outline, width=int(w * S), joint="curve")


def line(d, pts, fill, w):
    d.line([P(*p) for p in pts], fill=fill, width=int(w * S), joint="curve")
    for p in (pts[0], pts[-1]):
        r = w * 0.5
        d.ellipse([P(p[0] - r, p[1] - r), P(p[0] + r, p[1] + r)], fill=fill)


def circle(d, cx, cy, r, fill, outline=OUTL, w=5):
    d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill, outline=outline, width=int(w * S) if outline else 0)


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


STEEL, STEEL_HI, GOLD, GOLD_HI = (196, 206, 222, 255), (240, 246, 255, 255), (226, 160, 46, 255), (255, 214, 110, 255)

# sword (damage)
img = canvas(); d = ImageDraw.Draw(img)
blade = [(60, 14), (68, 14), (70, 82), (64, 92), (58, 82)]
guard = [(40, 82), (88, 82), (88, 92), (40, 92)]
grip = [(59, 92), (69, 92), (69, 112), (59, 112)]
for shape, col in ((blade, STEEL), (grip, (120, 66, 30, 255)), (guard, GOLD)):
    poly(d, rot(shape, 64, 64, 40), col)
line(d, rot([(64, 20), (64, 80)], 64, 64, 40), STEEL_HI, 3)
circle(d, *rot([(64, 116)], 64, 64, 40)[0], 7, GOLD)
save(img, "st_dmg")

# hourglass (attack interval)
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(36, 16), (92, 16), (92, 26), (36, 26)], (150, 92, 40, 255))
poly(d, [(36, 102), (92, 102), (92, 112), (36, 112)], (150, 92, 40, 255))
poly(d, [(42, 26), (86, 26), (68, 64), (86, 102), (42, 102), (60, 64)], (210, 236, 250, 220))
poly(d, [(50, 34), (78, 34), (64, 56)], (246, 206, 98, 255), None)
poly(d, [(64, 76), (82, 100), (46, 100)], (246, 206, 98, 255), None)
line(d, [(64, 58), (64, 92)], (246, 206, 98, 255), 3)
save(img, "st_rate")

# target (range)
img = canvas(); d = ImageDraw.Draw(img)
circle(d, 64, 64, 50, (230, 70, 60, 255))
circle(d, 64, 64, 36, (250, 244, 230, 255), OUTL, 4)
circle(d, 64, 64, 22, (230, 70, 60, 255), OUTL, 4)
circle(d, 64, 64, 9, (250, 244, 230, 255), OUTL, 3)
save(img, "st_range")

# shield (armor)
def shield(d, fill, rim, emblem=None):
    pts = [(28, 22), (64, 12), (100, 22), (98, 62)]
    for i in range(1, 12):
        k = i / 12
        pts.append((98 - 34 * k, 62 + 52 * (k ** 0.8)))
    for i in range(11, 0, -1):
        k = i / 12
        pts.append((30 + 34 * k, 62 + 52 * (k ** 0.8)))
    pts.append((30, 62))
    poly(d, pts, rim)
    inner = [(p[0] * 0.8 + 64 * 0.2, p[1] * 0.8 + 62 * 0.2) for p in pts]
    poly(d, inner, fill, None)
    return inner


img = canvas(); d = ImageDraw.Draw(img)
shield(d, (120, 136, 160, 255), (196, 206, 222, 255))
line(d, [(64, 30), (64, 100)], (226, 232, 244, 255), 6)
line(d, [(38, 56), (90, 56)], (226, 232, 244, 255), 6)
save(img, "st_armor")

# magic resist (blue shield + rune star)
img = canvas(); d = ImageDraw.Draw(img)
shield(d, (60, 92, 200, 255), (150, 190, 255, 255))
pts = []
for i in range(10):
    r = 26 if i % 2 == 0 else 11
    a = math.radians(-90 + i * 36)
    pts.append((64 + math.cos(a) * r, 62 + math.sin(a) * r))
poly(d, pts, (200, 236, 255, 255), (30, 40, 90, 255), 3)
save(img, "st_magic")

# speed (winged boot, simplified to a boot + motion lines)
img = canvas(); d = ImageDraw.Draw(img)
boot = [(52, 22), (80, 22), (80, 78), (110, 92), (110, 108), (46, 108), (46, 84), (52, 78)]
poly(d, boot, (150, 92, 48, 255))
poly(d, [(46, 100), (110, 100), (110, 108), (46, 108)], (90, 52, 24, 255), None)
for y in (40, 58, 76):
    line(d, [(14, y), (38, y)], (240, 240, 250, 255), 5)
save(img, "st_speed")

# helmet (soldier count)
img = canvas(); d = ImageDraw.Draw(img)
helm = [(30, 70)]
for i in range(19):
    a = math.radians(180 + i * 10)
    helm.append((64 + math.cos(a) * 36, 66 + math.sin(a) * 42))
helm += [(98, 70), (98, 96), (80, 96), (80, 78), (48, 78), (48, 96), (30, 96)]
poly(d, helm, STEEL)
poly(d, [(56, 36), (72, 36), (72, 78), (56, 78)], (150, 160, 178, 255), None)
poly(d, [(58, 10), (70, 10), (78, 30), (50, 30)], (220, 60, 50, 255))
save(img, "st_unit")

# retry (circular arrow)
img = canvas(); d = ImageDraw.Draw(img)
arc = []
for i in range(0, 300, 6):
    a = math.radians(i - 60)
    arc.append((64 + math.cos(a) * 38, 64 + math.sin(a) * 38))
line(d, arc, OUTL, 22)
line(d, arc, (250, 236, 200, 255), 12)
tip = arc[-1]
a = math.radians(300 - 60 + 90)
head = [(tip[0] + math.cos(a) * 20, tip[1] + math.sin(a) * 20), (tip[0] + math.cos(a + 2.3) * 22, tip[1] + math.sin(a + 2.3) * 22), (tip[0] + math.cos(a - 2.3) * 22, tip[1] + math.sin(a - 2.3) * 22)]
poly(d, head, (250, 236, 200, 255))
save(img, "ic_retry")

# play / next
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(36, 22), (106, 64), (36, 106)], (250, 236, 200, 255), OUTL, 6)
save(img, "ic_play")

# close (X)
img = canvas(); d = ImageDraw.Draw(img)
for a, b in (((30, 30), (98, 98)), ((98, 30), (30, 98))):
    line(d, [a, b], OUTL, 26)
for a, b in (((30, 30), (98, 98)), ((98, 30), (30, 98))):
    line(d, [a, b], (250, 236, 200, 255), 14)
save(img, "ic_close")

# map (folded parchment)
img = canvas(); d = ImageDraw.Draw(img)
panels = [[(14, 30), (46, 20), (46, 100), (14, 110)], [(46, 20), (82, 30), (82, 110), (46, 100)], [(82, 30), (114, 20), (114, 100), (82, 110)]]
for i, pnl in enumerate(panels):
    poly(d, pnl, (240, 222, 176, 255) if i != 1 else (222, 198, 146, 255))
line(d, [(24, 80), (40, 60), (58, 70), (74, 46), (98, 54)], (190, 60, 50, 255), 5)
circle(d, 98, 54, 7, (220, 60, 50, 255))
save(img, "ic_map")

# gear (settings)
img = canvas(); d = ImageDraw.Draw(img)
pts = []
for i in range(48):
    a = math.radians(i * 7.5)
    r = 52 if (i // 3) % 2 == 0 else 40
    pts.append((64 + math.cos(a) * r, 64 + math.sin(a) * r))
poly(d, pts, (196, 206, 222, 255))
circle(d, 64, 64, 18, (70, 80, 100, 255))
save(img, "ic_gear")

# book (bestiary)
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(18, 26), (62, 20), (62, 108), (18, 112)], (150, 50, 40, 255))
poly(d, [(66, 20), (110, 26), (110, 112), (66, 108)], (150, 50, 40, 255))
poly(d, [(24, 30), (60, 26), (60, 100), (24, 104)], (246, 234, 206, 255), None)
poly(d, [(68, 26), (104, 30), (104, 104), (68, 100)], (246, 234, 206, 255), None)
for y in (42, 54, 66, 78):
    line(d, [(30, y), (54, y - 3)], (160, 130, 100, 255), 3)
    line(d, [(74, y - 3), (98, y)], (160, 130, 100, 255), 3)
save(img, "ic_book")

# trophy (achievements)
img = canvas(); d = ImageDraw.Draw(img)
cup = [(30, 16), (98, 16), (94, 52), (78, 72), (50, 72), (34, 52)]
poly(d, cup, GOLD)
line(d, [(30, 26), (14, 30), (18, 50), (36, 56)], OUTL, 9)
line(d, [(98, 26), (114, 30), (110, 50), (92, 56)], OUTL, 9)
line(d, [(30, 26), (14, 30), (18, 50), (36, 56)], GOLD, 4)
line(d, [(98, 26), (114, 30), (110, 50), (92, 56)], GOLD, 4)
poly(d, [(56, 72), (72, 72), (74, 92), (54, 92)], GOLD)
poly(d, [(38, 92), (90, 92), (94, 112), (34, 112)], (150, 92, 40, 255))
line(d, [(44, 24), (46, 48)], GOLD_HI, 6)
save(img, "ic_trophy")

# helmet crest (heroes)
img = canvas(); d = ImageDraw.Draw(img)
crest = [(64, 10), (84, 24), (64, 34), (44, 24)]
poly(d, crest, (220, 60, 50, 255))
helm = [(26, 64)]
for i in range(19):
    a = math.radians(180 + i * 10)
    helm.append((64 + math.cos(a) * 38, 70 + math.sin(a) * 40))
helm += [(102, 64), (102, 112), (76, 112), (76, 82), (52, 82), (52, 112), (26, 112)]
poly(d, helm, GOLD)
line(d, [(40, 64), (88, 64)], OUTL, 6)
save(img, "ic_hero")

# star upgrade (kingdom upgrades)
img = canvas(); d = ImageDraw.Draw(img)
pts = []
for i in range(10):
    r = 52 if i % 2 == 0 else 22
    a = math.radians(-90 + i * 36)
    pts.append((64 + math.cos(a) * r, 68 + math.sin(a) * r))
poly(d, pts, GOLD)
poly(d, [(64, 40), (82, 62), (72, 62), (72, 86), (56, 86), (56, 62), (46, 62)], (255, 248, 220, 255), OUTL, 3)
save(img, "ic_upgrade")

# infinity (endless)
img = canvas(); d = ImageDraw.Draw(img)
pts = []
for i in range(121):
    t = i / 120 * 2 * math.pi
    s = 1 + math.sin(t) ** 2
    pts.append((64 + 44 * math.cos(t) / s, 64 + 44 * math.sin(t) * math.cos(t) / s))
line(d, pts, OUTL, 22)
line(d, pts, (190, 140, 255, 255), 12)
save(img, "ic_endless")

print("icons ->", OUT)
