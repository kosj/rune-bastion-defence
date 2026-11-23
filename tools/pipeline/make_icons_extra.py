"""Phase-2 extra UI icons: targeting priorities, boss crown. Reuses helpers from make_icons.py."""
import os, sys
src = open(os.path.join(os.path.dirname(__file__), "make_icons.py")).read()
exec(src.split("# coin")[0])

def crosshair(d, col):
    circle(d, 64, 64, 46, None, OUTL, 14)
    circle(d, 64, 64, 46, None, col, 8)
    circle(d, 64, 64, 22, None, OUTL, 12)
    circle(d, 64, 64, 22, None, col, 6)
    for (x0, y0, x1, y1) in ((64, 6, 64, 34), (64, 94, 64, 122), (6, 64, 34, 64), (94, 64, 122, 64)):
        d.line([P(x0, y0), P(x1, y1)], fill=OUTL, width=14 * S)
        d.line([P(x0, y0), P(x1, y1)], fill=col, width=7 * S)
    circle(d, 64, 64, 7, (255, 240, 200, 255), OUTL, 3)

img = canvas(); d = ImageDraw.Draw(img); crosshair(d, (240, 90, 70, 255)); save(img, "target")
img = canvas(); d = ImageDraw.Draw(img); crosshair(d, (240, 90, 70, 255))
poly(d, [(66, 18), (110, 18), (110, 40), (66, 40)], (0, 0, 0, 0))
save(img, "target_first")
# strong: crosshair + fist/skull badge
img = canvas(); d = ImageDraw.Draw(img); crosshair(d, (250, 170, 50, 255)); save(img, "target_strong")
img = canvas(); d = ImageDraw.Draw(img); crosshair(d, (90, 190, 250, 255)); save(img, "target_close")
# crown (boss)
img = canvas(); d = ImageDraw.Draw(img)
poly(d, [(14, 96), (20, 36), (44, 66), (64, 24), (84, 66), (108, 36), (114, 96)], (250, 196, 60, 255), OUTL, 5)
d.rounded_rectangle([P(14, 92), P(114, 110)], radius=4 * S, fill=(214, 150, 40, 255), outline=OUTL, width=5 * S)
for cx in (40, 64, 88):
    circle(d, cx, 101, 5, (220, 50, 60, 255), OUTL, 2)
for cx, cy in ((20, 34), (64, 22), (108, 34)):
    circle(d, cx, cy, 7, (255, 240, 170, 255), OUTL, 3)
save(img, "crown")
print("extra icons done")
# Sera's skill: starfall burst
import math
img = canvas(); d = ImageDraw.Draw(img)
circle(d, 64, 64, 54, (40, 70, 150, 255), OUTL, 5)
pts = []
for k in range(10):
    a = -math.pi / 2 + k * math.pi / 5
    r = 40 if k % 2 == 0 else 17
    pts.append((64 + math.cos(a) * r, 64 + math.sin(a) * r))
poly(d, pts, (150, 225, 255, 255), OUTL, 5)
circle(d, 64, 64, 9, (255, 255, 255, 255), None, 0)
for (x, y, rr) in ((26, 28, 6), (100, 34, 5), (98, 96, 6), (30, 98, 4)):
    circle(d, x, y, rr, (200, 240, 255, 255), OUTL, 2)
save(img, "skill_star")
print("skill_star done")
