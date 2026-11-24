"""Content-v4 icons: tower abilities (one per mastery) and the hero talent tree.
Same badge style as the mastery icons (make_icons.py), but abilities wear a cyan rune gem
instead of the gold star so the two kinds of upgrade read differently in the radial menu.
usage: python3 make_icons_v4.py assets/ui"""
import math
import os
import sys

src = open(os.path.join(os.path.dirname(__file__), "make_icons.py")).read()
exec(src.split("# coin")[0])
from PIL import ImageDraw  # noqa: E402

W = (255, 255, 255, 255)


def flame(d, cx, cy, s, c1, c2):
    pts = []
    for i in range(60):
        t = i / 60 * 2 * math.pi
        x = math.sin(t) * (0.55 + 0.25 * math.cos(t))
        y = -math.cos(t) * 1.0
        if y < 0:
            x *= (1 + y) ** 1.4 + 0.05
        pts.append((cx + x * 40 * s, cy + y * 48 * s))
    poly(d, pts, c1, OUTL, 4)
    poly(d, [(cx + (px - cx) * 0.55, cy + 14 * s + (py - cy) * 0.55) for px, py in pts], c2)


def gem(d, cx, cy, r):
    poly(d, [(cx, cy - r), (cx + r * 0.8, cy), (cx, cy + r), (cx - r * 0.8, cy)], (90, 230, 255, 255), OUTL, 3)
    poly(d, [(cx, cy - r * 0.6), (cx + r * 0.4, cy), (cx, cy + r * 0.1), (cx - r * 0.4, cy)], (220, 250, 255, 255))


def ability(name, col, glyph):
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 64, 64, 54, col, OUTL, 5)
    circle(d, 64, 64, 44, tuple(min(255, int(c * 1.25)) for c in col[:3]) + (255,))
    glyph(d)
    gem(d, 101, 27, 17)
    save(img, name)


def drop(d, cx, cy, s, fill):
    pts = []
    for i in range(48):
        t = i / 48 * 2 * math.pi
        x = math.sin(t) * 0.62
        y = -math.cos(t)
        if y < 0:
            x *= (1 + y) ** 1.2
        pts.append((cx + x * 34 * s, cy + y * 40 * s))
    poly(d, pts, fill, OUTL, 4)


def skull_small(d, cx, cy, s):
    circle(d, cx, cy - 4 * s, 22 * s, (240, 232, 214, 255), OUTL, 3)
    d.rounded_rectangle([P(cx - 13 * s, cy + 10 * s), P(cx + 13 * s, cy + 24 * s)], radius=4 * S, fill=(240, 232, 214, 255), outline=OUTL, width=3 * S)
    circle(d, cx - 8 * s, cy - 2 * s, 6 * s, (40, 20, 20, 255))
    circle(d, cx + 8 * s, cy - 2 * s, 6 * s, (40, 20, 20, 255))


# ranger -> poison arrows: a green venom drop with an arrow through it
def g_poison(d):
    d.line([P(30, 98), P(96, 32)], fill=(120, 80, 40, 255), width=6 * S)
    poly(d, [(96, 32), (100, 20), (108, 28)], W, OUTL, 2)
    drop(d, 58, 70, 0.78, (120, 240, 70, 255))
    circle(d, 52, 64, 6, (220, 255, 200, 255))


# marksman -> execute: skull in the cross-hairs
def g_execute(d):
    skull_small(d, 64, 62, 1.15)
    d.ellipse([P(24, 24), P(104, 104)], outline=(255, 70, 50, 255), width=5 * S)
    for x0, y0, x1, y1 in ((64, 14, 64, 32), (64, 96, 64, 114), (14, 64, 32, 64), (96, 64, 114, 64)):
        d.line([P(x0, y0), P(x1, y1)], fill=(255, 70, 50, 255), width=5 * S)


# paladin -> holy strike: radiant sword
def g_holy(d):
    for i in range(12):
        a = math.radians(i * 30)
        d.line([P(64 + math.cos(a) * 22, 64 + math.sin(a) * 22), P(64 + math.cos(a) * 42, 64 + math.sin(a) * 42)], fill=(255, 245, 170, 255), width=4 * S)
    poly(d, [(64, 22), (72, 34), (72, 82), (56, 82), (56, 34)], (240, 245, 255, 255), OUTL, 3)
    d.line([P(46, 82), P(82, 82)], fill=(210, 160, 50, 255), width=8 * S)
    d.line([P(64, 84), P(64, 104)], fill=(120, 80, 40, 255), width=7 * S)


# lancer -> javelin volley: three thrown spears
def g_javelin(d):
    for k, off in enumerate((-18, 0, 18)):
        x0, y0, x1, y1 = 30 + off, 100, 88 + off, 30
        d.line([P(x0, y0), P(x1, y1)], fill=(150, 100, 60, 255), width=5 * S)
        poly(d, [(x1 - 4, y1 + 8), (x1 + 8, y1 - 8), (x1 + 6, y1 + 6)], W, OUTL, 2)


