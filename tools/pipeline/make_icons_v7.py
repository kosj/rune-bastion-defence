"""Daily challenge menu glyph (calendar page with a gold star), in the make_icons_ui2.py style.
usage: python3 make_icons_v7.py assets/ui"""
import os
import sys

src = open(os.path.join(os.path.dirname(__file__), "make_icons_ui2.py")).read()
exec(src.split("poly(d, [(18, 26)")[0].split("\nimg = canvas()")[0])
from PIL import ImageDraw  # noqa: E402

GOLD = (246, 190, 60, 255)
GOLD_HI = (255, 230, 140, 255)

img = canvas(); d = ImageDraw.Draw(img)
# page
d.rounded_rectangle([P(16, 24), P(112, 114)], radius=12 * S, fill=(246, 234, 206, 255), outline=OUTL, width=5 * S)
# red header band
d.rounded_rectangle([P(16, 24), P(112, 50)], radius=12 * S, fill=(190, 56, 44, 255), outline=OUTL, width=5 * S)
d.rectangle([P(19, 40), P(109, 50)], fill=(190, 56, 44, 255))
line(d, [(16, 50), (112, 50)], OUTL, 5)
# rings
for x in (40, 88):
    line(d, [(x, 14), (x, 32)], OUTL, 11)
    line(d, [(x, 15), (x, 31)], (200, 200, 210, 255), 5)
# a star for today
import math
pts = []
for i in range(10):
    r = 26 if i % 2 == 0 else 11
    a = math.radians(-90 + i * 36)
    pts.append((64 + math.cos(a) * r, 82 + math.sin(a) * r))
poly(d, pts, GOLD)
line(d, [(58, 70), (62, 66)], GOLD_HI, 4)
save(img, "ic_daily")
