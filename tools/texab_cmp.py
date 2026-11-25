#!/usr/bin/env python3
"""Compare the texture-size A/B shots of test_runner.tscn -- texab=<spec> (see _texab there):
X_a2.png / X_a3.png (frozen frames: reference and what still moves), X_b1.png, X_b2.png ...
(textures reduced, stage by stage).  usage: texab_cmp.py X.png [Y.png ...]
Prints masked PSNR, the 99.9th percentile and the share of pixels whose luminance moved more
than 4 and 8 levels (cumulative and for each stage alone), and writes a side-by-side crop
(A | B | diff x8) around the largest change: X_bN_cmp.png."""
import sys, glob, os
import numpy as np
from PIL import Image


def lum(a):
    return a[..., 0] * 0.2126 + a[..., 1] * 0.7152 + a[..., 2] * 0.0722


def main():
    for a_path in sys.argv[1:]:
        a3 = a_path.replace(".png", "_a3.png")
        if os.path.exists(a3):
            # frozen run: reference = first frozen frame, motion = what changes between frozen frames
            A = np.asarray(Image.open(a_path.replace(".png", "_a2.png")).convert("RGB")).astype(np.float32)
            A2 = np.asarray(Image.open(a3).convert("RGB")).astype(np.float32)
        else:
            A = np.asarray(Image.open(a_path).convert("RGB")).astype(np.float32)
            A2 = np.asarray(Image.open(a_path.replace(".png", "_a2.png")).convert("RGB")).astype(np.float32)
        moving = np.abs(lum(A) - lum(A2)) > 2.0
        # grow the moving mask a little (animated shader edges)
        m = moving.copy()
        for dy in (-2, -1, 1, 2):
            m |= np.roll(moving, dy, 0)
        for dx in (-2, -1, 1, 2):
            m |= np.roll(moving, dx, 1)
        keep = ~m
        base = os.path.basename(a_path)[:-4]
        print(f"{base}: moving {m.mean()*100:.1f}% of pixels masked")
        prev = A
        for b_path in sorted(glob.glob(a_path.replace(".png", "_b[0-9].png"))):
            if "_cmp" in b_path:
                continue
            B = np.asarray(Image.open(b_path).convert("RGB")).astype(np.float32)
            # this stage alone (against the previous stage)
            ds = np.abs(lum(prev) - lum(B))[keep]
            mse_s = (((prev - B) ** 2).mean(axis=2))[keep].mean()
            stage_only = f"   [stage alone: PSNR {10*np.log10(255**2/max(mse_s,1e-9)):5.1f} dB  >8: {(ds>8).mean()*100:5.2f}%]"
            prev = B
            d = np.abs(lum(A) - lum(B))
            dk = d[keep]
            mse = (((A - B) ** 2).mean(axis=2))[keep].mean()
            psnr = 10 * np.log10(255 ** 2 / max(mse, 1e-9))
            p999 = np.percentile(dk, 99.9)
            f4 = (dk > 4).mean() * 100
            f8 = (dk > 8).mean() * 100
            tag = b_path[len(a_path) - 4:-4]
            print(f"   {tag}: PSNR {psnr:5.1f} dB  p99.9 {p999:5.1f}  >4: {f4:5.2f}%  >8: {f8:5.2f}%  max {dk.max():.0f}" + stage_only)
            # crop around the densest change (box blur of the diff)
            dd = np.where(keep, d, 0)
            H, W = dd.shape
            cs = min(320, H // 3)
            k = np.cumsum(np.cumsum(dd, 0), 1)
            best, by, bx = -1, 0, 0
            for y in range(0, H - cs, cs // 4):
                for x in range(0, W - cs, cs // 4):
                    s = k[y + cs - 1, x + cs - 1] - (k[y - 1, x + cs - 1] if y else 0) - (k[y + cs - 1, x - 1] if x else 0) + (k[y - 1, x - 1] if x and y else 0)
                    if s > best:
                        best, by, bx = s, y, x
            ca = A[by:by + cs, bx:bx + cs]
            cb = B[by:by + cs, bx:bx + cs]
            cd = np.clip(np.abs(ca - cb) * 8, 0, 255)
            out = np.concatenate([ca, cb, cd], axis=1).astype(np.uint8)
            Image.fromarray(out).resize((out.shape[1] * 2, out.shape[0] * 2), Image.NEAREST).save(
                b_path.replace(".png", "_cmp.png"))


main()
