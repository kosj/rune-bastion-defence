"""Second hero skill badges (same badge style as the first skills): Kael's flame charge, Sera's
star ward, Ren's piercing arrow.
usage: python3 make_icons_v6.py assets/ui"""
import math
import os
import sys

src = open(os.path.join(os.path.dirname(__file__), "make_icons.py")).read()
exec(src.split("# coin")[0])
from PIL import ImageDraw  # noqa: E402


def badge_bg(d, ring, inner):
    circle(d, 64, 64, 54, ring, OUTL, 5)
    circle(d, 64, 64, 44, inner)


def skill_charge():
    img = canvas(); d = ImageDraw.Draw(img)
    badge_bg(d, (150, 40, 28, 255), (196, 72, 36, 255))
    # speed streaks behind
    for y, x0, x1 in ((44, 18, 46), (64, 12, 40), (84, 18, 46)):
        d.line([P(x0, y), P(x1, y)], fill=OUTL, width=9 * S)
        d.line([P(x0, y), P(x1, y)], fill=(255, 214, 120, 255), width=5 * S)
    # double chevron, the front one brighter
    for off, col in ((0, (255, 150, 50, 255)), (24, (255, 226, 110, 255))):
        x = 44 + off
        poly(d, [(x, 30), (x + 22, 30), (x + 48, 64), (x + 22, 98), (x, 98), (x + 26, 64)], col, OUTL, 5)
    save(img, "skill_charge")


def skill_ward():
    img = canvas(); d = ImageDraw.Draw(img)
    badge_bg(d, (78, 44, 140, 255), (118, 78, 190, 255))
    lav = (226, 208, 255, 255)
    circle(d, 64, 64, 36, None, OUTL, 9)
    circle(d, 64, 64, 36, None, lav, 5)
    # rune ticks around the ring
    for k in range(12):
        a = k * math.tau / 12
        x0, y0 = 64 + math.cos(a) * 30, 64 + math.sin(a) * 30
        x1, y1 = 64 + math.cos(a) * 26, 64 + math.sin(a) * 26
        d.line([P(x0, y0), P(x1, y1)], fill=lav, width=3 * S)
    # star of two triangles
    for rot in (-90, 90):
        pts = [(64 + math.cos(math.radians(rot + i * 120)) * 24, 64 + math.sin(math.radians(rot + i * 120)) * 24) for i in range(3)]
        d.line([P(*p) for p in pts + [pts[0]]], fill=OUTL, width=7 * S, joint="curve")
        d.line([P(*p) for p in pts + [pts[0]]], fill=(250, 236, 255, 255), width=3 * S, joint="curve")
    circle(d, 64, 64, 8, (255, 255, 255, 255), OUTL, 3)
    save(img, "skill_ward")


def skill_pierce():
    img = canvas(); d = ImageDraw.Draw(img)
    badge_bg(d, (24, 92, 100, 255), (44, 134, 140, 255))
    # rings the arrow has gone through
    for cx, cy, r in ((44, 84, 13), (66, 62, 13)):
        d.ellipse([P(cx - r, cy - r * 0.55), P(cx + r, cy + r * 0.55)], outline=OUTL, width=7 * S)
        d.ellipse([P(cx - r, cy - r * 0.55), P(cx + r, cy + r * 0.55)], outline=(255, 226, 140, 255), width=3 * S)
    # one long arrow, bottom-left to top-right
    x0, y0, x1, y1 = 20, 108, 98, 30
    d.line([P(x0, y0), P(x1, y1)], fill=OUTL, width=10 * S)
    d.line([P(x0, y0), P(x1, y1)], fill=(150, 96, 52, 255), width=5 * S)
    poly(d, [(x1 + 12, y1 - 12), (x1 - 14, y1 - 4), (x1 + 4, y1 + 14)], (238, 240, 246, 255), OUTL, 3)
    poly(d, [(x0 + 2, y0 - 2), (x0 - 10, y0 - 4), (x0 + 6, y0 - 18), (x0 + 12, y0 - 12)], (255, 214, 90, 255), OUTL, 3)
    poly(d, [(x0 + 2, y0 - 2), (x0 + 4, y0 + 10), (x0 + 18, y0 - 6), (x0 + 12, y0 - 12)], (255, 214, 90, 255), OUTL, 3)
    save(img, "skill_pierce")


skill_charge()
skill_ward()
skill_pierce()
