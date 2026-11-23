"""Procedural SFX + music synthesis (numpy). Writes WAV sfx and OGG music via ffmpeg."""
import numpy as np, os, sys, subprocess, wave

OUT = sys.argv[1]
SFX = os.path.join(OUT, "sfx"); MUS = os.path.join(OUT, "music")
os.makedirs(SFX, exist_ok=True); os.makedirs(MUS, exist_ok=True)
SR = 22050
rng = np.random.default_rng(7)


def t_(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.1, sus_t=0.0):
    a_n, d_n, s_n, r_n = int(a * SR), int(d * SR), max(int(sus_t * SR), 0), int(r * SR)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1)), np.linspace(1, s, max(d_n, 1)), np.full(s_n, s), np.linspace(s, 0, max(r_n, 1))])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def expdec(n, k):
    return np.exp(-np.arange(n) / SR * k)


def lp(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.zeros_like(x); acc = 0.0
    # vectorised one-pole via lfilter-like loop in chunks
    out = np.empty_like(x)
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        out[i] = acc
    return out


def lp_fast(x, cutoff):
    # FFT brickwall-ish smooth lowpass
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def hp_fast(x, cutoff):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (cutoff / np.maximum(f, 1)) ** 4)
    return np.fft.irfft(X, len(x))


def bp_fast(x, lo, hi):
    return hp_fast(lp_fast(x, hi), lo)


def noise(d):
    return rng.uniform(-1, 1, int(SR * d))


def sweep(f0, f1, d, wave="sine", curve=2.0):
    t = t_(d)
    k = (t / d) ** (1 / curve) if f1 < f0 else (t / d)
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    if wave == "sine":
        return np.sin(ph)
    if wave == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if wave == "square":
        return np.sign(np.sin(ph))
    if wave == "tri":
        return 2 * np.abs(2 * ((ph / (2 * np.pi)) % 1) - 1) - 1


def reverb(x, size=1.2, mix=0.25, damp=3000):
    n = int(SR * size)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.0 / size))
    ir = lp_fast(ir, damp)
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    L = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(ir, L), L)
    out = np.concatenate([x, np.zeros(n)]) * (1 - mix) + y * mix
    return out


def norm(x, peak=0.9):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade_tail(x, ms=8):
    n = int(SR * ms / 1000)
    x = x.copy()
    x[-n:] *= np.linspace(1, 0, n)
    x[:min(32, len(x))] *= np.linspace(0, 1, min(32, len(x)))
    return x


