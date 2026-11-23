"""Procedural VFX textures: flipbooks (fire, smoke, explosion), glow, spark, star, rings, rune circle, slash, crack, leaf, snow."""
import numpy as np, os, sys, math
from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(3)


def vnoise(n, scale, seed):
    r = np.random.default_rng(seed)
    g = r.random((scale + 1, scale + 1))
    g[-1, :] = g[0, :]; g[:, -1] = g[:, 0]
    x = np.linspace(0, scale, n, endpoint=False)
    xi = x.astype(int); xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    a = g[np.ix_(xi, xi)]; b = g[np.ix_(xi, xi + 1)]; c = g[np.ix_(xi + 1, xi)]; d = g[np.ix_(xi + 1, xi + 1)]
    fx = xf[None, :]; fy = xf[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(n, seed, octs=5, base=4):
    s = np.zeros((n, n)); amp = 1.0; tot = 0
    for o in range(octs):
        s += vnoise(n, base * 2 ** o, seed + o * 17) * amp
        tot += amp; amp *= 0.5
    return s / tot


def radial(n):
    y, x = np.mgrid[0:n, 0:n] + 0.5
    return np.sqrt((x - n / 2) ** 2 + (y - n / 2) ** 2) / (n / 2)


def save_rgba(arr, name):
    a = np.clip(arr, 0, 1)
    Image.fromarray((a * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


def ramp(v, stops):
    """map 0..1 to color via list of (t, (r,g,b))"""
    out = np.zeros(v.shape + (3,))
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]; t1, c1 = stops[i + 1]
        m = (v >= t0) & (v <= t1)
        k = ((v - t0) / max(t1 - t0, 1e-6))[m][:, None]
        out[m] = np.array(c0) * (1 - k) + np.array(c1) * k
    out[v > stops[-1][0]] = stops[-1][1]
    return out


N = 128
R = radial(N)

# --- glow (soft core + halo), white
g = np.exp(-(R ** 2) * 5.0) * 0.85 + np.exp(-(R ** 2) * 28.0) * 0.6
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(g, 0, 1) * (R < 1)
save_rgba(img, "fx_glow")

# --- spark streak (horizontal elongated), white
y, x = np.mgrid[0:N, 0:N] + 0.5
sx = (x - N / 2) / (N / 2); sy = (y - N / 2) / (N / 2)
s = np.exp(-(sy ** 2) * 90) * np.clip(1 - np.abs(sx), 0, 1) ** 1.5
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(s * 1.4, 0, 1)
save_rgba(img, "fx_spark")

# --- 4 point star sparkle
st = np.exp(-np.abs(sx) * 26) * np.exp(-np.abs(sy) * 3) + np.exp(-np.abs(sy) * 26) * np.exp(-np.abs(sx) * 3)
st += np.exp(-(R ** 2) * 30) * 0.8
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(st, 0, 1)
save_rgba(img, "fx_star")

# --- soft ring (shockwave)
ring = np.exp(-((R - 0.82) ** 2) * 260) + np.exp(-((R - 0.78) ** 2) * 40) * 0.35
img = np.zeros((N, N, 4)); img[..., :3] = 1; img[..., 3] = np.clip(ring, 0, 1)
save_rgba(img, "fx_ring")

# --- rune magic circle (256)
M = 256
im = Image.new("L", (M * 2, M * 2), 0); d = ImageDraw.Draw(im)
c = M
for r, w in ((0.96, 10), (0.84, 5), (0.56, 6), (0.48, 3)):
    d.ellipse([c - r * c, c - r * c, c + r * c, c + r * c], outline=255, width=w)
for i in range(6):
    a = i * math.pi / 3
    pts = [(c + math.cos(a + k * 2 * math.pi / 3) * 0.84 * c, c + math.sin(a + k * 2 * math.pi / 3) * 0.84 * c) for k in range(3)]
    if i < 2:
        d.polygon(pts, outline=255, width=5)
for i in range(24):
    a = i * 2 * math.pi / 24
    rr = 0.9 * c
    x0, y0 = c + math.cos(a) * rr, c + math.sin(a) * rr
    t = i % 4
    if t == 0:
        d.line([x0 - 10, y0, x0 + 10, y0], fill=255, width=4); d.line([x0, y0 - 12, x0, y0 + 12], fill=255, width=4)
    elif t == 1:
        d.ellipse([x0 - 8, y0 - 8, x0 + 8, y0 + 8], outline=255, width=4)
    elif t == 2:
        d.polygon([(x0, y0 - 12), (x0 + 9, y0 + 8), (x0 - 9, y0 + 8)], outline=255, width=3)
    else:
        d.line([x0 - 9, y0 - 9, x0 + 9, y0 + 9], fill=255, width=4)
im = im.resize((M, M), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.6))
glow = im.filter(ImageFilter.GaussianBlur(6))
a = np.maximum(np.asarray(im) / 255.0, np.asarray(glow) / 255.0 * 0.8)
img = np.zeros((M, M, 4)); img[..., :3] = 1; img[..., 3] = a
save_rgba(img, "fx_rune")

# --- slash arc (crescent) white
y2, x2 = np.mgrid[0:M, 0:M] + 0.5
rr = np.sqrt((x2 - M / 2) ** 2 + (y2 - M / 2) ** 2) / (M / 2)
ang = np.arctan2(y2 - M / 2, x2 - M / 2)
band = np.exp(-((rr - 0.78) ** 2) * 160)
tail = np.clip((ang + math.pi) / (2 * math.pi), 0, 1) ** 2.2
img = np.zeros((M, M, 4)); img[..., :3] = 1; img[..., 3] = np.clip(band * tail * 1.4, 0, 1)
save_rgba(img, "fx_slash")

# --- ground crack decal (dark)
im = Image.new("L", (M, M), 0); d = ImageDraw.Draw(im)
r2 = np.random.default_rng(9)
for k in range(9):
    a = k * 2 * math.pi / 9 + r2.uniform(-0.2, 0.2)
    px, py = M / 2, M / 2
    w = 9
    for s_ in range(7):
        a += r2.uniform(-0.45, 0.45)
        L = r2.uniform(10, 22)
        nx, ny = px + math.cos(a) * L, py + math.sin(a) * L
        d.line([px, py, nx, ny], fill=255, width=max(int(w), 1))
        px, py = nx, ny; w *= 0.78
d.ellipse([M / 2 - 22, M / 2 - 22, M / 2 + 22, M / 2 + 22], fill=200)
im = im.filter(ImageFilter.GaussianBlur(1.2))
a = np.asarray(im) / 255.0
soft = np.exp(-(radial(M) ** 2) * 3.0) * 0.45
img = np.zeros((M, M, 4)); img[..., :3] = 0.06; img[..., 3] = np.clip(np.maximum(a, soft), 0, 1)
save_rgba(img, "fx_crack")

# --- flipbooks 4x4 (fire, smoke, explosion) at 96px per frame
F = 96
RF = radial(F)


def flip(name, kind):
    sheet = np.zeros((F * 4, F * 4, 4))
    for i in range(16):
        t = i / 15.0
        n1 = fbm(F, 100 + i * 3, 5, 3)
        n2 = fbm(F, 300 + i * 5, 4, 5)
        yy = (np.mgrid[0:F, 0:F][0] + 0.5) / F
        if kind == "fire":
            rad = 0.8 + 0.18 * t
            shape = np.clip(1 - RF / rad, 0, 1) ** 0.6
            shape *= (0.35 + 1.1 * n1) * (1.0 - 0.35 * yy * t)
            v = np.clip((shape - t * 0.45) * 2.6, 0, 1)
            col = ramp(np.clip(v * (1.15 - 0.6 * t), 0, 1), [(0, (0.35, 0.05, 0.0)), (0.35, (0.95, 0.3, 0.02)), (0.7, (1.0, 0.72, 0.2)), (1.0, (1.0, 0.97, 0.75))])
            a = np.clip(v * 1.6, 0, 1) * (1 - t ** 3)
        elif kind == "smoke":
            rad = 0.7 + 0.28 * t
            shape = np.clip(1 - RF / rad, 0, 1) ** 0.55
            v = np.clip(shape * (0.35 + 1.1 * n1) * 1.3 - t * 0.3, 0, 1)
            shade = 0.55 + 0.45 * (1 - yy) * n2
            col = np.stack([shade * 0.92, shade * 0.9, shade * 0.88], -1)
            a = np.clip(v * 1.5, 0, 1) * (1 - t ** 2) * 0.9
        else:  # explosion: fire core turning to smoke
            rad = 0.55 + 0.43 * t ** 0.5
            shape = np.clip(1 - RF / rad, 0, 1) ** 0.55
            v = np.clip(shape * (0.4 + 1.1 * n1) * 1.8 - t * 0.4, 0, 1)
            heat = np.clip(v * (1.25 - 1.15 * t), 0, 1)
            fire = ramp(heat, [(0, (0.12, 0.08, 0.07)), (0.3, (0.6, 0.15, 0.02)), (0.6, (1.0, 0.55, 0.1)), (1.0, (1.0, 0.95, 0.7))])
            smoke = np.stack([0.25 + 0.2 * n2] * 3, -1)
            mix = np.clip(t * 1.4 - 0.2, 0, 1)
            col = fire * (1 - mix) + smoke * mix * (1 - heat[..., None]) + fire * mix * heat[..., None]
            a = np.clip(v * 2.0, 0, 1) * (1 - t ** 2.5)
        fr = np.zeros((F, F, 4)); fr[..., :3] = col; fr[..., 3] = a
        r_, c_ = divmod(i, 4)
        sheet[r_ * F:(r_ + 1) * F, c_ * F:(c_ + 1) * F] = fr
    save_rgba(sheet, name)


flip("fx_fire_flip", "fire")
flip("fx_smoke_flip", "smoke")
flip("fx_explosion_flip", "explosion")

# --- leaf & snowflake
im = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
d.ellipse([12, 22, 52, 42], fill=(255, 255, 255, 255)); d.line([10, 32, 54, 32], fill=(200, 200, 200, 255), width=2)
im.save(os.path.join(OUT, "fx_leaf.png"))
im = Image.new("RGBA", (64, 64), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
for k in range(3):
    a = k * math.pi / 3
    d.line([32 - math.cos(a) * 26, 32 - math.sin(a) * 26, 32 + math.cos(a) * 26, 32 + math.sin(a) * 26], fill=(255, 255, 255, 255), width=4)
d.ellipse([26, 26, 38, 38], fill=(255, 255, 255, 255))
im.filter(ImageFilter.GaussianBlur(0.8)).save(os.path.join(OUT, "fx_snow.png"))
# --- beam (horizontal soft line for lightning / lasers)
y3 = (np.mgrid[0:32, 0:128][0] + 0.5) / 32 * 2 - 1
b = np.exp(-(y3 ** 2) * 18) + np.exp(-(y3 ** 2) * 200) * 0.8
img = np.zeros((32, 128, 4)); img[..., :3] = 1; img[..., 3] = np.clip(b, 0, 1)
save_rgba(img, "fx_beam")
print("vfx textures done")
