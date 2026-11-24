#!/usr/bin/env python3
"""Emission masks for props whose painted parts glow (lava cracks, magic crystals).

Writes <name>_emit.png next to <name>_albedo.png: the albedo kept only where the colour is
saturated, bright and inside the given hue band, black elsewhere. Assets.instance_glow uses it as
the emission map. usage: make_emit.py MODEL_DIR
"""
import sys
import numpy as np
from PIL import Image

BANDS = {  # name: (hue ranges in degrees, min saturation, min value)
    "meteor": ([(0, 45), (340, 360)], 0.45, 0.5),
    "shaman_crystal": ([(165, 215)], 0.35, 0.45),
    "mage_crystal": ([(255, 330)], 0.35, 0.35),
}


def main(d):
    for name, (bands, smin, vmin) in BANDS.items():
        a = np.asarray(Image.open(f"{d}/{name}_albedo.png").convert("RGB")).astype(np.float32) / 255
        mx, mn = a.max(2), a.min(2)
        s, v = (mx - mn) / (mx + 1e-6), mx
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        dd = mx - mn + 1e-6
        h = np.where(mx == r, ((g - b) / dd) % 6, np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) * 60
        hue = np.zeros_like(h)
        for lo, hi in bands:
            hue = np.maximum(hue, ((h >= lo) & (h < hi)).astype(np.float32))
        m = np.clip((s - smin) / 0.2, 0, 1) * np.clip((v - vmin) / 0.25, 0, 1) * hue
        Image.fromarray((a * m[..., None] * 255).astype(np.uint8)).save(f"{d}/{name}_emit.png")
        print(name, "glowing share %.3f" % (m > 0.5).mean())


if __name__ == "__main__":
    main(sys.argv[1])