def write_wav(name, x, peak=0.85):
    x = fade_tail(norm(x, peak))
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(os.path.join(SFX, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())


def ks(freq, d, damp=0.996, bright=0.5):
    """Karplus-Strong pluck."""
    n = int(SR * d)
    p = max(int(SR / freq), 2)
    buf = rng.uniform(-1, 1, p)
    buf = lp_fast(np.tile(buf, 4), 2000 + bright * 6000)[:p]
    out = np.zeros(n)
    for i in range(n):
        v = buf[i % p]
        out[i] = v
        buf[i % p] = damp * 0.5 * (v + buf[(i + 1) % p])
    return out

# ----------------------------------------------------------------- SFX

write_wav("click", sweep(1800, 900, 0.05, "sine") * expdec(int(SR * 0.05), 60) + noise(0.05) * expdec(int(SR * 0.05), 200) * 0.3, 0.6)
for i in range(1, 4):
    n = noise(0.22)
    x = bp_fast(n, 2500 + i * 400, 9000) * expdec(len(n), 22)
    ring = sum(np.sin(2 * np.pi * f * t_(0.22)) for f in (1870 + i * 90, 2930 + i * 60, 4210)) * expdec(len(n), 14) * 0.25
    write_wav("clash_%d" % i, x + ring, 0.7)
    s = bp_fast(noise(0.16), 1500, 7000) * env(int(SR * 0.16), 0.03, 0.12, 0, 0.01)
    write_wav("sword_%d" % i, s + sweep(900 + i * 100, 400, 0.16, "sine") * expdec(int(SR * 0.16), 30) * 0.3, 0.6)
for i in range(1, 3):
    tw = sweep(220 + i * 30, 180, 0.25, "tri") * expdec(int(SR * 0.25), 25)
    wh = bp_fast(noise(0.25), 800, 5000) * env(int(SR * 0.25), 0.01, 0.2, 0, 0.04) * 0.6
    write_wav("bow_%d" % i, tw + wh, 0.6)
for i in range(1, 3):
    d = 1.1
    n = noise(d)
    low = sweep(90, 30, d, "sine", 3) * expdec(int(SR * d), 5)
    crack = lp_fast(n, 3000) * expdec(len(n), 9)
    rumble = lp_fast(n, 400) * expdec(len(n), 3)
    write_wav("boom_%d" % i, reverb(low * 1.2 + crack * 0.8 + rumble * 0.9, 0.8, 0.2), 0.95)
d = 0.5
write_wav("cannon", lp_fast(noise(d), 1800) * expdec(int(SR * d), 12) + sweep(120, 40, d, "sine") * expdec(int(SR * d), 10), 0.8)
mg = sum(np.sin(2 * np.pi * (f + 40 * np.sin(2 * np.pi * 6 * t_(0.45))) * t_(0.45)) for f in (660, 990, 1320)) * env(int(SR * 0.45), 0.02, 0.4, 0, 0.03)
write_wav("magic", reverb(mg + sweep(300, 1400, 0.45, "sine") * 0.4 * expdec(int(SR * 0.45), 6), 0.6, 0.3), 0.55)
zz = np.sign(np.sin(2 * np.pi * 60 * t_(0.4))) * bp_fast(noise(0.4), 1000, 8000) * expdec(int(SR * 0.4), 7)
write_wav("zap", reverb(zz + sweep(2000, 200, 0.4, "saw") * 0.3 * expdec(int(SR * 0.4), 8), 0.4, 0.2), 0.7)
fr = bp_fast(noise(0.7), 3000, 10000) * expdec(int(SR * 0.7), 6) + sum(np.sin(2 * np.pi * f * t_(0.7)) for f in (2093, 2637, 3136)) * expdec(int(SR * 0.7), 5) * 0.2
write_wav("frost", reverb(fr, 0.8, 0.35), 0.6)
sl = lp_fast(noise(1.2), 600) * expdec(int(SR * 1.2), 3.5) + sweep(70, 25, 1.2, "sine") * expdec(int(SR * 1.2), 3) * 1.5
write_wav("slam", sl, 0.95)
grunt = lp_fast(sweep(220, 120, 0.3, "saw"), 900) * env(int(SR * 0.3), 0.02, 0.28, 0, 0.02)
write_wav("die_small", grunt + lp_fast(noise(0.3), 1200) * expdec(int(SR * 0.3), 15) * 0.4, 0.6)
gb = lp_fast(sweep(130, 60, 0.6, "saw") + sweep(133, 62, 0.6, "saw"), 600) * env(int(SR * 0.6), 0.03, 0.55, 0, 0.03)
write_wav("die_big", gb + sweep(60, 30, 0.6) * expdec(int(SR * 0.6), 6), 0.8)
cn = sum(np.sin(2 * np.pi * f * t_(0.35)) * expdec(int(SR * 0.35), k) for f, k in ((2637, 10), (3520, 12), (5274, 16)))
cn[int(SR * 0.07):] += (sum(np.sin(2 * np.pi * f * t_(0.28)) * expdec(int(SR * 0.28), 12) for f in (3136, 4186)))[:len(cn) - int(SR * 0.07)]
write_wav("coin", cn, 0.5)
write_wav("hero_move", reverb(sum(np.sin(2 * np.pi * f * t_(0.25)) for f in (523, 784)) * env(int(SR * 0.25), 0.01, 0.2, 0, 0.04), 0.4, 0.2), 0.45)
write_wav("hero_select", reverb(np.concatenate([np.sin(2 * np.pi * 587 * t_(0.1)) * env(int(SR * 0.1), 0.005, 0.09), np.sin(2 * np.pi * 880 * t_(0.2)) * env(int(SR * 0.2), 0.005, 0.18)]), 0.5, 0.25), 0.45)
lv = np.concatenate([sum(np.sin(2 * np.pi * f * t_(0.12)) for f in (n, n * 2)) * env(int(SR * 0.12), 0.005, 0.1) for n in (523, 659, 784, 1047)])
write_wav("levelup", reverb(lv, 0.9, 0.35), 0.55)
wh = bp_fast(noise(0.8), 300, 3000) * np.sin(np.pi * t_(0.8) / 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * t_(0.8)))
write_wav("whirl", reverb(wh + lp_fast(noise(0.8), 500) * np.sin(np.pi * t_(0.8) / 0.8), 0.6, 0.2), 0.75)
hits = np.zeros(int(SR * 0.7))
for k, off in enumerate((0.0, 0.18, 0.36)):
    h = lp_fast(noise(0.12), 2500) * expdec(int(SR * 0.12), 40) + np.sin(2 * np.pi * 180 * t_(0.12)) * expdec(int(SR * 0.12), 30)
    i = int(off * SR); hits[i:i + len(h)] += h
