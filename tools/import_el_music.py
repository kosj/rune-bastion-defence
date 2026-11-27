#!/usr/bin/env python3
"""Turn ElevenLabs music renders into seamless game loops.

Usage: import_el_music.py <src_dir> [names...]

<src_dir> holds <name>.mp3 (battle, battle_river, boss, final, menu ...). Each render is
  - trimmed of the silence and the quiet tail a render may end on (a fade-out would dip the loop),
  - made into a loop: the last LOOP_XF seconds are cross-faded into the first ones with
    equal-power curves, so the end runs into the start without a click or a gap,
  - loudness-matched (RMS) across the set so switching region or entering the last wave
    does not jump in level,
  - written as stereo Ogg Vorbis to assets/audio/music/<name>.ogg.
"""
import os, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets/audio/music")
SR = 44100
LOOP_XF = 2.5      # seconds of cross-fade at the loop point
TARGET_DB = -17.0  # RMS of every loop (the old composed tracks sat around here)
QUALITY = 3        # Vorbis q3: ~110 kbps stereo, music under battle effects


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def env_db(x, win=0.25):
    n = int(win * SR)
    m = x.mean(axis=1)
    k = len(m) // n
    e = np.sqrt((m[: k * n].reshape(k, n) ** 2).mean(axis=1) + 1e-12)
    return 20 * np.log10(e), n


def trim(x):
    db, n = env_db(x)
    body = np.median(db)
    loud = np.where(db > body - 12.0)[0]
    a, b = loud[0] * n, (loud[-1] + 1) * n
    return x[a:b]


def make_loop(x):
    f = int(LOOP_XF * SR)
    head, tail = x[:f], x[-f:]
    t = np.linspace(0.0, 1.0, f, dtype=np.float32)[:, None]
    fade_in, fade_out = np.sin(t * np.pi / 2), np.cos(t * np.pi / 2)
    y = x[: len(x) - f].copy()
    y[:f] = head * fade_in + tail * fade_out
    return y


def level(y):
    rms = np.sqrt((y ** 2).mean() + 1e-12)
    g = 10 ** (TARGET_DB / 20) / rms
    y = y * g
    peak = np.abs(y).max()
    if peak > 0.98:
        y *= 0.98 / peak
    return y


def save(y, path):
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "2", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(QUALITY), path], input=y.astype(np.float32).tobytes(), check=True)


def main():
    src = sys.argv[1]
    names = sys.argv[2:] or [f[:-4] for f in sorted(os.listdir(src)) if f.endswith(".mp3")]
    for nm in names:
        x = load(os.path.join(src, nm + ".mp3"))
        y = level(make_loop(trim(x)))
        out = os.path.join(OUT, nm + ".ogg")
        save(y, out)
        print("%-14s %5.1fs -> %5.1fs loop, %4d KB" % (nm, len(x) / SR, len(y) / SR, os.path.getsize(out) // 1024))


if __name__ == "__main__":
    main()
