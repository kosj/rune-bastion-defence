"""Compose and render Rune Bastion's music and musical cues with a General MIDI soundfont.

    python3 -I make_music.py SOUNDFONT.sf2 OUT_DIR [names...]

All music is original and written here as note data. Rendering uses sf2synth.py (own sample player).
Loops are rendered twice and the second pass is cut out, so reverb tails and release
tails carry across the loop point seamlessly. Requires ffmpeg for Ogg Vorbis encoding.
"""
import os
import subprocess
import sys
import numpy as np
from scipy.signal import fftconvolve, lfilter
import scipy.io.wavfile as wf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sf2synth import SF2, SR  # noqa: E402

PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def m(s):
    """'C#4' -> MIDI note number."""
    i, acc = 1, 0
    while i < len(s) and s[i] in "#b":
        acc += 1 if s[i] == "#" else -1
        i += 1
    return 12 * (int(s[i:]) + 1) + PC[s[0]] + acc


QUAL = {"": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "m7": [0, 3, 7, 10], "sus4": [0, 5, 7],
        "maj7": [0, 4, 7, 11], "dim": [0, 3, 6], "5": [0, 7], "add9": [0, 4, 7, 14]}


def chord(sym):
    """'F#m7/C#' -> (root_pc, [pcs], bass_pc)."""
    bass = None
    if "/" in sym:
        sym, b = sym.split("/")
        bass = (PC[b[0]] + (1 if b[1:2] == "#" else -1 if b[1:2] == "b" else 0)) % 12
    r = PC[sym[0]]
    q = sym[1:]
    if q[:1] in ("#", "b"):
        r += 1 if q[0] == "#" else -1
        q = q[1:]
    r %= 12
    pcs = [(r + x) % 12 for x in QUAL[q]]
    return r, pcs, bass if bass is not None else r


def near(pc, target):
    """MIDI note with pitch class pc closest to target."""
    base = target - ((target - pc) % 12)
    return base if target - base <= 6 else base + 12


def voice(pcs, prev, lo, hi):
    """Smooth voice leading: move each voice to the nearest chord tone, then fill missing tones."""
    out = []
    for p in prev:
        best = min((near(pc, p) for pc in pcs), key=lambda n: (abs(n - p), n))
        while best < lo:
            best += 12
        while best > hi:
            best -= 12
        out.append(best)
    for pc in pcs[:len(prev)]:
        if not any(n % 12 == pc for n in out):
            counts = {}
            for n in out:
                counts[n % 12] = counts.get(n % 12, 0) + 1
            # replace a doubled tone with the missing one, least movement
            cands = [i for i, n in enumerate(out) if counts[n % 12] > 1] or list(range(len(out)))
            i = min(cands, key=lambda i: abs(near(pc, out[i]) - out[i]))
            nn = near(pc, out[i])
            while nn < lo:
                nn += 12
            while nn > hi:
                nn -= 12
            out[i] = nn
    return sorted(out)


class Song:
    def __init__(self, bpm, bars, beats=4, seed=1):
        self.spb = 60.0 / bpm
        self.bars = bars
        self.beats = beats
        self.tracks = {}
        self.ev = []
        self.rng = np.random.default_rng(seed)

    @property
    def length(self):
        return self.bars * self.beats * self.spb

    def track(self, name, bank, prog, vol=1.0, pan=0.0, rev=0.25, jitter=0.006, vc=1.5, rel=3.0):
        self.tracks[name] = dict(bank=bank, prog=prog, vol=vol, pan=pan, rev=rev, jitter=jitter, vc=vc, rel=rel)

    def n(self, tr, bar, beat, dur, key, vel):
        if isinstance(key, str):
            key = m(key)
        self.ev.append((tr, (bar * self.beats + beat) * self.spb, dur * self.spb, int(key), int(vel)))

    def line(self, tr, bar, beat, notes, vel, legato=0.92, accent=None):
        """notes: [('D4', beats), ('r', beats), (['D4','F4'], beats)...]; returns end position."""
        pos = bar * self.beats + beat
        for i, (k, d) in enumerate(notes):
            if k != "r":
                v = vel(i) if callable(vel) else vel
                keys = k if isinstance(k, (list, tuple)) else [k]
                for kk in keys:
                    self.n(tr, 0, pos, d * legato, kk, v)
            pos += d
        return pos

    def roll(self, tr, bar, beat, beats, key, v0, v1, rate=8):
        steps = int(beats * rate)
        for i in range(steps):
            self.n(tr, bar, beat + i / rate, 1.0 / rate, key, v0 + (v1 - v0) * i / max(steps - 1, 1))


# ----------------------------------------------------------------------------- rendering
_cache = {}