write_wav("build", reverb(hits, 0.5, 0.2), 0.7)
up = np.concatenate([sum(np.sin(2 * np.pi * f * t_(0.16)) * (0.7 ** j) for j, f in enumerate((n, n * 2, n * 3))) * env(int(SR * 0.16), 0.005, 0.14) for n in (392, 523, 659, 784)])
write_wav("upgrade", reverb(up, 1.0, 0.3), 0.55)
write_wav("sell", reverb(np.concatenate([cn[: int(SR * 0.15)], cn]), 0.4, 0.2), 0.5)
write_wav("rally", reverb(sweep(400, 600, 0.2, "tri") * env(int(SR * 0.2), 0.01, 0.18), 0.4, 0.2), 0.45)
write_wav("error", sweep(220, 160, 0.18, "square") * env(int(SR * 0.18), 0.005, 0.17) * 0.5, 0.35)
ll = sweep(300, 120, 0.5, "saw") * env(int(SR * 0.5), 0.01, 0.48)
write_wav("life_lost", lp_fast(ll, 1500) + np.sin(2 * np.pi * 80 * t_(0.5)) * expdec(int(SR * 0.5), 6), 0.7)
mc = sweep(200, 1200, 0.6, "saw") * env(int(SR * 0.6), 0.05, 0.5, 0, 0.05) * 0.3 + bp_fast(noise(0.6), 500, 4000) * np.linspace(0, 1, int(SR * 0.6))
write_wav("meteor_cast", reverb(lp_fast(mc, 3000), 0.8, 0.3), 0.7)


def horn_note(f, d, vib=5.0):
    t = t_(d)
    ph = 2 * np.pi * np.cumsum(f * (1 + 0.006 * np.sin(2 * np.pi * vib * t))) / SR
    x = sum(np.sin(k * ph) * (1 / k) ** 1.2 for k in range(1, 9))
    return lp_fast(x, 1800) * env(len(t), 0.08, 0.1, 0.8, 0.25, d - 0.45)

hn = np.concatenate([horn_note(196, 0.45), horn_note(294, 0.9)])
write_wav("horn", reverb(hn + 0.5 * np.concatenate([horn_note(147, 0.45), horn_note(147, 0.9)]), 1.6, 0.35), 0.8)
rf = np.concatenate([horn_note(392, 0.25), horn_note(523, 0.5)])
write_wav("reinforce", reverb(rf + bp_fast(noise(len(rf) / SR), 200, 2000) * 0.15, 1.0, 0.3), 0.6)
br = lp_fast(sweep(110, 70, 1.6, "saw") + sweep(113, 72, 1.6, "saw") + noise(1.6) * 0.5, 700) * env(int(SR * 1.6), 0.15, 0.6, 0.6, 0.6, 0.3)
write_wav("boss_roar", reverb(br * (1 + 0.3 * np.sin(2 * np.pi * 18 * t_(1.6))), 1.2, 0.3), 0.95)


def chord_hit(notes, d):
    return sum(horn_note(f, d) for f in notes)

vic = np.concatenate([chord_hit((392, 494, 587), 0.22), chord_hit((392, 494, 587), 0.22), chord_hit((523, 659, 784), 1.4)])
write_wav("victory", reverb(vic, 1.8, 0.35), 0.8)
df = np.concatenate([horn_note(294, 0.5), horn_note(277, 0.5), horn_note(262, 0.5), horn_note(196, 1.4)])
write_wav("defeat", reverb(df, 1.8, 0.35), 0.75)
print("sfx done")

# ----------------------------------------------------------------- music

NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name, octave):
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octave + 1) - 69) / 12)


def pad(freqs, d):
    t = t_(d)
    x = np.zeros(len(t))
    for f in freqs:
        for det in (-0.004, 0.0, 0.005):
            ph = 2 * np.pi * f * (1 + det) * t
            x += (2 * ((ph / (2 * np.pi)) % 1) - 1) * 0.3
    x = lp_fast(x, 1400)
    return x * env(len(t), 0.4, 0.2, 0.85, 0.5, max(d - 1.1, 0))


def drum(kind, d=0.5):
    n = int(SR * d)
    if kind == "taiko":
        return (sweep(110, 45, d, "sine", 3) * expdec(n, 7) * 1.4 + lp_fast(noise(d), 900) * expdec(n, 25) * 0.6)
    if kind == "snare":
        return bp_fast(noise(d), 800, 6000) * expdec(n, 18) * 0.6 + np.sin(2 * np.pi * 190 * t_(d)) * expdec(n, 25) * 0.3
    if kind == "hat":
        return hp_fast(noise(d), 6000) * expdec(n, 60) * 0.25


