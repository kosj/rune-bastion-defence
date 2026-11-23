"""Extra SFX for phase 2 (fuse, warcry, priority tick). Reuses the helpers in make_audio.py."""
import os, re
src = open(os.path.join(os.path.dirname(__file__), "make_audio.py")).read()
exec(src.split("# ----------------------------------------------------------------- SFX")[0])
d = 0.8
fz = hp_fast(noise(d), 3500) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 23 * t_(d)))) * env(int(SR * d), 0.02, 0.7, 0, 0.05)
write_wav("fuse", fz + sweep(500, 1600, d, "sine") * 0.15 * env(int(SR * d), 0.05, 0.7), 0.45)
d = 1.0
growl = lp_fast(sweep(150, 95, d, "saw") + sweep(152, 97, d, "saw") + sweep(76, 50, d, "square") * 0.6, 700)
growl *= (0.7 + 0.3 * np.sin(2 * np.pi * 9 * t_(d))) * env(int(SR * d), 0.06, 0.85, 0, 0.1)
write_wav("warcry", reverb(growl + lp_fast(noise(d), 900) * 0.3 * env(int(SR * d), 0.05, 0.8), 0.9, 0.3), 0.85)
write_wav("tick", sweep(1400, 1900, 0.06, "tri") * env(int(SR * 0.06), 0.003, 0.05), 0.4)
print("extra sfx done")
