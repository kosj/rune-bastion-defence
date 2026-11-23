"""Procedural UI icons (supersampled PIL vector drawing)."""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
S = 4  # supersample
N = 128


def canvas():
    return Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))


def save(img, name, shadow=True):
    if shadow:
        a = img.split()[3]
        sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sh.putalpha(a.point(lambda v: int(v * 0.55)))
        sh = sh.filter(ImageFilter.GaussianBlur(S * 3))
        base = Image.new("RGBA", img.size, (0, 0, 0, 0))
        base.alpha_composite(sh, (0, S * 3))
        base.alpha_composite(img)
        img = base
    img = img.resize((N, N), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))


def P(x, y):
    return (x * S, y * S)


def poly(d, pts, fill, outline=None, w=0):
    d.polygon([P(*p) for p in pts], fill=fill)
    if outline:
        d.line([P(*p) for p in pts + [pts[0]]], fill=outline, width=w * S, joint="curve")


def circle(d, cx, cy, r, fill, outline=None, w=0):
    d.ellipse([P(cx - r, cy - r), P(cx + r, cy + r)], fill=fill, outline=outline, width=w * S)


def star_pts(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


OUTL = (40, 22, 10, 255)

# coin
img = canvas(); d = ImageDraw.Draw(img)
circle(d, 64, 64, 54, (176, 112, 22, 255), OUTL, 5)
circle(d, 64, 64, 44, (250, 198, 70, 255))
circle(d, 60, 58, 36, (255, 222, 120, 255))
poly(d, star_pts(64, 64, 24, 10), (196, 128, 26, 255))
save(img, "coin")

# heart
img = canvas(); d = ImageDraw.Draw(img)
pts = []
for i in range(100):
    t = i / 100 * 2 * math.pi
    x = 16 * math.sin(t) ** 3
    y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
    pts.append((64 + x * 3.3, 60 + y * 3.3))
poly(d, pts, (220, 50, 60, 255), OUTL, 5)
circle(d, 44, 42, 9, (255, 150, 150, 200))
save(img, "heart")

# skull
def skull(d, cx, cy, s=1.0, col=(240, 232, 214, 255)):
    circle(d, cx, cy - 6 * s, 38 * s, col, OUTL, 5)
    d.rounded_rectangle([P(cx - 22 * s, cy + 14 * s), P(cx + 22 * s, cy + 40 * s)], radius=8 * S, fill=col, outline=OUTL, width=5 * S)
    circle(d, cx - 15 * s, cy - 2 * s, 11 * s, (40, 20, 20, 255))
    circle(d, cx + 15 * s, cy - 2 * s, 11 * s, (40, 20, 20, 255))
    poly(d, [(cx, cy + 10 * s), (cx - 6 * s, cy + 20 * s), (cx + 6 * s, cy + 20 * s)], (40, 20, 20, 255))
    for k in (-10, 0, 10):
        d.line([P(cx + k * s, cy + 26 * s), P(cx + k * s, cy + 38 * s)], fill=(60, 40, 30, 255), width=3 * S)

img = canvas(); d = ImageDraw.Draw(img); skull(d, 64, 58, 1.0); save(img, "skull")
img = canvas(); d = ImageDraw.Draw(img)
for k, c in ((0, (255, 120, 30, 255)), (1, (255, 200, 60, 255))):
    for i in range(7):
        a = math.radians(-160 + i * 23)
        r = 56 - k * 8
        poly(d, [(64 + math.cos(a - 0.2) * 30, 64 + math.sin(a - 0.2) * 30), (64 + math.cos(a) * r, 64 + math.sin(a) * r), (64 + math.cos(a + 0.2) * 30, 64 + math.sin(a + 0.2) * 30)], c)
skull(d, 64, 66, 0.85)
save(img, "wave_call")

# speed / pause
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(42, 30), (94, 64), (42, 98)], (250, 240, 220, 255), OUTL, 5)
save(img, "speed1")
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(22, 32), (64, 64), (22, 96)], (255, 210, 90, 255), OUTL, 5)
poly(d, [(62, 32), (104, 64), (62, 96)], (255, 210, 90, 255), OUTL, 5)
save(img, "speed2")
img = canvas(); d = ImageDraw.Draw(img)
for x in (40, 74):
    d.rounded_rectangle([P(x, 30), P(x + 16, 98)], radius=4 * S, fill=(250, 240, 220, 255), outline=OUTL, width=5 * S)
save(img, "pause")

# check
img = canvas(); d = ImageDraw.Draw(img)
circle(d, 64, 64, 52, (60, 170, 80, 255), OUTL, 5)
d.line([P(38, 66), P(56, 84), P(92, 44)], fill=(255, 255, 255, 255), width=14 * S, joint="curve")
save(img, "check")