# arcane -> teleport: violet portal swirl with a back-arrow
def g_teleport(d):
    for k in range(3):
        r = 36 - k * 10
        d.arc([P(64 - r, 64 - r), P(64 + r, 64 + r)], 30 + k * 60, 300 + k * 60, fill=(240, 210, 255, 255), width=(6 - k) * S)
    poly(d, [(26, 70), (40, 56), (40, 84)], (255, 240, 120, 255), OUTL, 2)


# frost -> absolute zero: an ice block with a snowflake
def g_freeze(d):
    d.rounded_rectangle([P(32, 32), P(96, 96)], radius=10 * S, fill=(200, 240, 255, 255), outline=OUTL, width=4 * S)
    for i in range(3):
        a = math.radians(i * 60)
        d.line([P(64 - math.cos(a) * 24, 64 - math.sin(a) * 24), P(64 + math.cos(a) * 24, 64 + math.sin(a) * 24)], fill=(40, 120, 200, 255), width=5 * S)
    poly(d, [(36, 36), (60, 36), (36, 54)], (255, 255, 255, 200))


# bombard -> shock shells: bomb with an electric burst
def g_shock(d):
    for i in range(8):
        a = math.radians(i * 45 + 22)
        poly(d, [(64 + math.cos(a - 0.18) * 30, 64 + math.sin(a - 0.18) * 30), (64 + math.cos(a) * 50, 64 + math.sin(a) * 50), (64 + math.cos(a + 0.18) * 30, 64 + math.sin(a + 0.18) * 30)], (255, 230, 90, 255))
    circle(d, 64, 66, 24, (40, 40, 45, 255), OUTL, 3)
    poly(d, [(68, 46), (56, 66), (66, 66), (60, 84), (74, 60), (64, 60), (70, 46)], (255, 240, 120, 255))


# cluster -> napalm: small bombs over a flame
def g_napalm(d):
    flame(d, 64, 72, 0.72, (240, 90, 30, 255), (255, 210, 90, 255))
    for x, y in ((40, 40), (88, 40)):
        circle(d, x, y, 11, (40, 40, 45, 255), OUTL, 3)


ability("a_poison", (40, 120, 50, 255), g_poison)
ability("a_execute", (150, 110, 25, 255), g_execute)
ability("a_holy", (180, 140, 40, 255), g_holy)
ability("a_javelin", (45, 90, 175, 255), g_javelin)
ability("a_teleport", (100, 45, 160, 255), g_teleport)
ability("a_freeze", (35, 110, 180, 255), g_freeze)
ability("a_shock", (160, 65, 28, 255), g_shock)
ability("a_napalm", (150, 60, 30, 255), g_napalm)


# hero talents: round medallions
def talent(name, col, glyph):
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 64, 64, 54, (60, 40, 20, 255), OUTL, 5)
    circle(d, 64, 64, 46, col)
    glyph(d)
    save(img, name)


def g_hp(d):
    poly(d, [(64, 98), (30, 62), (30, 44), (42, 32), (56, 32), (64, 42), (72, 32), (86, 32), (98, 44), (98, 62)], (235, 60, 70, 255), OUTL, 4)
    d.line([P(64, 50), P(64, 78)], fill=W, width=7 * S)
    d.line([P(50, 64), P(78, 64)], fill=W, width=7 * S)


def g_dmg(d):
    for a in (-1, 1):
        d.line([P(64 - a * 34, 28), P(64 + a * 30, 98)], fill=(225, 230, 240, 255), width=9 * S)
        d.line([P(64 - a * 34, 28), P(64 + a * 30, 98)], fill=W, width=3 * S)
        d.line([P(64 + a * 16, 80), P(64 + a * 40, 70)], fill=(200, 150, 50, 255), width=7 * S)


def g_skill(d):
    flame(d, 64, 70, 0.8, (240, 90, 30, 255), (255, 210, 90, 255))
    poly(d, star_pts(64, 70, 12, 5), (255, 250, 220, 255))


def g_cd(d):
    poly(d, [(40, 30), (88, 30), (66, 64), (88, 98), (40, 98), (62, 64)], (240, 225, 190, 255), OUTL, 4)
    poly(d, [(48, 92), (80, 92), (64, 72)], (240, 190, 70, 255))
    poly(d, [(50, 36), (78, 36), (64, 54)], (240, 190, 70, 255))


talent("ht_hp", (150, 40, 50, 255), g_hp)
talent("ht_dmg", (70, 80, 110, 255), g_dmg)
talent("ht_skill", (150, 70, 30, 255), g_skill)
talent("ht_cd", (60, 110, 120, 255), g_cd)
print("v4 icons done")
