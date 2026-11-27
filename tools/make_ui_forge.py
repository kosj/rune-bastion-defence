"""Forged UI materials: the surfaces every screen is built from (tools/make_ui_kit.py draws the
older pieces: map flags, bars, badges, ribbons, medallion slots).

One material language, "rune-forged": dark slate stone held in a thin bronze-gold trim, and
buttons that are enamel plates on a solid base (a lit face, a bevelled rim, a darker lip below,
a contact shadow), so a button reads as something to press from across the room and every
surface separates from the busy 3D battlefield behind it. Lighting is matte, from the upper left;
no glassy highlight blobs. A faint grain keeps large fills from looking like flat vector shapes.

Drawn at 2x (StyleBoxHD draws them at half their pixel size). Shadows sit outside the control
rect: the style's `expand` puts them there, so layouts do not change.

python3 tools/make_ui_forge.py  ->  assets/ui/kit/f*.png
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from make_ui_kit import (S, blur_alpha, cov, grad_dir, grid, hexc, lerp, noise, over, save,  # noqa: E402
                         sd_circle, sd_rrect, shift)

DARK = hexc("07090d")
TRIM_HI, TRIM, TRIM_LO, TRIM_DEEP = hexc("ffe9ad"), hexc("cf9f45"), hexc("6e4815"), hexc("2a1906")
LIGHT = np.array([-0.45, -0.89])


def bevel(d, inner, outer, hi, mid, lo, edge_col=None):
    """A rounded bevel band between distances `outer` and `inner` (inner more negative), lit from
    the upper left: the outer half catches light where its normal faces it, the inner half the
    opposite. Returns (rgb, coverage)."""
    gx, gy = grad_dir(d)
    t = np.clip((outer - d) / (outer - inner), 0, 1)
    slope = np.cos(t * np.pi)
    lit = np.clip((gx * LIGHT[0] + gy * LIGHT[1]) * slope, -1, 1)
    col = np.where((lit > 0)[..., None], lerp(mid, hi, lit), lerp(mid, lo, -lit))
    if edge_col is not None:
        e = np.exp(-((d - inner) ** 2) / 0.8)
        col = lerp(col, edge_col, np.clip(e * 0.7, 0, 1))
    band = np.clip(np.minimum(cov(d - outer), 1 - cov(d - inner)), 0, 1)
    return col, band


def vgrad(H, W, top, bot, y0, y1):
    _, y = grid(W, H)
    t = np.clip((y - y0) / max(y1 - y0, 1), 0, 1)
    return lerp(top, bot, t)


def grain(W, H, seed, amount=0.05):
    n = noise(W, H, 4, 24, seed=seed)
    return (1.0 - amount / 2 + amount * n)[..., None]


# ------------------------------------------------------------------ buttons
BUTTONS = {
    #             face top   face bottom  lip        rim light
    "primary": ("ffd76a", "e99f2a", "8c5410", "fff0b8"),
    "secondary": ("4b6688", "2d4260", "17233a", "9fb8d8"),
    "special": ("8466d0", "543a9a", "2a1a58", "c9b6ff"),
    "danger": ("e2624a", "b0301f", "5e140b", "ffb8a6"),
    "disabled": ("4a5260", "3a414c", "1f242c", "6f7887"),
}
BW, BH, BM, BR, LIP = 120, 72, 6, 14, 6  # canvas units: texture, shadow margin, radius, lip


def button(name, role, state):
    W, H = BW * S, BH * S
    top, bot, lip, rim = (hexc(c) for c in BUTTONS["disabled" if state == "disabled" else role])
    k = {"normal": 1.0, "hover": 1.09, "pressed": 0.9, "disabled": 1.0}[state]
    top, bot = np.clip(top * k, 0, 1), np.clip(bot * k, 0, 1)
    x0, y0, x1, y1 = BM * S, BM * S, W - BM * S, H - BM * S
    cx = W / 2
    hw = (x1 - x0) / 2
    # the whole plate (face + lip) and the face on top of it
    hh = (y1 - y0) / 2
    d_body = sd_rrect(W, H, cx, (y0 + y1) / 2, hw, hh, BR * S)
    sink = (LIP - 1) * S if state == "pressed" else 0
    fy0, fy1 = y0 + sink, y1 - LIP * S + sink
    d_face = sd_rrect(W, H, cx, (fy0 + fy1) / 2, hw, (fy1 - fy0) / 2, BR * S)
    img = np.zeros((H, W, 4), np.float32)
    # contact shadow (smaller when the plate is pressed down)
    sh_off, sh_blur, sh_a = (1.0, 1.5, 0.35) if state == "pressed" else (3.0, 3.5, 0.45)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d_body, 0, sh_off * S)), sh_blur * S) * sh_a)
    # dark outline, then the lip (the plate's side) inside it
    img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(d_body) * 0.92)
    img = over(img, vgrad(H, W, lip * 1.1, lip * 0.7, y0, y1), cov(d_body + 1.6 * S))
    # face: matte vertical gradient, a soft sheen on the upper part, grain
    fill = vgrad(H, W, top, bot, fy0, fy1)
    _, y = grid(W, H)
    up = np.clip(1 - (y - fy0) / max(fy1 - fy0, 1) / 0.5, 0, 1)
    fill = lerp(fill, np.ones(3), up ** 2 * (0.1 if state != "pressed" else 0.04))
    fill = fill * grain(W, H, 41, 0.04)
    inside = cov(d_face + 1.6 * S)
    img = over(img, np.clip(fill, 0, 1), inside)
    # bevelled rim of the face: light on the top-left, the face colour falling into shade below
    col, band = bevel(d_face + 1.6 * S, -2.6 * S, 0, rim, (top + bot) / 2, bot * 0.62)
    img = over(img, col, band * (0.85 if state != "disabled" else 0.5))
    save(img, name)


# ------------------------------------------------------------------ round medallions
ROUNDS = {
    #            centre     edge       rim hi     rim lo
    "secondary": ("41597a", "1b2639", "c7d3e4", "39465a"),
    "primary": ("ffd36a", "c47f19", "fff0b8", "7a4a0c"),
    "danger": ("d9533c", "7c1a10", "ffc2b4", "5a140b"),
    "disabled": ("3d4552", "232831", "7a8291", "2a3038"),
}
RS, RM = 96, 6


def medallion(name, role, state):
    W = H = RS * S
    centre, edge, rim_hi, rim_lo = (hexc(c) for c in ROUNDS["disabled" if state == "disabled" else role])
    k = {"normal": 1.0, "hover": 1.12, "pressed": 0.86, "disabled": 1.0}[state]
    centre, edge = np.clip(centre * k, 0, 1), np.clip(edge * k, 0, 1)
    R = RS / 2 * S - RM * S
    dy = 1.5 * S if state == "pressed" else 0
    d = sd_circle(W, H, W / 2, H / 2 + dy, R)
    img = np.zeros((H, W, 4), np.float32)
    sh_off, sh_blur, sh_a = (1.0, 1.5, 0.35) if state == "pressed" else (3.0, 3.5, 0.5)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, sh_off * S)), sh_blur * S) * sh_a)
    img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(d) * 0.92)
    x, y = grid(W, H)
    rr = np.sqrt((x - W * 0.44) ** 2 + (y - H * 0.36 - dy) ** 2) / R
    fill = lerp(centre, edge, np.clip(rr, 0, 1) ** 1.2) * grain(W, H, 51, 0.05)
    img = over(img, np.clip(fill, 0, 1), cov(d + 1.5 * S))
    # inner shadow under the rim, then the rim itself
    ish = np.clip(1.0 + (d + 4.5 * S) / (5 * S), 0, 1) ** 2 * cov(d + 1.5 * S) * 0.45
    img = over(img, np.zeros((H, W, 3), np.float32), ish)
    col, band = bevel(d + 1.5 * S, -3.6 * S, 0, rim_hi, (rim_hi + rim_lo) / 2, rim_lo, edge_col=DARK)
    img = over(img, col, band)
    save(img, name)


# ------------------------------------------------------------------ sheets, cards, wells
def slate(W, H, y0, y1, top="223146", bot="111924", seed=61):
    fill = vgrad(H, W, hexc(top), hexc(bot), y0, y1)
    mott = noise(W, H, 5, 3, seed=seed)
    return fill * (0.94 + 0.09 * mott[..., None]) * grain(W, H, seed + 1, 0.035)


def trimmed(name, size, margin, radius, trim, body_alpha=1.0, studs=True, flat_bottom=False,
            top="223146", bot="111924"):
    W = H = size * S
    m = margin * S
    ext = 40 * S if flat_bottom else 0  # an upright bottom sheet runs off the screen edge
    d = sd_rrect(W, H + 2 * ext, W / 2, (H + 2 * ext) / 2, W / 2 - m, (H + 2 * ext) / 2 - m, radius * S)[:H]
    img = np.zeros((H, W, 4), np.float32)
    sh = blur_alpha(cov(shift(d, 0, (2.5 if not flat_bottom else -2.5) * S)), (margin * 0.55) * S) * 0.62
    img = over(img, np.zeros((H, W, 3), np.float32), sh)
    img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(d) * 0.95)
    body = slate(W, H, m, H - m, top, bot)
    inside = cov(d + (trim + 1.2) * S)
    img = over(img, body, inside * body_alpha)
    # light catches the top inner edge, a soft shade under the trim all round
    ish = np.clip(1.0 + (d + (trim + 1.2) * S) / (7 * S), 0, 1) ** 2 * inside * 0.4
    img = over(img, np.zeros((H, W, 3), np.float32), ish)
    _, y = grid(W, H)
    hl = np.exp(-((d + (trim + 2.2) * S) ** 2) / (0.9 * S * S)) * np.clip(1 - (y - m) / (H * 0.5), 0, 1)
    img = over(img, np.ones((H, W, 3), np.float32), hl * 0.1)
    col, band = bevel(d + 1.2 * S, -trim * S, 0, TRIM_HI, TRIM, TRIM_LO, edge_col=TRIM_DEEP)
    img = over(img, col, band)
    if studs:
        # small rune studs where the trim turns the corners
        off = m + radius * S * 0.29 + 0.6 * S
        pts = ((off, off), (W - off, off)) if flat_bottom else ((off, off), (W - off, off), (off, H - off), (W - off, H - off))
        for cx, cy in pts:
            x, yy = grid(W, H)
            dd = (np.abs(x - cx) + np.abs(yy - cy)) / np.sqrt(2) - 3.2 * S  # a diamond
            c, b = bevel(dd, -3.2 * S, 0, hexc("fff6d6"), hexc("e8b85a"), hexc("7a4d12"), edge_col=TRIM_DEEP)
            img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(dd - 0.8 * S) * 0.8)
            img = over(img, c, b)
    save(img, name)


def well(name, size=80, radius=12, on=False):
    W = H = size * S
    m = 1 * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - m, H / 2 - m, radius * S)
    img = np.zeros((H, W, 4), np.float32)
    base = hexc("3a2a0c") if on else hexc("070d14")
    img = over(img, np.broadcast_to(base, (H, W, 3)), cov(d) * (0.62 if not on else 0.66))
    # carved in: shade along the top inner edge, a thin light lip along the bottom
    _, y = grid(W, H)
    top_sh = np.clip(1.0 + d / (5 * S), 0, 1) ** 2 * np.clip(1 - (y - m) / (H * 0.6), 0, 1) * cov(d)
    img = over(img, np.zeros((H, W, 3), np.float32), top_sh * 0.55)
    lip = np.exp(-((d + 0.6 * S) ** 2) / (0.5 * S * S)) * np.clip((y - H * 0.55) / (H * 0.45), 0, 1)
    img = over(img, np.ones((H, W, 3), np.float32), lip * 0.12)
    if on:
        col, band = bevel(d, -2.2 * S, 0, TRIM_HI, TRIM, TRIM_LO)
        img = over(img, col, band)
    save(img, name)


def capsule(name, w=96, h=56):
    """The HUD counter capsule: translucent smoked glass in a thin trim."""
    W, H = w * S, h * S
    m = 4 * S
    d = sd_rrect(W, H, W / 2, H / 2, W / 2 - m, H / 2 - m, (H / 2 - m))
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.zeros((H, W, 3), np.float32), blur_alpha(cov(shift(d, 0, 2 * S)), 2.5 * S) * 0.45)
    img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(d) * 0.9)
    body = vgrad(H, W, hexc("1c2838"), hexc("0b1119"), m, H - m)
    img = over(img, body, cov(d + 1.4 * S) * 0.88)
    col, band = bevel(d + 1.0 * S, -1.8 * S, 0, TRIM_HI, TRIM, TRIM_LO)
    img = over(img, col, band * 0.85)
    save(img, name)


def divider(name, w=320, h=16):
    """A trim line for under sheet titles: tapered gold with a rune diamond in the middle."""
    W, H = w * S, h * S
    x, y = grid(W, H)
    cx, cy = W / 2, H / 2
    taper = np.clip(1 - np.abs(x - cx) / (W / 2), 0, 1) ** 0.6
    d_line = np.abs(y - cy) - 0.9 * S * taper
    img = np.zeros((H, W, 4), np.float32)
    img = over(img, np.broadcast_to(TRIM, (H, W, 3)), cov(d_line) * taper)
    dd = (np.abs(x - cx) + np.abs(y - cy)) / np.sqrt(2) - 4.5 * S
    img = over(img, np.broadcast_to(DARK, (H, W, 3)), cov(dd - 0.9 * S) * 0.85)
    c, b = bevel(dd, -4.5 * S, 0, hexc("fff6d6"), hexc("e8b85a"), hexc("7a4d12"))
    img = over(img, c, b)
    save(img, name)


if __name__ == "__main__":
    for role in BUTTONS:
        if role == "disabled":
            continue
        for st in ("normal", "hover", "pressed", "disabled"):
            button("fb_%s_%s" % (role, st), role, st)
    for role in ROUNDS:
        if role == "disabled":
            continue
        for st in ("normal", "hover", "pressed", "disabled"):
            medallion("fr_%s_%s" % (role, st), role, st)
    trimmed("fs_sheet", 160, 16, 18, 4.2)
    trimmed("fs_sheet_up", 160, 16, 18, 4.2, flat_bottom=True)
    trimmed("fs_card", 112, 10, 14, 3.0, body_alpha=0.95, studs=False)
    trimmed("fs_bar", 112, 8, 22, 2.2, body_alpha=0.86, studs=False, top="1a2534", bot="0c121a")
    well("fs_well")
    well("fs_well_on", on=True)
    capsule("fs_capsule")
    divider("fs_divider")
    print("forge ->", os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "kit")))