def render(song, sf, passes=2, tail=4.0, master_rms_db=-17.0, reverb_s=2.3, reverb_mix=1.0):
    L = song.length
    total = int((L * passes + tail) * SR)
    dry = {}
    sends = np.zeros((total, 2), np.float32)
    mix = np.zeros((total, 2), np.float32)
    for name, t in song.tracks.items():
        dry[name] = np.zeros((total, 2), np.float32)
    rng = song.rng
    # humanize once per event so every pass is identical (seamless loops)
    hum = [(int(np.clip(vel + rng.integers(-4, 5), 1, 127)), rng.normal(0, song.tracks[tr]["jitter"]))
           for (tr, t0, dur, key, vel) in song.ev]
    for p in range(passes):
        for (tr, t0, dur, key, vel), (vj, jit) in zip(song.ev, hum):
            T = song.tracks[tr]
            ck = (T["bank"], T["prog"], key, vj, round(dur, 3), T["vc"], T["rel"])
            x = _cache.get(ck)
            if x is None:
                x = sf.note(T["bank"], T["prog"], key, vj, dur, max_release=T["rel"], vel_curve=T["vc"])
                _cache[ck] = x
            start = int((t0 + p * L + jit) * SR)
            start = max(start, 0)
            end = min(start + x.shape[0], total)
            dry[tr][start:end] += x[:end - start]
    for name, T in song.tracks.items():
        buf = dry[name] * T["vol"]
        if T["pan"]:
            a = (T["pan"] + 1.0) * np.pi / 4.0
            l = buf[:, 0] * np.cos(a) * 1.4142
            r = buf[:, 1] * np.sin(a) * 1.4142
            buf = np.stack([l, r], axis=1)
        mix += buf
        sends += buf * T["rev"]
    wet = reverb(sends, reverb_s) * reverb_mix
    out = mix + wet[:total]
    return out, L


def reverb(x, rt60=2.3, seed=7):
    rng = np.random.default_rng(seed)
    n = int(rt60 * 1.2 * SR)
    t = np.arange(n) / SR
    decay = np.exp(-6.91 * t / rt60)
    ir = np.zeros((n, 2), np.float32)
    for ch in range(2):
        noise = rng.standard_normal(n)
        # darker as it decays: blend toward low-passed noise over time
        b1 = np.array([0.12]); a1 = np.array([1.0, -0.88])
        dark = lfilter(b1, a1, noise) * 2.2
        w = np.clip(t / (rt60 * 0.5), 0, 1)
        tail = (noise * (1 - w) + dark * w) * decay
        tail[: int(0.018 * SR)] = 0.0  # pre-delay
        # a few early reflections
        for d, g in ((0.011, 0.5), (0.019, 0.38), (0.027, 0.3), (0.041, 0.22), (0.053, 0.18)):
            k = int((d + 0.002 * ch) * SR)
            ir[k, ch] += g * (1 if rng.random() > 0.5 else -1)
        ir[:, ch] += tail.astype(np.float32) * 0.09
    ir /= np.sqrt((ir ** 2).sum() / 2)
    out = np.zeros((x.shape[0] + n - 1, 2), np.float32)
    for ch in range(2):
        out[:, ch] = fftconvolve(x[:, ch], ir[:, ch])
    return out * 0.6


def master(y, rms_db=-17.0, ceiling=0.89):
    r = np.sqrt(np.mean(y ** 2)) + 1e-9
    y = y * (10 ** (rms_db / 20.0) / r)
    knee = 0.7
    a = np.abs(y)
    over = a > knee
    y[over] = np.sign(y[over]) * (knee + (1 - knee) * np.tanh((a[over] - knee) / (1 - knee)))
    pk = np.abs(y).max()
    if pk > ceiling:
        y *= ceiling / pk
    return y


def write_ogg(y, path, q=4):
    tmp = path + ".tmp.wav"
    wf.write(tmp, SR, (np.clip(y, -1, 1) * 32767).astype(np.int16))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(q), path], check=True)
    os.remove(tmp)


def loop_track(song, sf, path, rms_db=-17.0, q=4, reverb_s=2.3):
    y, L = render(song, sf, passes=3, reverb_s=reverb_s)
    n0, n1 = int(L * SR), int(2 * L * SR)
    seg = master(y[n0:n1].copy(), rms_db)
    write_ogg(seg, path, q)
    return seg.shape[0] / SR