def place(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[: j - i]


def battle():
    bpm = 116
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    mix_l = np.zeros(int(SR * L) + SR * 3)
    prog = [("D", ["D", "F", "A"]), ("A#", ["A#", "D", "F"]), ("F", ["F", "A", "C"]), ("C", ["C", "E", "G"])]
    for b in range(bars):
        root, ch = prog[(b // 2) % 4] if b < 8 else prog[[0, 1, 2, 3, 0, 1, 3, 3][b - 8]]
        t0 = b * 4 * beat
        if b % 2 == 0:
            place(mix_l, pad([hz(n, 3) for n in ch] + [hz(root, 2)], 8 * beat + 0.4) * 0.22, t0)
        # ostinato pluck 8ths
        arp = [hz(ch[0], 4), hz(ch[1], 4), hz(ch[2], 4), hz(ch[1], 4)]
        for k in range(8):
            place(mix_l, ks(arp[k % 4], beat * 0.9, 0.994, 0.4) * 0.16, t0 + k * beat / 2)
        # bass
        for k in (0, 2.5, 3):
            place(mix_l, lp_fast(sweep(hz(root, 2), hz(root, 2), beat * 0.9, "saw"), 500) * env(int(SR * beat * 0.9), 0.01, 0.3, 0.5, 0.1, beat * 0.4) * 0.35, t0 + k * beat)
        # drums
        for k, kind in ((0, "taiko"), (1.5, "taiko"), (2, "snare"), (3, "taiko"), (3.5, "taiko")):
            if b >= 2 or kind == "taiko":
                place(mix_l, drum(kind), t0 + k * beat)
        if b >= 4:
            for k in range(8):
                place(mix_l, drum("hat", 0.1), t0 + k * beat / 2)
    # heroic horn melody second half
    mel = [("D", 5, 2), ("F", 5, 1), ("A", 5, 1), ("A#", 5, 3), ("A", 5, 1), ("F", 5, 2), ("G", 5, 1), ("A", 5, 1), ("C", 6, 3), ("A#", 5, 1),
           ("A", 5, 2), ("G", 5, 1), ("F", 5, 1), ("E", 5, 2), ("C", 5, 2), ("D", 5, 6), ("D", 5, 2)]
    t = 8 * 4 * beat
    for n, o, d in mel:
        place(mix_l, horn_note(hz(n, o), d * beat * 0.95) * 0.22, t)
        place(mix_l, horn_note(hz(n, o - 1), d * beat * 0.95) * 0.12, t)
        t += d * beat
    y = reverb(mix_l, 1.6, 0.22)
    y = y[: int(SR * L)]
    # seamless loop: crossfade tail of reverb into start
    return norm(y, 0.85)


def menu():
    bpm = 76
    beat = 60 / bpm
    bars = 12
    L = bars * 4 * beat
    buf = np.zeros(int(SR * L) + SR * 3)
    prog = [("D", ["D", "F#", "A"]), ("B", ["B", "D", "F#"]), ("G", ["G", "B", "D"]), ("A", ["A", "C#", "E"])]
    for b in range(bars):
        root, ch = prog[b % 4]
        t0 = b * 4 * beat
        place(buf, pad([hz(n, 3) for n in ch], 4 * beat + 0.6) * 0.2, t0)
        arp = [hz(ch[0], 4), hz(ch[1], 4), hz(ch[2], 4), hz(ch[0], 5), hz(ch[2], 4), hz(ch[1], 4)]
        for k in range(12):
            place(buf, ks(arp[k % 6], beat * 1.6, 0.997, 0.7) * 0.14, t0 + k * beat / 3)
        place(buf, lp_fast(np.sin(2 * np.pi * hz(root, 2) * t_(4 * beat)), 400) * env(int(SR * 4 * beat), 0.1, 0.5, 0.5, 0.8, 2 * beat) * 0.3, t0)
    mel = [("F#", 5, 2), ("A", 5, 1), ("B", 5, 1), ("A", 5, 3), ("F#", 5, 1), ("G", 5, 2), ("F#", 5, 1), ("E", 5, 1), ("D", 5, 4),
           ("B", 4, 2), ("D", 5, 1), ("E", 5, 1), ("F#", 5, 3), ("E", 5, 1), ("C#", 5, 2), ("D", 5, 6)]
    t = 4 * 4 * beat
    for n, o, d in mel:
        f = hz(n, o)
        tt = t_(d * beat)
        fl = (np.sin(2 * np.pi * f * tt + 0.3 * np.sin(2 * np.pi * 5 * tt)) + 0.2 * np.sin(4 * np.pi * f * tt)) * env(len(tt), 0.08, 0.1, 0.7, 0.3, d * beat - 0.5)
        place(buf, fl * 0.18, t)
        t += d * beat
    y = reverb(buf, 2.2, 0.3)[: int(SR * L)]
    return norm(y, 0.8)


def write_ogg(name, x):
    tmp = "/tmp/_m.wav"
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", os.path.join(MUS, name + ".ogg")], check=True)

if "--no-music" not in sys.argv:
    write_ogg("battle", battle())
    write_ogg("menu", menu())
print("music done")
