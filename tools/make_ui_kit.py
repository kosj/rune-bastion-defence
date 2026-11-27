"""Procedural UI kit: framed panels, parchment, gem buttons, round slots, ribbons, bars and map flags.

Everything is rendered from signed distance fields at 2x the canvas size (textures are drawn by
StyleBoxHD at half their pixel size, so they stay crisp on 1.5-2x phone/desktop scaling).
Look: gold-trimmed navy enamel + warm parchment, in the spirit of Kingdom Rush style fantasy UI.

python3 tools/make_ui_kit.py  ->  assets/ui/kit/*.png
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "kit")
os.makedirs(OUT, exist_ok=True)
S = 2  # texture pixels per canvas unit
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ primitives
def grid(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x + 0.5, y + 0.5


def sd_rrect(w, h, cx, cy, hw, hh, r):
    x, y = grid(w, h)
    qx = np.abs(x - cx) - (hw - r)
    qy = np.abs(y - cy) - (hh - r)
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2)
    return out + np.minimum(np.maximum(qx, qy), 0) - r


def sd_circle(w, h, cx, cy, rad):
    x, y = grid(w, h)
    return np.sqrt((x - cx) ** 2 + (y - cy) ** 2) - rad


def sd_polygon(w, h, pts, ss=4):
    """signed distance (px) to a polygon given in pixel coords (negative inside), via EDT"""
    from PIL import ImageDraw
    from scipy.ndimage import distance_transform_edt
    big = Image.new("L", (w * ss, h * ss), 0)
    ImageDraw.Draw(big).polygon([(x * ss, y * ss) for x, y in pts], fill=255)
    m = np.asarray(big, np.float32) / 255.0 > 0.5
    din = distance_transform_edt(m)
    dout = distance_transform_edt(~m)
    d = (dout - din) / ss
    # downsample by averaging (keeps sub-pixel accuracy)
    return d.reshape(h, ss, w, ss).mean(axis=(1, 3)).astype(np.float32)


def cov(d):
    """coverage of the inside (d<0) with 1px anti-aliasing"""
    return np.clip(0.5 - d, 0.0, 1.0)


def grad_dir(d):
    gy, gx = np.gradient(d)
    n = np.sqrt(gx * gx + gy * gy) + 1e-6
    return gx / n, gy / n


def noise(w, h, octaves=5, base=4, seed=0):
    r = np.random.default_rng(seed)
    acc = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        n = base * (2 ** o)
        g = r.random((n + 1, n + 1)).astype(np.float32)
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
        acc += np.asarray(img, np.float32) / 255.0 * amp
        tot += amp
        amp *= 0.55
    return acc / tot


def lerp(a, b, t):
    t = np.asarray(t)[..., None] if np.ndim(t) else t
    return np.asarray(a, np.float32) * (1 - t) + np.asarray(b, np.float32) * t


def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def over(dst, src_rgb, src_a):
    """alpha-composite src over dst (premultiplied-free RGBA float arrays)"""
    a = src_a[..., None]
    out_a = a + dst[..., 3:4] * (1 - a)
    out_rgb = (src_rgb * a + dst[..., :3] * dst[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-6)
    return np.concatenate([out_rgb, out_a], -1)


def blur_alpha(a, rad):
    img = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    return np.asarray(img.filter(ImageFilter.GaussianBlur(rad)), np.float32) / 255.0


def shift(a, dx, dy):
    return np.roll(np.roll(a, int(dy), 0), int(dx), 1)


def save(arr, name):
    a = np.clip(arr, 0, 1)
    Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


GOLD_HI, GOLD, GOLD_LO, GOLD_DEEP = hexc("fff1b8"), hexc("f0bd4f"), hexc("a8701f"), hexc("5b3a10")
LIGHT = np.array([-0.55, -0.83])  # light from the upper left


def metal_band(d, inner, outer, hi=GOLD_HI, mid=GOLD, lo=GOLD_LO):
    """rounded (pillow) bevel band between distance `outer` (<0 side) and `inner` (more negative)"""
    gx, gy = grad_dir(d)
    t = np.clip((outer - d) / (outer - inner), 0, 1)  # 0 at outer edge -> 1 at inner edge
    slope = np.cos(t * np.pi)  # + on outer half, - on inner half
    lit = (gx * LIGHT[0] + gy * LIGHT[1]) * slope  # outward normal facing light on outer half
    lit = np.clip(lit, -1, 1)
    col = np.where((lit > 0)[..., None], lerp(mid, hi, lit), lerp(mid, lo, -lit))
    # thin dark separating lines at both edges
    edge = np.exp(-((d - outer) ** 2) / 0.9) + np.exp(-((d - inner) ** 2) / 0.9)
    col = lerp(col, GOLD_DEEP, np.clip(edge * 0.8, 0, 1))
    band = np.clip(np.minimum(cov(d - outer), 1 - cov(d - inner)), 0, 1)
    return col, band


# ------------------------------------------------------------------ framed panels
def framed_panel(name, size, margin, frame_w, radius, fill_fn, frame=True, rivets=True, shadow=True):
    W = H = size * S
    m = 7 * S if shadow else 2 * S  # room for the drop shadow
    hw, hh = W / 2 - m, H / 2 - m
    d = sd_rrect(W, H, W / 2, H / 2, hw, hh, radius * S)
    img = np.zeros((H, W, 4), np.float32)
    if shadow:
        sh = blur_alpha(cov(shift(d, 0, 2.5 * S)), 4 * S) * 0.6
        img = over(img, np.zeros((H, W, 3), np.float32), sh)
    # body fill
    inside = cov(d + frame_w * S)
    body = fill_fn(W, H, d + frame_w * S)
    img = over(img, body, inside if frame else cov(d))
    # inner shadow under the frame
    ish = np.clip(1.0 - (-(d + frame_w * S)) / (9 * S), 0, 1) ** 2 * inside * 0.55
    img = over(img, np.zeros((H, W, 3), np.float32), ish)
    if frame:
        col, band = metal_band(d, -frame_w * S, 0)
        img = over(img, col, band)
        # outer dark rim
        rim = np.clip(cov(d) - cov(d + 1.2 * S), 0, 1)
        img = over(img, GOLD_DEEP * 0.6, rim * 0.9)
    if rivets:
        off = m + frame_w * S * 0.5 + radius * S * 0.3
        for cx, cy in ((off, off), (W - off, off), (off, H - off), (W - off, H - off)):
            dr = sd_circle(W, H, cx, cy, 4.2 * S)
            c, b = metal_band(dr, -4.2 * S, 0, hi=hexc("fffbe6"), mid=hexc("f6d06a"), lo=hexc("8d5a14"))
            img = over(img, c, b)
            # tiny gem centre
            dg = sd_circle(W, H, cx, cy, 1.8 * S)
            img = over(img, np.broadcast_to(hexc("c43b2c"), (H, W, 3)), cov(dg))
    save(img, name)
    print(name, W, H, "margin", margin)


def enamel(W, H, d):
    n = noise(W, H, 5, 3, seed=11)
    fine = noise(W, H, 3, 32, seed=12)
    x, y = grid(W, H)
    v = 1.0 - 0.55 * (((x - W / 2) / W) ** 2 + ((y - H * 0.42) / H) ** 2)
    top, bot = hexc("223057"), hexc("0f1630")
    col = lerp(bot, top, np.clip(v, 0, 1))
    col = col * (0.92 + 0.12 * n[..., None]) * (0.97 + 0.05 * fine[..., None])
    return col


def parchment(W, H, d):
    n = noise(W, H, 6, 3, seed=21)
    fib = noise(W, H, 2, 64, seed=22)
    base = lerp(hexc("e9d3a2"), hexc("f8ecc9"), n)
    base = base * (0.96 + 0.06 * fib[..., None])
    edge = np.clip(1.0 + d / (14 * S), 0, 1)  # darker toward the frame
    burn = lerp(base, hexc("b98d52"), edge ** 2.2 * 0.85)
    return burn


def leather(W, H, d):
    n = noise(W, H, 5, 4, seed=31)
    col = lerp(hexc("2a1a12"), hexc("4a2e1d"), n)
    return col


# ------------------------------------------------------------------ gem buttons
def gem_button(name, top, bot, state="normal", w=96, h=52, radius=16):
    W, H = w * S, h * S
    lift = 0 if state == "pressed" else 3 * S
    m = 4 * S
    cy = H / 2 - lift / 2 + (S if state == "pressed" else 0)
    hw, hh = W / 2 - m, H / 2 - m - lift / 2
    d = sd_rrect(W, H, W / 2, cy, hw, hh, radius * S)
    img = np.zeros((H, W, 4), np.float32)
    if state != "pressed":
        # solid "base" under the button (3D thickness) + soft shadow
        db = sd_rrect(W, H, W / 2, cy + lift, hw, hh, radius * S)
        img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(db), 2.5 * S) * 0.55)
        img = over(img, lerp(bot, np.zeros(3), 0.55)[None, None, :] * np.ones((H, W, 1)), cov(db))
    x, y = grid(W, H)
    t = np.clip((y - (cy - hh)) / (2 * hh), 0, 1)
    k = {"normal": 1.0, "hover": 1.14, "pressed": 0.82, "disabled": 1.0}[state]
    fill = lerp(top * k, bot * k, t)
    img = over(img, np.clip(fill, 0, 1), cov(d + 3 * S))
    # gloss on the upper half
    dg = sd_rrect(W, H, W / 2, cy - hh * 0.42, hw - 6 * S, hh * 0.42, radius * S * 0.7)
    gl = cov(dg) * (1 - t) ** 1.5 * (0.34 if state != "pressed" else 0.14)
    img = over(img, np.ones((H, W, 3), np.float32), gl)
    # inner bottom shade
    ib = np.clip((t - 0.62) / 0.38, 0, 1) ** 2 * cov(d + 3 * S) * 0.28
    img = over(img, np.zeros((H, W, 3), np.float32), ib)
    col, band = metal_band(d, -3.2 * S, 0)
    if state == "disabled":
        col = lerp(col, np.full(3, 0.55), 0.75)
    img = over(img, col, band)
    rim = np.clip(cov(d) - cov(d + 1.0 * S), 0, 1)
    img = over(img, GOLD_DEEP * 0.5, rim)
    save(img, name)


# ------------------------------------------------------------------ round slots
def round_slot(name, inner_hi, inner_lo, state="normal", size=96):
    W = H = size * S
    R = W / 2 - 4 * S
    off = S if state == "pressed" else 0
    d = sd_circle(W, H, W / 2, H / 2 + off, R)
    img = np.zeros((H, W, 4), np.float32)
    if state != "pressed":
        img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, 2 * S)), 2.5 * S) * 0.6)
    x, y = grid(W, H)
    rr = np.sqrt((x - W * 0.42) ** 2 + (y - H * 0.36) ** 2) / R
    k = {"normal": 1.0, "hover": 1.18, "pressed": 0.8, "disabled": 0.6}[state]
    fill = lerp(inner_hi * k, inner_lo * k, np.clip(rr, 0, 1))
    if state == "disabled":
        fill = lerp(fill, np.full(3, 0.22), 0.6)
    img = over(img, np.clip(fill, 0, 1), cov(d + 6 * S))
    # top gloss crescent
    dg = sd_circle(W, H, W / 2, H / 2 - R * 0.36 + off, R * 0.62)
    img = over(img, np.ones((H, W, 3), np.float32), cov(np.maximum(dg, d + 9 * S)) * 0.16)
    col, band = metal_band(d, -6.5 * S, 0)
    if state == "disabled":
        col = lerp(col, np.full(3, 0.5), 0.7)
    elif state == "hover":
        col = np.clip(col * 1.12, 0, 1)
    img = over(img, col, band)
    save(img, name)


# ------------------------------------------------------------------ ribbon
def ribbon(name, w=300, h=64, col_hi=hexc("d8493a"), col_lo=hexc("8e1f17")):
    W, H = w * S, h * S
    img = np.zeros((H, W, 4), np.float32)
    x, y = grid(W, H)
    tail = 44 * S
    b0, b1 = H * 0.08, H * 0.70            # main band top/bottom
    t0, t1 = H * 0.30, H * 0.94            # tails sit lower
    notch = 13 * S
    for side in (0, 1):
        def X(v):
            return v if side == 0 else W - v
        pts = [(X(2 * S), t0), (X(tail + 12 * S), t0), (X(tail + 12 * S), t1), (X(2 * S), t1), (X(2 * S + notch), (t0 + t1) / 2)]
        d = sd_polygon(W, H, pts)
        tt = np.clip((y - t0) / (t1 - t0), 0, 1)
        img = over(img, lerp(col_lo * 0.95, col_lo * 0.62, tt), cov(d))
        # gold edge on the tail
        img = over(img, GOLD * 0.8, np.clip(cov(d) - cov(d + 1.6 * S), 0, 1) * 0.8)
        # fold: dark triangle joining band and tail
        fp = [(X(tail), b1), (X(tail + 12 * S), b1), (X(tail + 12 * S), t1)] if side == 0 else \
             [(X(tail), b1), (X(tail + 12 * S), b1), (X(tail + 12 * S), t1)]
        img = over(img, col_lo * 0.32, cov(sd_polygon(W, H, fp)))
    d = sd_rrect(W, H, W / 2, (b0 + b1) / 2, W / 2 - tail, (b1 - b0) / 2, 3 * S)
    t = np.clip((y - b0) / (b1 - b0), 0, 1)
    band = lerp(col_hi, col_lo, t) * (0.95 + 0.08 * noise(W, H, 3, 8, seed=41)[..., None])
    img = over(img, band, cov(d))
    for yy in (b0 + 4.5 * S, b1 - 4.5 * S):
        sm = ((x >= tail + 3 * S) & (x <= W - tail - 3 * S) & (np.abs(y - yy) < 1.1 * S)).astype(np.float32)
        img = over(img, GOLD, blur_alpha(sm, 0.5) * 0.95)
    img = over(img, np.ones((H, W, 3), np.float32), cov(d) * np.clip(1 - t * 3.2, 0, 1) * 0.28)
    img = over(img, np.zeros((H, W, 3), np.float32), cov(d) * np.clip((t - 0.7) / 0.3, 0, 1) * 0.25)
    save(img, name)


# ------------------------------------------------------------------ bars
def bar_frame(name, w=64, h=18):
    W, H = w * S, h * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - S, H / 2 - S, H / 2 - S)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, hexc("120b08"), cov(d + 2.5 * S) * 0.92)
    col, band = metal_band(d, -2.5 * S, 0, hi=hexc("ffe7a0"), mid=hexc("c9932f"), lo=hexc("6b4512"))
    img = over(img, col, band)
    save(img, name)


def bar_fill(name, hi, lo, w=64, h=18):
    W, H = w * S, h * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - 3 * S, H / 2 - 3 * S, H / 2 - 3 * S)
    x, y = grid(W, H)
    t = np.clip((y - 3 * S) / (H - 6 * S), 0, 1)
    col = lerp(hi, lo, t)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, col, cov(d))
    img = over(img, np.ones((H, W, 3), np.float32), cov(d) * np.clip(1 - t * 2.6, 0, 1) * 0.45)
    save(img, name)


# ------------------------------------------------------------------ misc sprites
def badge(name, size=48, hi=hexc("ffe9a8"), lo=hexc("b67a1f")):
    W = H = size * S
    d = sd_circle(W, H, W / 2, H / 2, W / 2 - 2 * S)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, S)), 2 * S) * 0.6)
    x, y = grid(W, H)
    rr = np.sqrt((x - W * 0.4) ** 2 + (y - H * 0.35) ** 2) / (W / 2)
    img = over(img, lerp(hexc("3a2410"), hexc("1d1208"), np.clip(rr, 0, 1)), cov(d + 4 * S))
    col, band = metal_band(d, -4.5 * S, 0, hi=hexc("fff6d0"), mid=hi * 0.5 + lo * 0.5, lo=lo)
    img = over(img, col, band)
    save(img, name)


def glow(name, size=128, color=(1.0, 0.92, 0.6)):
    W = H = size * S
    x, y = grid(W, H)
    r = np.sqrt((x - W / 2) ** 2 + (y - H / 2) ** 2) / (W / 2)
    a = np.clip(1 - r, 0, 1) ** 2.2
    img = np.zeros((H, W, 4), np.float32)
    img[..., :3] = color
    img[..., 3] = a
    save(img, name)


def rays(name, size=256, n=16):
    W = H = size * S
    x, y = grid(W, H)
    ang = np.arctan2(y - H / 2, x - W / 2)
    r = np.sqrt((x - W / 2) ** 2 + (y - H / 2) ** 2) / (W / 2)
    s = (np.cos(ang * n) * 0.5 + 0.5) ** 6
    a = s * np.clip(1 - r, 0, 1) ** 1.3 * np.clip(r * 4, 0, 1)
    img = np.zeros((H, W, 4), np.float32)
    img[..., :3] = (1.0, 0.9, 0.55)
    img[..., 3] = a * 0.9
    save(img, name)


def divider(name, w=320, h=24):
    W, H = w * S, h * S
    x, y = grid(W, H)
    img = np.zeros((H, W, 4), np.float32)
    fade = np.clip(1 - np.abs(x - W / 2) / (W / 2), 0, 1) ** 0.6
    line = (np.abs(y - H / 2) < 1.1 * S).astype(np.float32) * fade
    img = over(img, GOLD, blur_alpha(line, 0.5))
    dd = np.abs(x - W / 2) + np.abs(y - H / 2) - 8 * S  # diamond
    c, b = metal_band(dd, -8 * S, 0)
    img = over(img, c, b)
    save(img, name)


def shield_flag(name, body_hi, body_lo, size=(84, 96)):
    W, H = size[0] * S, size[1] * S
    x, y = grid(W, H)
    m = 6 * S
    top, mid, bot = m, H * 0.58, H - m
    L, R = m, W - m
    pts = [(L + 10 * S, top), (R - 10 * S, top), (R, top + 10 * S), (R, mid)]
    # curved lower edges to the point
    for i in range(1, 17):
        k = i / 16.0
        pts.append((R + (W / 2 - R) * k, mid + (bot - mid) * (k ** 1.6)))
    for i in range(15, 0, -1):
        k = i / 16.0
        pts.append((L + (W / 2 - L) * k, mid + (bot - mid) * (k ** 1.6)))
    pts += [(L, mid), (L, top + 10 * S)]
    d = sd_polygon(W, H, pts)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, 3 * S)), 3 * S) * 0.6)
    t = np.clip((y - top) / (bot - top), 0, 1)
    img = over(img, lerp(body_hi, body_lo, t), cov(d + 5 * S))
    img = over(img, np.ones((H, W, 3), np.float32), cov(d + 5 * S) * np.clip(1 - t * 2.4, 0, 1) * 0.22)
    col, band = metal_band(d, -5 * S, 0)
    img = over(img, col, band)
    save(img, name)


def pill(name, w=64, h=30):
    W, H = w * S, h * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - 2 * S, H / 2 - 2 * S, H / 2 - 2 * S)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, S)), 1.5 * S) * 0.6)
    img = over(img, lerp(hexc("1d2440"), hexc("0b0f1f"), np.clip(grid(W, H)[1] / H, 0, 1)), cov(d + 2 * S))
    col, band = metal_band(d, -2.2 * S, 0)
    img = over(img, col, band)
    save(img, name)


def to_1x(name):
    """downscale a 2x kit texture to 1x for theme icons (Godot draws icons at texel size)"""
    pth = os.path.join(OUT, name + ".png")
    im = Image.open(pth)
    im.resize((im.width // 2, im.height // 2), Image.LANCZOS).save(pth)


def knob(name, size=30):
    W = H = size * S
    d = sd_circle(W, H, W / 2, H / 2, W / 2 - 3 * S)
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, S)), 1.5 * S) * 0.6)
    x, y = grid(W, H)
    rr = np.sqrt((x - W * 0.4) ** 2 + (y - H * 0.35) ** 2) / (W / 2)
    img = over(img, lerp(hexc("fff3c4"), hexc("c98a24"), np.clip(rr, 0, 1)), cov(d))
    col, band = metal_band(d, -2.5 * S, 0)
    img = over(img, col, band)
    save(img, name)


def toggle(name, on, w=60, h=32):
    W, H = w * S, h * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - 2 * S, H / 2 - 2 * S, H / 2 - 2 * S)
    img = np.zeros((H, W, 4), np.float32)
    fill = lerp(hexc("6fd35a"), hexc("2e8a2a"), np.clip(grid(W, H)[1] / H, 0, 1)) if on else \
        lerp(hexc("3a3f52"), hexc("1a1d28"), np.clip(grid(W, H)[1] / H, 0, 1))
    img = over(img, fill, cov(d + 2.5 * S))
    col, band = metal_band(d, -2.5 * S, 0)
    img = over(img, col, band)
    kx = W - H / 2 if on else H / 2
    dk = sd_circle(W, H, kx, H / 2, H / 2 - 5 * S)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(dk, 0, S)), S) * 0.5)
    x, y = grid(W, H)
    rr = np.sqrt((x - kx + 3 * S) ** 2 + (y - H * 0.38) ** 2) / (H / 2)
    img = over(img, lerp(hexc("ffffff"), hexc("c9cdd8"), np.clip(rr, 0, 1)), cov(dk))
    save(img, name)


if __name__ == "__main__":
    # panels, rectangular buttons, the divider and pills moved to the forged set (make_ui_forge.py)
    for nm, a, b in (("navy", "34477e", "10172f"), ("red", "c8402e", "5a120c"), ("purple", "7650c2", "261247"),
                     ("brown", "8a4a2a", "2e150a"), ("green", "46a24a", "123a14"), ("teal", "2f8f99", "0b2e36")):
        for st in ("normal", "hover", "pressed", "disabled"):
            round_slot("slot_%s_%s" % (nm, st), hexc(a), hexc(b), st)
    ribbon("ribbon_red")
    ribbon("ribbon_blue", col_hi=hexc("4b6fc4"), col_lo=hexc("1e2d66"))
    ribbon("ribbon_dark", col_hi=hexc("51443a"), col_lo=hexc("231a14"))
    bar_frame("bar_frame")
    bar_fill("bar_green", hexc("8ef06a"), hexc("2e9a2a"))
    bar_fill("bar_gold", hexc("ffe27a"), hexc("c88a1c"))
    bar_fill("bar_red", hexc("ff7a5a"), hexc("b0201a"))
    bar_fill("bar_blue", hexc("8fc4ff"), hexc("2a5ec0"))
    badge("badge")
    glow("glow")
    rays("rays")
    shield_flag("flag_locked", hexc("6f7380"), hexc("3a3d46"))
    shield_flag("flag_open", hexc("4f74c8"), hexc("1f2d68"))
    shield_flag("flag_done", hexc("d84a38"), hexc("7d1a12"))
    shield_flag("flag_heroic", hexc("f0c24f"), hexc("9a6312"))
    shield_flag("flag_endless", hexc("8f5fd8"), hexc("3a1f78"))
    knob("knob")
    toggle("toggle_on", True)
    toggle("toggle_off", False)
    for n in ("knob", "toggle_on", "toggle_off"):
        to_1x(n)
    pill("scroll_grab", 48, 16)
    sg = os.path.join(OUT, "scroll_grab.png")
    Image.open(sg).rotate(90, expand=True).save(sg)
    print("kit ->", os.path.abspath(OUT))