# upgrade arrow
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(64, 16), (108, 62), (82, 62), (82, 108), (46, 108), (46, 62), (20, 62)], (255, 200, 60, 255), OUTL, 5)
poly(d, [(64, 26), (90, 54), (64, 54)], (255, 236, 150, 255))
save(img, "upgrade")

# sell: coins stack
img = canvas(); d = ImageDraw.Draw(img)
for i, y in enumerate((92, 78, 64)):
    d.ellipse([P(30, y - 12), P(98, y + 12)], fill=(200, 140, 30, 255), outline=OUTL, width=4 * S)
    d.ellipse([P(36, y - 16), P(92, y + 6)], fill=(250, 205, 80, 255))
circle(d, 64, 38, 22, (250, 205, 80, 255), OUTL, 4)
poly(d, star_pts(64, 38, 12, 5), (196, 128, 26, 255))
save(img, "sell")

# rally flag
img = canvas(); d = ImageDraw.Draw(img)
d.rounded_rectangle([P(34, 16), P(44, 112)], radius=3 * S, fill=(120, 80, 40, 255), outline=OUTL, width=4 * S)
poly(d, [(44, 20), (104, 34), (84, 48), (104, 62), (44, 66)], (60, 120, 230, 255), OUTL, 5)
circle(d, 39, 16, 7, (255, 210, 80, 255), OUTL, 3)
save(img, "rally")

# stars
img = canvas(); d = ImageDraw.Draw(img)
poly(d, star_pts(64, 66, 58, 25), (255, 205, 50, 255), OUTL, 5)
poly(d, star_pts(58, 58, 30, 12), (255, 236, 140, 255))
save(img, "star")
img = canvas(); d = ImageDraw.Draw(img)
poly(d, star_pts(64, 66, 58, 25), (70, 72, 90, 255), (25, 25, 35, 255), 5)
save(img, "star_empty")

# lock
img = canvas(); d = ImageDraw.Draw(img)
d.arc([P(36, 18), P(92, 78)], 180, 360, fill=(180, 180, 190, 255), width=12 * S)
d.rounded_rectangle([P(26, 56), P(102, 112)], radius=10 * S, fill=(200, 160, 60, 255), outline=OUTL, width=5 * S)
circle(d, 64, 80, 8, (60, 40, 20, 255))
save(img, "lock")

# flame (skill)
def flame(d, cx, cy, s, c1, c2):
    pts = []
    for i in range(60):
        t = i / 60 * 2 * math.pi
        r = 1.0
        x = math.sin(t) * (0.55 + 0.25 * math.cos(t))
        y = -math.cos(t) * 1.0
        if y < 0:
            x *= (1 + y) ** 1.4 + 0.05
        pts.append((cx + x * 40 * s, cy + y * 48 * s))
    poly(d, pts, c1, OUTL, 4)
    pts2 = [(cx + (px - cx) * 0.55, cy + 14 * s + (py - cy) * 0.55) for px, py in pts]
    poly(d, pts2, c2)

img = canvas(); d = ImageDraw.Draw(img)
flame(d, 64, 68, 1.0, (240, 90, 30, 255), (255, 210, 90, 255))
d.arc([P(14, 14), P(114, 114)], 200, 330, fill=(255, 180, 60, 255), width=8 * S)
d.arc([P(14, 14), P(114, 114)], 20, 150, fill=(255, 180, 60, 255), width=8 * S)
save(img, "skill_fire")

# meteor
img = canvas(); d = ImageDraw.Draw(img)
for k in range(4):
    off = k * 9
    poly(d, [(18 + off, 18 - off * 0.2), (70 + off * 0.3, 52), (56, 72 + off * 0.2)], (255, 120 + k * 30, 40, 180 - k * 30))
circle(d, 76, 76, 30, (230, 90, 30, 255), OUTL, 5)
circle(d, 70, 70, 18, (255, 200, 80, 255))
circle(d, 84, 86, 6, (150, 50, 20, 255))
save(img, "spell_meteor")

# reinforce: shield + swords
img = canvas(); d = ImageDraw.Draw(img)
for a in (-1, 1):
    d.line([P(64 - a * 44, 20), P(64 + a * 40, 104)], fill=(210, 215, 225, 255), width=9 * S)
    d.line([P(64 - a * 44, 20), P(64 + a * 40, 104)], fill=(250, 250, 255, 255), width=3 * S)
    d.line([P(64 + a * 26, 86), P(64 + a * 48, 74)], fill=(200, 150, 50, 255), width=8 * S)
poly(d, [(64, 26), (100, 38), (96, 76), (64, 108), (32, 76), (28, 38)], (50, 100, 210, 255), OUTL, 5)
poly(d, [(64, 36), (90, 45), (87, 74), (64, 98)], (90, 140, 240, 255))
poly(d, star_pts(64, 64, 16, 7), (255, 255, 255, 255))
save(img, "spell_reinforce")

