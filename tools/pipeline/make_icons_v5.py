"""Content-v5 icons: Lia's Arrow Rain skill badge (same badge style as the other hero skills).
usage: python3 make_icons_v5.py assets/ui"""
import math
import os
import sys

src = open(os.path.join(os.path.dirname(__file__), "make_icons.py")).read()
exec(src.split("# coin")[0])
from PIL import ImageDraw  # noqa: E402


def skill_arrows():
    img = canvas(); d = ImageDraw.Draw(img)
    circle(d, 64, 64, 54, (40, 110, 55, 255), OUTL, 5)
    circle(d, 64, 64, 44, (70, 150, 80, 255))
    # three arrows raining down at a slant, a little impact burst under the middle one
    for off, top in ((-22, 22), (0, 14), (22, 24)):
        x0, y0 = 50 + off, top
        x1, y1 = 40 + off, top + 62
        d.line([P(x0, y0), P(x1, y1)], fill=(120, 80, 45, 255), width=5 * S)
        # head
        poly(d, [(x1 - 8, y1 - 6), (x1 + 6, y1 - 3), (x1 - 3, y1 + 10)], (235, 235, 240, 255), OUTL, 2)
        # fletching
        poly(d, [(x0 - 7, y0 - 2), (x0 + 1, y0 + 2), (x0 - 3, y0 + 12)], (240, 210, 90, 255), OUTL, 2)
        poly(d, [(x0 + 7, y0 + 1), (x0 + 1, y0 + 2), (x0 + 2, y0 + 13)], (240, 210, 90, 255), OUTL, 2)
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6)
        d.line([P(40 + math.cos(a) * 10, 98 - math.sin(a) * 4), P(40 + math.cos(a) * 20, 98 - math.sin(a) * 10)],
               fill=(255, 235, 150, 255), width=3 * S)
    save(img, "skill_arrows")


skill_arrows()