def cue(song, sf, path, rms_db=-15.0, q=5, fade=0.6, reverb_s=2.0, length=None):
    y, L = render(song, sf, passes=1, tail=3.5, reverb_s=reverb_s)
    a = np.abs(y).max(axis=1)
    thr = a.max() * 10 ** (-58 / 20)
    end = len(a) - np.argmax(a[::-1] > thr)
    if length:
        end = min(end, int(length * SR))
    y = y[:end].copy()
    f = int(fade * SR)
    if f and f < len(y):
        y[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
    y = master(y, rms_db)
    write_ogg(y, path, q)
    return len(y) / SR


# ============================================================================== MUSIC

def orch_kit(s, vol=1.0, rev=0.3):
    s.track("kit", 128, 48, vol=vol, rev=rev, jitter=0.003, vc=1.3, rel=3.0)


def menu_theme():
    """Warm heroic main theme in D major (title / world map)."""
    s = Song(84, 24, seed=11)
    s.track("harp", 0, 46, vol=0.8, pan=-0.35, rev=0.45)
    s.track("pad", 0, 49, vol=0.6, rev=0.5, jitter=0.01, rel=2.5)
    s.track("cello", 0, 42, vol=0.85, pan=0.25, rev=0.35)
    s.track("bass", 0, 43, vol=0.7, pan=0.3, rev=0.3)
    s.track("horn", 0, 60, vol=2.0, pan=-0.15, rev=0.45, rel=2.0)
    s.track("vln", 0, 49, vol=1.9, pan=-0.2, rev=0.5, rel=2.0)
    s.track("flute", 0, 73, vol=1.5, pan=0.2, rev=0.5)
    s.track("glock", 0, 9, vol=1.3, pan=0.3, rev=0.5)
    s.track("timp", 0, 47, vol=0.9, rev=0.35, jitter=0.002)
    orch_kit(s, 0.7)
    prog = ["D", "Bm", "G", "A", "D", "Bm", "G", "A", "D/F#", "G", "Em7", "A",
            "Bm", "G", "D", "A", "Bm", "G", "Em", "A", "G", "A", "Bm", "A"]
    dyn = [52, 55, 58, 60] + [70] * 8 + [86] * 8 + [62, 58, 55, 50]
    v = [m("F#3"), m("A3"), m("D4"), m("F#4")]
    for bar, sym in enumerate(prog):
        r, pcs, bass = chord(sym)
        v = voice(pcs, v, m("E3"), m("B4"))
        for k in v:
            s.n("pad", bar, 0, 3.97, k, dyn[bar] - 8)
        # bass: half notes (quarters in the B section)
        b2 = near(bass, m("D2") if bass >= 2 else m("E2"))
        if b2 < m("C2"):
            b2 += 12
        if 12 <= bar < 20:
            for q in range(4):
                s.n("bass", bar, q, 0.95, b2, dyn[bar] - 6)
                s.n("cello", bar, q, 0.95, b2 + 12, dyn[bar] - 10)
        else:
            s.n("bass", bar, 0, 1.95, b2, dyn[bar] - 4)
            s.n("bass", bar, 2, 1.95, b2, dyn[bar] - 10)
            s.n("cello", bar, 0, 3.9, b2 + 12, dyn[bar] - 8)
        # harp arpeggio (eighths), lighter in the strings section
        tones = sorted({near(pc, m("D3") + 4) for pc in pcs})
        tones = [t for t in tones] + [t + 12 for t in tones] + [tones[0] + 24]
        pat = [0, 1, 2, 3, 4, 3, 2, 1]
        for i, ix in enumerate(pat):
            if 12 <= bar < 20 and i % 2:
                continue
            s.n("harp", bar, i * 0.5, 0.9, tones[min(ix, len(tones) - 1)], dyn[bar] - (6 if i else 0))
    # horn melody, section A (bars 4..11)
    s.line("horn", 4, 0, [("D4", 1), ("A4", 1.5), ("G4", .5), ("F#4", 1),
                          ("E4", 1.5), ("F#4", .5), ("D4", 2),
                          ("B3", 1), ("D4", 1), ("G4", 1.5), ("F#4", .5),
                          ("E4", 3), ("r", 1),
                          ("D4", 1), ("A4", 1.5), ("B4", .5), ("A4", 1),
                          ("D5", 2), ("B4", 1), ("G4", 1),
                          ("A4", 1.5), ("G4", .5), ("F#4", 1), ("E4", 1),
                          ("E4", 3), ("A3", 1)], lambda i: 82 if i % 3 == 0 else 74, legato=0.97)
    # flute answer while the horn holds
    s.line("flute", 7, 2, [("A4", .5), ("B4", .5), ("C#5", .5), ("D5", .5)], 64)
    s.line("flute", 11, 2, [("C#5", .5), ("D5", .5), ("E5", 1)], 62)
    # violins, section B (bars 12..19)
    s.line("vln", 12, 0, [("D5", 1.5), ("C#5", .5), ("B4", 1), ("F#5", 1),
                          ("G5", 2), ("F#5", 1), ("E5", 1),
                          ("F#5", 1.5), ("E5", .5), ("D5", 1), ("A4", 1),
                          ("E5", 3), ("C#5", 1),
                          ("D5", 1.5), ("E5", .5), ("F#5", 1), ("B5", 1),
                          ("D6", 2), ("B5", 1), ("G5", 1),
                          ("A5", 1.5), ("G5", .5), ("F#5", 1), ("E5", 1),
                          ("E5", 2), ("C#5", 2)], lambda i: 92 if i % 4 == 0 else 84, legato=0.98)
    s.line("glock", 12, 0, [("D6", 4), ("G6", 4), ("F#6", 4), ("E6", 4)], 60)
    for bar, k in zip(range(12, 20), ["F#4", "G4", "F#4", "E4", "F#4", "G4", "G4", "E4"]):
        s.n("horn", bar, 0, 3.9, k, 68)
    # outro on the flute
    s.line("flute", 20, 0, [("D5", 1), ("B4", 1), ("G4", 2), ("A4", 1.5), ("B4", .5), ("C#5", 2),
                            ("D5", 2), ("F#4", 2), ("E4", 4)], 60, legato=0.97)
    # timpani + cymbal into the strings section
    s.roll("timp", 11, 2, 2, "A2", 40, 88, rate=10)
    for bar in (12, 14, 16, 18):
        s.n("timp", bar, 0, 1, near(chord(prog[bar])[0], m("A2")), 84)
    s.n("kit", 12, 0, 3, 59, 70)
    s.n("kit", 16, 0, 3, 59, 56)
    s.prog = prog
    return s


def battle_theme():
    """Driving D-minor battle loop."""
    s = Song(132, 32, seed=21)
    s.track("ost", 0, 48, vol=1.1, pan=-0.25, rev=0.22, rel=0.4)
    s.track("cello", 0, 42, vol=1.05, pan=0.2, rev=0.2, rel=0.3)
    s.track("bass", 0, 43, vol=1.1, pan=0.25, rev=0.2, rel=0.3)
    s.track("brass", 0, 61, vol=0.75, pan=0.1, rev=0.3, rel=0.6)
    s.track("bone", 0, 57, vol=0.7, pan=0.3, rev=0.3, rel=0.6)
    s.track("horn", 0, 60, vol=1.35, pan=-0.1, rev=0.4, rel=1.2)
    s.track("tpt", 0, 56, vol=1.3, pan=-0.2, rev=0.4, rel=0.8)
    s.track("vln", 0, 48, vol=1.4, pan=-0.3, rev=0.4, rel=0.8)
    s.track("choir", 0, 52, vol=0.45, rev=0.5, jitter=0.01, rel=1.5)
    s.track("timp", 0, 47, vol=0.95, rev=0.25, jitter=0.002, rel=1.5)
    orch_kit(s, 0.55, rev=0.2)
    prog = (["Dm", "Dm", "Bb", "C", "Dm", "Dm", "Gm", "A"] +
            ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"] +
            ["Bb", "C", "Dm", "Dm/C", "Bb", "C", "A", "A"] +
            ["Dm", "Bb", "F", "C", "Dm", "Bb", "Gm", "A"])
    v = [m("D4"), m("F4"), m("A4")]
    for bar, sym in enumerate(prog):
        r, pcs, bass = chord(sym)
        sec = bar // 8
        loud = [0, 6, 12, 10][sec]
        # ostinato: gallop in eighths/sixteenths on chord tones
        tones = sorted({near(pc, m("F4")) for pc in pcs[:3]})
        rt = near(r, m("D4"))
        pat = [rt, rt, tones[-1], rt, tones[1] if len(tones) > 1 else rt, rt, tones[-1], rt]
        for i, k in enumerate(pat):
            s.n("ost", bar, i * 0.5, 0.32, k, (96 if i % 2 == 0 else 78) + loud)
        b2 = near(bass, m("D2") + 3)
        for q in range(4):
            s.n("bass", bar, q, 0.4, b2, 98 + loud)
            s.n("bass", bar, q + 0.5, 0.18, b2, 76 + loud)
            s.n("bass", bar, q + 0.75, 0.18, b2, 82 + loud)
            s.n("cello", bar, q, 0.4, b2 + 12, 90 + loud)
            s.n("cello", bar, q + 0.5, 0.2, b2 + 12, 70 + loud)
            s.n("cello", bar, q + 0.75, 0.2, b2 + 12, 76 + loud)
        # brass stabs
        v = voice(pcs[:3], v, m("A3"), m("E5"))
        if sec != 1:
            for (bt, d, vv) in ((0, 0.7, 104), (1.5, 0.4, 92), (3, 0.45, 96)):
                for k in v:
                    s.n("brass", bar, bt, d, k, vv + loud - 6)
                s.n("bone", bar, bt, d, near(r, m("D3")), vv + loud - 4)
        else:
            s.n("bone", bar, 0, 3.6, near(r, m("D3")), 80)
        # timpani
        s.n("timp", bar, 0, 1, near(r, m("A2")), 104 + loud // 2)
        s.n("timp", bar, 2, 1, near((r + 7) % 12, m("A2")), 86 + loud // 2)
        # percussion: taiko on 1 & 3, snare pickups, crash per phrase
        s.n("kit", bar, 0, 1, 36, 108)
        s.n("kit", bar, 2, 1, 35, 92)
        s.n("kit", bar, 2.5, 0.5, 38, 58)
        s.n("kit", bar, 3.5, 0.25, 38, 70)
        s.n("kit", bar, 3.75, 0.25, 38, 76)
        if bar % 8 == 0:
            s.n("kit", bar, 0, 3, 57, 104 if bar else 92)
            s.n("kit", bar, 0, 3, 59, 90)
        if bar % 8 == 7:
            s.roll("kit", bar, 2, 2, 38, 60, 112, rate=8)
        if sec >= 2:
            for (k, d) in zip(voice(pcs[:3], [m("D4"), m("F4"), m("A4")], m("C4"), m("A4")), (3.9, 3.9, 3.9)):
                s.n("choir", bar, 0, d, k, 86 + (8 if sec == 2 else 0))
    hm = [("D4", 2), ("A4", 1.5), ("G4", .5),
          ("F4", 1.5), ("G4", .5), ("D4", 2),
          ("C4", 1), ("F4", 1), ("A4", 1), ("C5", 1),
          ("C5", 2), ("Bb4", 1), ("G4", 1),
          ("A4", 2), ("D5", 1.5), ("C5", .5),
          ("Bb4", 1.5), ("A4", .5), ("F4", 2),
          ("G4", 1), ("Bb4", 1), ("D5", 1.5), ("C5", .5),
          ("C#5", 3), ("A4", 1)]
    s.line("horn", 8, 0, hm, lambda i: 100 if i % 3 == 0 else 92, legato=0.96)
    # fanfare (section C)
    s.line("tpt", 16, 0, [("Bb4", 1), ("D5", 1), ("F5", 2),
                          ("E5", 1.5), ("D5", .5), ("C5", 2),
                          ("D5", 1), ("A4", 1), ("D5", 1), ("F5", 1),
                          ("F5", 1.5), ("E5", .5), ("D5", 2),
                          ("F5", 2), ("D5", 2),
                          ("E5", 2), ("G5", 2),
                          ("A5", 4)], lambda i: 104 if i % 2 == 0 else 96, legato=0.9)
    s.line("horn", 16, 0, [("F4", 4), ("G4", 4), ("A4", 4), ("A4", 4), ("F4", 4), ("G4", 4), ("E4", 4), ("E4", 4)], 90)
    # strings take the theme an octave up (section D), horns hold
    s.line("vln", 24, 0, [(k if k == "r" else k[:-1] + str(int(k[-1]) + 1), d) for k, d in hm],
           lambda i: 104 if i % 3 == 0 else 96, legato=0.97)
    s.line("horn", 24, 0, [("F4", 4), ("F4", 4), ("A4", 4), ("G4", 4), ("F4", 4), ("F4", 4), ("D4", 4), ("E4", 4)], 86)
    s.prog = prog
    return s


def boss_theme():
    """E Phrygian boss battle: grinding E-F ostinato, choir, low brass theme."""
    s = Song(144, 24, seed=31)
    s.track("ost", 0, 48, vol=1.35, pan=-0.25, rev=0.2, rel=0.3)
    s.track("trem", 0, 44, vol=0.55, pan=0.3, rev=0.45, rel=1.0)
    s.track("cello", 0, 42, vol=1.25, pan=0.2, rev=0.2, rel=0.3)
    s.track("bass", 0, 43, vol=1.3, pan=0.2, rev=0.2, rel=0.3)
    s.track("bone", 0, 57, vol=0.9, pan=0.25, rev=0.3, rel=0.8)
    s.track("tuba", 0, 58, vol=0.7, rev=0.25, rel=0.8)
    s.track("horn", 0, 60, vol=1.15, pan=-0.15, rev=0.4, rel=1.2)
    s.track("tpt", 0, 56, vol=1.45, pan=-0.2, rev=0.4, rel=0.6)
    s.track("choir", 0, 52, vol=0.7, rev=0.55, jitter=0.01, rel=1.5)
    s.track("timp", 0, 47, vol=1.0, rev=0.25, jitter=0.002, rel=1.2)
    orch_kit(s, 0.65, rev=0.22)
    prog = (["Em", "Em", "F", "Em", "Em", "Em", "F", "B"] +
            ["C", "B", "Am", "B", "C", "D", "B", "B"] +
            ["Em", "F", "Em", "F", "G", "F", "B", "B"])
    for bar, sym in enumerate(prog):
        r, pcs, bass = chord(sym)
        sec = bar // 8
        # grinding ostinato: root with half-step neighbour
        rt = near(r, m("E4"))
        nb = rt + 1 if sym in ("Em", "B") else rt
        pat = [rt, rt, nb, rt, rt, rt, nb, rt + 7 if sec == 2 else rt]
        for i, k in enumerate(pat):
            s.n("ost", bar, i * 0.5, 0.3, k, 100 if i in (0, 3, 6) else 80)
        b2 = near(bass, m("E2"))
        for i in range(8):
            s.n("bass", bar, i * 0.5, 0.3, b2, 104 if i in (0, 3, 6) else 80)
            s.n("cello", bar, i * 0.5, 0.3, b2 + 12, 96 if i in (0, 3, 6) else 74)
        # tremolo strings + choir sustain the harmony
        hv = sorted({near(pc, m("B4")) for pc in pcs})
        for k in hv:
            s.n("trem", bar, 0, 3.95, k, 70 + sec * 8)
        cv = sorted({near(pc, m("G4")) for pc in pcs})
        for k in cv:
            s.n("choir", bar, 0, 3.95, k, 84 + sec * 6)
        s.n("tuba", bar, 0, 1.8, b2, 92)
        s.n("tuba", bar, 2, 1.8, b2, 84)
        # timpani 3+3+2 pattern, taiko accents
        for bt in (0, 1.5, 3):
            s.n("timp", bar, bt, 0.5, near(r, m("B2")), 108 if bt == 0 else 94)
            s.n("kit", bar, bt, 1, 36 if bt == 0 else 35, 110 if bt == 0 else 96)
        s.n("kit", bar, 3.5, 0.25, 38, 74)
        s.n("kit", bar, 3.75, 0.25, 38, 84)
        if bar % 4 == 0:
            s.n("kit", bar, 0, 3, 57, 108)
        if bar % 8 == 7:
            s.roll("kit", bar, 0, 4, 38, 56, 116, rate=8)
            s.roll("timp", bar, 2, 2, near(r, m("B2")), 70, 120, rate=12)
    # low brass statement over the first section
    for bar, k in zip(range(0, 8), ["E3", "E3", "F3", "E3", "G3", "E3", "F3", "D#3"]):
        s.n("bone", bar, 0, 3.6, k, 96)
    theme = [("G4", 3), ("E4", 1), ("F#4", 3), ("D#4", 1), ("E4", 1), ("A4", 1), ("C5", 1.5), ("B4", .5),
             ("B4", 4), ("C5", 3), ("B4", 1), ("A4", 3), ("F#4", 1), ("B4", 1.5), ("A4", .5), ("F#4", 2),
             ("D#4", 4)]
    s.line("horn", 8, 0, theme, lambda i: 108 if i % 2 == 0 else 100, legato=0.96)
    s.line("bone", 8, 0, [(k[:-1] + str(int(k[-1]) - 1), d) for k, d in theme], 100, legato=0.96)
    for bar in range(16, 24):
        s.line("tpt", bar, 0, [("E5", 0.5), ("F5", 0.5), ("E5", 1)] if prog[bar] != "B" else [("D#5", 0.5), ("E5", 0.5), ("D#5", 1)], 104)
    s.prog = prog
    return s


def battle_dark():
    """Brooding 6/8 march for the dark regions (citadel, falls, temple)."""
    s = Song(100, 32, beats=6, seed=41)  # 6/8: one "beat" is an eighth note
    s.spb = 60.0 / (100 * 3)  # dotted quarter = 100
    s.track("ost", 0, 45, vol=0.9, pan=-0.3, rev=0.35, rel=0.5)
    s.track("low", 0, 48, vol=0.7, pan=0.2, rev=0.3, rel=0.4)
    s.track("bass", 0, 43, vol=0.85, pan=0.25, rev=0.25, rel=0.4)
    s.track("pad", 0, 49, vol=0.7, rev=0.55, jitter=0.01, rel=2.0)
    s.track("choir", 0, 52, vol=0.85, rev=0.6, jitter=0.012, rel=1.8)
    s.track("oboe", 0, 68, vol=1.0, pan=0.15, rev=0.5, rel=1.0)
    s.track("horn", 0, 60, vol=1.1, pan=-0.15, rev=0.45, rel=1.2)
    s.track("celesta", 0, 8, vol=1.3, pan=0.35, rev=0.6)
    s.track("timp", 0, 47, vol=0.95, rev=0.3, jitter=0.002, rel=1.5)
    orch_kit(s, 0.7, rev=0.28)
    prog = (["Am", "Am", "F", "E", "Am", "Am", "Dm", "E"] +
            ["F", "G", "Am", "Am", "F", "G", "E", "E"] +
            ["Dm", "Am", "Dm", "E", "F", "Dm", "E", "E"] +
            ["Am", "Am", "F", "E", "Am", "Am", "Dm", "E"])
    for bar, sym in enumerate(prog):
        r, pcs, bass = chord(sym)
        sec = min(bar // 8, 2)
        tones = sorted({near(pc, m("C4")) for pc in pcs[:3]})
        rt = near(r, m("A3"))
        # pizzicato 6/8 lilt: 1 . 3 4 . 6
        for i, (e, k) in enumerate(((0, rt), (2, tones[-1]), (3, rt + 12), (5, tones[1]))):
            s.n("ost", bar, e, 0.8, k, 92 if i in (0, 2) else 72)
        b2 = near(bass, m("A1") + 4)
        s.n("bass", bar, 0, 2.6, b2, 96)
        s.n("bass", bar, 3, 2.6, b2, 84)
        s.n("low", bar, 0, 1.2, b2 + 12, 82)
        s.n("low", bar, 3, 1.2, b2 + 12, 74)
        for k in sorted({near(pc, m("E4")) for pc in pcs}):
            s.n("pad", bar, 0, 5.9, k, 66 + sec * 6)
        if sec >= 1:
            for k in sorted({near(pc, m("A4")) for pc in pcs[:3]}):
                s.n("choir", bar, 0, 5.9, k, 74 + sec * 6)
        s.n("timp", bar, 0, 2, near(r, m("A2")), 96)
        s.n("kit", bar, 0, 2, 36, 96)
        s.n("kit", bar, 3, 2, 35, 80)
        s.n("kit", bar, 5, 1, 38, 60)
        if bar % 8 == 0:
            s.n("kit", bar, 0, 4, 59, 84)
        if bar % 8 == 7:
            s.roll("timp", bar, 3, 3, near(r, m("A2")), 60, 112, rate=4)
        if bar % 2 == 0:
            s.n("celesta", bar, 0, 1, near(pcs[1], m("A5")), 64)
            s.n("celesta", bar, 1, 1, near(pcs[2], m("A5")), 54)
    # oboe lament, then horns
    lament = [("E5", 3), ("D5", 1), ("C5", 1), ("B4", 1), ("A4", 4), ("C5", 2),
              ("C5", 3), ("B4", 1), ("A4", 2), ("B4", 6),
              ("E5", 3), ("F5", 1), ("E5", 1), ("D5", 1), ("C5", 4), ("A4", 2),
              ("D5", 3), ("C5", 1), ("B4", 1), ("A4", 1), ("G#4", 6)]
    s.line("oboe", 0, 0, lament, lambda i: 86 if i % 3 == 0 else 78, legato=0.97)
    s.line("horn", 8, 0, [("A4", 3), ("C5", 3), ("B4", 4), ("G4", 2), ("C5", 3), ("E5", 3), ("E5", 6),
                          ("A4", 3), ("C5", 3), ("D5", 4), ("B4", 2), ("G#4", 6), ("B4", 6)],
           lambda i: 98 if i % 2 == 0 else 90, legato=0.97)
    s.line("oboe", 16, 0, [("F5", 3), ("E5", 3), ("C5", 6), ("A5", 3), ("F5", 3), ("E5", 6),
                           ("F5", 3), ("D5", 3), ("A4", 6), ("B4", 6), ("G#4", 6)], 84, legato=0.97)
    s.line("horn", 16, 0, [("D4", 6), ("E4", 6), ("F4", 6), ("E4", 6), ("C4", 6), ("D4", 6), ("E4", 12)], 84)
    # last section: the lament returns on the horns an octave down, oboe echoes above
    s.line("horn", 24, 0, [(k[:-1] + str(int(k[-1]) - 1), d) for k, d in lament], lambda i: 96 if i % 3 == 0 else 88, legato=0.97)
    for bar in range(24, 32, 2):
        s.n("oboe", bar, 3, 2.5, near(chord(prog[bar])[1][2], m("E5")), 70)
    s.prog = prog
    return s


# ------------------------------------------------------------------------------ cues

def cue_victory():
    s = Song(100, 3, seed=51)
    s.track("tpt", 0, 56, vol=1.0, pan=-0.2, rev=0.4)
    s.track("brass", 0, 61, vol=0.9, rev=0.4, rel=1.5)
    s.track("horn", 0, 60, vol=1.0, pan=0.2, rev=0.45, rel=1.5)
    s.track("pad", 0, 48, vol=0.9, rev=0.5, rel=1.8)
    s.track("harp", 0, 46, vol=0.8, pan=-0.3, rev=0.5)
    s.track("glock", 0, 9, vol=0.6, pan=0.3, rev=0.5)
    s.track("timp", 0, 47, vol=1.0, rev=0.3)
    orch_kit(s, 1.0)
    s.line("tpt", 0, 0, [("A4", .33), ("A4", .33), ("A4", .34), ("D5", 1), ("F#5", 1), ("A5", 3)], 108, legato=0.9)
    s.line("horn", 0, 1, [("D4", 1), ("F#4", 1), ("A4", 3)], 96)
    for k in (m("D4"), m("F#4"), m("A4"), m("D5")):
        s.n("brass", 0, 3, 3.5, k, 104)
        s.n("pad", 0, 3, 4.5, k - 12, 96)
    s.n("brass", 0, 3, 3.5, m("D3"), 100)
    for i, k in enumerate(["D4", "F#4", "A4", "D5", "F#5", "A5", "D6"]):
        s.n("harp", 0, 3 + i * 0.12, 2, k, 90)
    s.line("glock", 0, 3, [("A5", .5), ("D6", .5), ("F#6", .5), ("A6", 2)], 80)
    s.n("timp", 0, 0, 1, m("A2"), 100)
    s.roll("timp", 0, 1, 2, "A2", 60, 110, rate=12)
    s.n("timp", 0, 3, 2, m("D2") + 12, 118)
    s.n("kit", 0, 3, 4, 57, 112)
    s.n("kit", 0, 3, 4, 59, 100)
    return s


def cue_defeat():
    s = Song(72, 3, seed=52)
    s.track("str", 0, 49, vol=1.0, rev=0.5, rel=2.0)
    s.track("cello", 0, 42, vol=0.9, rev=0.4, rel=2.0)
    s.track("horn", 0, 60, vol=1.0, rev=0.5, rel=2.0)
    s.track("timp", 0, 47, vol=1.0, rev=0.4)
    orch_kit(s, 0.9, rev=0.4)
    s.line("horn", 0, 0, [("A4", 1), ("G4", 1), ("F4", 1), ("E4", 1), ("D4", 4)], 92, legato=0.98)
    for k, b, d in (("D4", 0, 2), ("F4", 0, 2), ("Bb3", 2, 2), ("D4", 2, 2), ("A3", 4, 4), ("D4", 4, 4), ("F4", 4, 4)):
        s.n("str", 0, b, d - 0.05, m(k), 80)
    s.line("cello", 0, 0, [("D3", 2), ("Bb2", 2), ("D2", 4)], 88, legato=0.99)
    s.roll("timp", 0, 3, 1, "D2", 50, 100, rate=12)
    s.n("timp", 0, 4, 2, m("D2"), 112)
    s.n("kit", 0, 4, 3, 59, 70)
    return s


def cue_horn():
    """Wave call: horns + taiko."""
    s = Song(100, 2, seed=53)
    s.track("horn", 0, 60, vol=1.2, rev=0.5, rel=1.5)
    s.track("bone", 0, 57, vol=0.8, rev=0.45, rel=1.2)
    s.track("timp", 0, 47, vol=1.0, rev=0.35)
    orch_kit(s, 1.0, rev=0.35)
    s.line("horn", 0, 0, [("A3", .5), ("D4", .5), ("A4", 2.5)], 108, legato=0.96)
    s.line("horn", 0, 1, [("F#4", 2)], 92)
    s.line("bone", 0, 1, [("D3", 2)], 98)
    s.n("kit", 0, 0, 1, 36, 112)
    s.n("kit", 0, 1, 1, 36, 120)
    s.n("timp", 0, 1, 1, m("D2") + 12, 112)
    return s


def cue_boss():
    """Boss entrance: low brass swell, choir, taiko + cymbal hit."""
    s = Song(90, 3, seed=54)
    s.track("bone", 0, 57, vol=1.0, rev=0.45, rel=1.5)
    s.track("tuba", 0, 58, vol=0.9, rev=0.4, rel=1.5)
    s.track("choir", 0, 52, vol=1.0, rev=0.6, rel=2.0)
    s.track("trem", 0, 44, vol=0.7, rev=0.5, rel=1.5)
    s.track("timp", 0, 47, vol=1.0, rev=0.35)
    orch_kit(s, 1.1, rev=0.35)
    s.roll("timp", 0, 0, 2, "E2", 40, 120, rate=14)
    for k, v0 in (("E2", 70), ("B2", 70), ("E3", 70)):
        for i in range(4):
            s.n("bone" if k != "E2" else "tuba", 0, i * 0.5, 0.5, m(k), v0 + i * 12)
    for k in ("E2", "B2", "E3", "F3"):
        s.n("bone" if k != "E2" else "tuba", 0, 2, 3.0, m(k), 118)
    for k in ("E4", "G4", "B4", "C5"):
        s.n("choir", 0, 2, 3.0, m(k), 110)
        s.n("trem", 0, 0, 2, m(k) + 12, 60)
    s.n("kit", 0, 2, 3, 36, 127)
    s.n("kit", 0, 2, 3, 35, 120)
    s.n("kit", 0, 2, 4, 59, 118)
    s.n("kit", 0, 2, 4, 57, 110)
    s.n("timp", 0, 2, 2, m("E2"), 124)
    return s


def cue_levelup():
    s = Song(120, 2, seed=55)
    s.track("harp", 0, 46, vol=1.0, rev=0.5)
    s.track("glock", 0, 9, vol=0.8, rev=0.5)
    s.track("str", 0, 49, vol=0.7, rev=0.5, rel=1.0)
    for i, k in enumerate(["D4", "F#4", "A4", "D5", "F#5", "A5"]):
        s.n("harp", 0, i * 0.18, 1.5, m(k), 96)
    s.line("glock", 0, 0.9, [("A5", .3), ("D6", 1.5)], 92)
    for k in ("D4", "F#4", "A4"):
        s.n("str", 0, 0.9, 1.4, m(k), 80)
    return s


def cue_upgrade():
    s = Song(140, 1, seed=56)
    s.track("glock", 0, 9, vol=0.9, rev=0.45)
    s.track("cel", 0, 8, vol=0.7, rev=0.45)
    s.line("glock", 0, 0, [("E5", .35), ("A5", .35), ("C#6", 1.5)], 94)
    s.line("cel", 0, 0, [("E5", .35), ("A5", .35), ("C#6", 1.5)], 80)
    return s


def cue_star():
    s = Song(120, 1, seed=57)
    s.track("cel", 0, 8, vol=0.9, rev=0.5)
    s.track("glock", 0, 9, vol=0.6, rev=0.5)
    s.n("cel", 0, 0, 1.5, m("A5"), 96)
    s.n("cel", 0, 0, 1.5, m("E6"), 80)
    s.n("glock", 0, 0, 1.5, m("A6"), 80)
    return s


MUSIC = {"menu": (menu_theme, -18.5), "battle": (battle_theme, -17.0), "boss": (boss_theme, -16.5),
         "battle_dark": (battle_dark, -17.5)}
CUES = {"victory": cue_victory, "defeat": cue_defeat, "horn": cue_horn, "boss_intro": cue_boss,
        "levelup": cue_levelup, "upgrade": cue_upgrade, "star": cue_star}


def main():
    sf = SF2(sys.argv[1])
    out = sys.argv[2]
    want = set(sys.argv[3:])
    os.makedirs(os.path.join(out, "music"), exist_ok=True)
    os.makedirs(os.path.join(out, "sfx"), exist_ok=True)
    for name, (fn, rms) in MUSIC.items():
        if want and name not in want:
            continue
        secs = loop_track(fn(), sf, os.path.join(out, "music", name + ".ogg"), rms)
        print("MUSIC", name, round(secs, 1), "s")
    for name, fn in CUES.items():
        if want and name not in want:
            continue
        secs = cue(fn(), sf, os.path.join(out, "sfx", name + ".ogg"))
        print("CUE", name, round(secs, 2), "s")


if __name__ == "__main__":
    main()