# mastery badges
def badge(name, col, glyph):
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 64, 64, 54, col, OUTL, 5)
    circle(d, 64, 64, 44, tuple(min(255, int(c * 1.25)) for c in col[:3]) + (255,))
    glyph(d)
    poly(d, star_pts(100, 26, 18, 8), (255, 210, 60, 255), OUTL, 3)
    save(img, name)

W = (255, 255, 255, 255)
badge("m_ranger", (50, 140, 60, 255), lambda d: [d.arc([P(36, 30), P(76, 98)], 270, 90, fill=W, width=7 * S), d.line([P(56, 30), P(56, 98)], fill=W, width=3 * S),
      d.line([P(40, 64), P(96, 64)], fill=W, width=5 * S), d.line([P(40, 50), P(92, 50)], fill=W, width=4 * S), d.line([P(40, 78), P(92, 78)], fill=W, width=4 * S)])
badge("m_marksman", (170, 130, 30, 255), lambda d: [d.ellipse([P(34, 34), P(94, 94)], outline=W, width=6 * S), d.ellipse([P(54, 54), P(74, 74)], fill=W),
      d.line([P(64, 22), P(64, 44)], fill=W, width=5 * S), d.line([P(64, 84), P(64, 106)], fill=W, width=5 * S), d.line([P(22, 64), P(44, 64)], fill=W, width=5 * S), d.line([P(84, 64), P(106, 64)], fill=W, width=5 * S)])
badge("m_arcane", (110, 50, 170, 255), lambda d: poly(d, [(70, 22), (40, 70), (62, 70), (52, 106), (90, 54), (68, 54), (80, 22)], (255, 240, 120, 255), OUTL, 3))
def snow(d):
    for i in range(3):
        a = math.radians(i * 60)
        d.line([P(64 - math.cos(a) * 36, 64 - math.sin(a) * 36), P(64 + math.cos(a) * 36, 64 + math.sin(a) * 36)], fill=W, width=7 * S)
    circle(d, 64, 64, 9, W)
badge("m_frost", (40, 120, 190, 255), snow)
badge("m_bombard", (170, 70, 30, 255), lambda d: [circle(d, 60, 70, 28, (40, 40, 45, 255), OUTL, 3), d.line([P(78, 48), P(92, 30)], fill=(200, 170, 120, 255), width=5 * S), circle(d, 94, 28, 8, (255, 200, 60, 255))])
badge("m_cluster", (140, 130, 40, 255), lambda d: [circle(d, x, y, 15, (40, 40, 45, 255), OUTL, 3) for x, y in ((48, 52), (80, 52), (48, 82), (80, 82))])
badge("m_paladin", (190, 150, 50, 255), lambda d: [poly(d, [(64, 28), (96, 38), (92, 74), (64, 102), (36, 74), (32, 38)], (240, 240, 250, 255), OUTL, 4), d.line([P(64, 40), P(64, 90)], fill=(200, 150, 40, 255), width=7 * S), d.line([P(46, 56), P(82, 56)], fill=(200, 150, 40, 255), width=7 * S)])
badge("m_lancer", (50, 100, 190, 255), lambda d: [d.line([P(34, 100), P(92, 30)], fill=(150, 100, 60, 255), width=7 * S), poly(d, [(92, 22), (104, 18), (98, 38), (86, 34)], W, OUTL, 2), poly(d, [(86, 34), (98, 38), (80, 56)], W)])

# app icon
img = Image.new("RGBA", (N * S, N * S), (20, 24, 44, 255)); d = ImageDraw.Draw(img)
d.rounded_rectangle([P(4, 4), P(124, 124)], radius=24 * S, fill=(26, 32, 60, 255), outline=(250, 200, 80, 255), width=5 * S)
poly(d, [(40, 104), (40, 50), (48, 44), (56, 50), (56, 58), (72, 58), (72, 50), (80, 44), (88, 50), (88, 104)], (200, 190, 170, 255), OUTL, 4)
poly(d, [(36, 50), (48, 24), (60, 50)], (200, 50, 40, 255), OUTL, 3)
poly(d, [(68, 50), (80, 24), (92, 50)], (200, 50, 40, 255), OUTL, 3)
d.rounded_rectangle([P(56, 76), P(72, 104)], radius=8 * S, fill=(50, 30, 20, 255))
poly(d, star_pts(64, 92 - 30, 8, 3), (255, 210, 60, 255))
img.resize((N, N), Image.LANCZOS).save(os.path.join(OUT, "icon.png"))
img.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, "icon_512.png"))
print("icons done")
