"""Minimal SoundFont 2 sample player (own implementation, numpy only).

Reads a .sf2 as plain data and renders notes offline:
  * preset/instrument zones with key/velocity ranges, global zones, additive preset generators
  * sample loops, root key / scale tuning / coarse+fine tune, vibrato + mod LFO to pitch
  * DAHDSR volume envelope (linear attack, dB-linear decay/release), initial attenuation
  * static low-pass filter with the modulation envelope blended in (cheap filter sweep)
The soundfont file is only data; nothing from it is executed.
"""
import struct
import numpy as np
from scipy.signal import lfilter

SR = 44100

DEFAULTS = {
    0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 13500, 9: 0, 10: 0, 11: 0, 12: 0, 13: 0,
    15: 0, 16: 0, 17: 0, 21: -12000, 22: 0, 23: -12000, 24: 0, 25: -12000, 26: -12000, 27: -12000,
    28: -12000, 29: 0, 30: -12000, 31: 0, 32: 0, 33: -12000, 34: -12000, 35: -12000, 36: -12000,
    37: 0, 38: -12000, 39: 0, 40: 0, 45: 0, 46: -1, 47: -1, 48: 0, 50: 0, 51: 0, 52: 0, 54: 0,
    56: 100, 57: 0, 58: -1,
}
# generators that are not additive at preset level (spec 8.5)
NOT_PRESET = {0, 1, 2, 3, 4, 12, 45, 50, 54, 57, 58, 46, 47, 41, 53, 43, 44}


def s16(v):
    return v - 65536 if v >= 32768 else v


def rng(v):
    return v & 0xFF, (v >> 8) & 0xFF


def tc(v):
    return 2.0 ** (v / 1200.0)


class Region:
    __slots__ = ("klo", "khi", "vlo", "vhi", "g", "sh")

    def __init__(self, klo, khi, vlo, vhi, g, sh):
        self.klo, self.khi, self.vlo, self.vhi, self.g, self.sh = klo, khi, vlo, vhi, g, sh


class SF2:
    def __init__(self, path):
        data = open(path, "rb").read()
        if data[0:4] != b"RIFF" or data[8:12] != b"sfbk":
            raise ValueError("not a soundfont")
        chunks = {}
        pos = 12
        while pos + 8 <= len(data):
            cid = data[pos:pos + 4]
            size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
            body = data[pos + 8:pos + 8 + size]
            if cid == b"LIST":
                sub = 4
                while sub + 8 <= len(body):
                    sid = body[sub:sub + 4]
                    ssize = struct.unpack("<I", body[sub + 4:sub + 8])[0]
                    chunks[sid] = body[sub + 8:sub + 8 + ssize]
                    sub += 8 + ssize + (ssize & 1)
            pos += 8 + size + (size & 1)
        self.smpl = np.frombuffer(chunks[b"smpl"], dtype="<i2").astype(np.float32) / 32768.0

        def recs(cid, fmt):
            sz = struct.calcsize(fmt)
            b = chunks[cid]
            return [struct.unpack(fmt, b[i:i + sz]) for i in range(0, len(b) - sz + 1, sz)]

        self.phdr = recs(b"phdr", "<20sHHHIII")
        self.pbag = recs(b"pbag", "<HH")
        self.pgen = recs(b"pgen", "<HH")
        self.inst = recs(b"inst", "<20sH")
        self.ibag = recs(b"ibag", "<HH")
        self.igen = recs(b"igen", "<HH")
        self.shdr = recs(b"shdr", "<20sIIIIIBbHH")
        self._cache = {}

    def preset_name(self, bank, prog):
        for i, p in enumerate(self.phdr[:-1]):
            if p[1] == prog and p[2] == bank:
                return p[0].split(b"\0")[0].decode("latin-1")
        return None

    def _zones(self, bags, gens, b0, b1):
        out = []
        for b in range(b0, b1):
            g0, g1 = bags[b][0], bags[b + 1][0]
            z = {}
            for g in range(g0, g1):
                op, amt = gens[g]
                z[op] = amt
            out.append(z)
        return out

    def regions(self, bank, prog):
        key = (bank, prog)
        if key in self._cache:
            return self._cache[key]
        pi = None
        for i, p in enumerate(self.phdr[:-1]):
            if p[1] == prog and p[2] == bank:
                pi = i
                break
        if pi is None:
            raise KeyError("preset %d:%d missing" % key)
        pz = self._zones(self.pbag, self.pgen, self.phdr[pi][3], self.phdr[pi + 1][3])
        pglob = {}
        if pz and 41 not in pz[0]:
            pglob, pz = pz[0], pz[1:]
        out = []
        for z in pz:
            if 41 not in z:
                continue
            pall = dict(pglob)
            pall.update(z)
            ii = z[41]
            iz = self._zones(self.ibag, self.igen, self.inst[ii][1], self.inst[ii + 1][1])
            iglob = {}
            if iz and 53 not in iz[0]:
                iglob, iz = iz[0], iz[1:]
            pk = rng(pall.get(43, 0x7F00))
            pv = rng(pall.get(44, 0x7F00))
            for zz in iz:
                if 53 not in zz:
                    continue
                iall = dict(iglob)
                iall.update(zz)
                ik = rng(iall.get(43, 0x7F00))
                iv = rng(iall.get(44, 0x7F00))
                klo, khi = max(pk[0], ik[0]), min(pk[1], ik[1])
                vlo, vhi = max(pv[0], iv[0]), min(pv[1], iv[1])
                if klo > khi or vlo > vhi:
                    continue
                g = dict(DEFAULTS)
                for k, v in iall.items():
                    if k in (41, 43, 44, 53):
                        continue
                    g[k] = s16(v)
                for k, v in pall.items():
                    if k in NOT_PRESET:
                        continue
                    g[k] = g.get(k, 0) + s16(v)
                out.append(Region(klo, khi, vlo, vhi, g, self.shdr[iall[53]]))
        self._cache[key] = out
        return out

    # ------------------------------------------------------------------ rendering
    def note(self, bank, prog, key, vel, dur, bend_cents=0.0, max_release=4.0, vel_curve=1.5):
        """Render one note -> stereo float32 array (n, 2). dur = seconds until note-off."""
        parts = []
        for r in self.regions(bank, prog):
            if r.klo <= key <= r.khi and r.vlo <= vel <= r.vhi:
                parts.append(self._voice(r, key, vel, dur, bend_cents, max_release, vel_curve))
        if not parts:
            return np.zeros((1, 2), np.float32)
        n = max(p.shape[0] for p in parts)
        out = np.zeros((n, 2), np.float32)
        for p in parts:
            out[:p.shape[0]] += p
        return out

    def _voice(self, r, key, vel, dur, bend_cents, max_release, vel_curve):
        g = r.g
        name, start, end, ls, le, rate, opitch, pcorr, link, stype = r.sh
        start += g[0] + 32768 * g[4]
        end += g[1] + 32768 * g[12]
        ls += g[2] + 32768 * g[45]
        le += g[3] + 32768 * g[50]
        root = g[58] if g[58] >= 0 else opitch
        if root > 127:
            root = 60
        cents = (key - root) * g[56] + g[51] * 100 + g[52] + pcorr + bend_cents
        ratio = 2.0 ** (cents / 1200.0) * rate / SR
        mode = g[54] & 3
        looping = mode in (1, 3) and le > ls + 2

        # envelope timing
        delay = tc(g[33])
        attack = tc(g[34])
        hold = tc(g[35] + (60 - key) * g[39])
        decay = tc(g[36] + (60 - key) * g[40])
        sus_cb = float(np.clip(g[37], 0, 1440))
        release = float(np.clip(tc(g[38]), 0.004, max_release))
        n_on = int(dur * SR)
        n = n_on + int(release * SR) + 1
        if not looping:
            n = min(n, int((end - start - 2) / max(ratio, 1e-6)) + 1)
        if n <= 2:
            return np.zeros((1, 2), np.float32)
        t = np.arange(n, dtype=np.float64) / SR

        # pitch modulation (vibrato LFO + mod LFO)
        pm = np.zeros(n)
        if g[6]:
            f = 8.176 * tc(g[24])
            d0 = tc(g[23])
            pm += g[6] * np.sin(2 * np.pi * f * np.maximum(t - d0, 0)) * (t > d0)
        if g[5]:
            f = 8.176 * tc(g[22])
            d0 = tc(g[21])
            pm += g[5] * np.sin(2 * np.pi * f * np.maximum(t - d0, 0)) * (t > d0)
        if pm.any():
            inc = ratio * np.power(2.0, pm / 1200.0)
            pos = start + np.concatenate(([0.0], np.cumsum(inc[:-1])))
        else:
            pos = start + np.arange(n) * ratio
        if looping:
            over = pos >= le
            pos[over] = ls + np.mod(pos[over] - ls, le - ls)
        else:
            pos = np.minimum(pos, end - 2)
        i0 = pos.astype(np.int64)
        fr = (pos - i0).astype(np.float32)
        s = self.smpl[i0] * (1.0 - fr) + self.smpl[i0 + 1] * fr

        # volume envelope in centibels of attenuation
        env = np.empty(n, np.float64)
        a0 = int(delay * SR)
        a1 = a0 + max(int(attack * SR), 1)
        h1 = a1 + int(hold * SR)
        d1 = h1 + max(int(decay * SR * sus_cb / 1440.0), 1)
        env[:] = 0.0
        idx = np.arange(n)
        lin = np.zeros(n)
        # attack: linear amplitude
        m = (idx >= a0) & (idx < a1)
        lin[m] = (idx[m] - a0) / max(a1 - a0, 1)
        lin[(idx >= a1)] = 1.0
        amp = lin.copy()
        # decay: dB-linear toward sustain
        m = (idx >= h1) & (idx < d1)
        cb = (idx[m] - h1) / max(d1 - h1, 1) * sus_cb
        amp[m] = 10 ** (-cb / 200.0)
        amp[idx >= d1] = 10 ** (-sus_cb / 200.0)
        # release from the level at note-off
        if n_on < n:
            lvl = amp[min(n_on, n - 1)] if n_on > 0 else 0.0
            lvl_cb = -200.0 * np.log10(max(lvl, 1e-6))
            rel_len = n - n_on
            k = np.arange(rel_len) / SR
            cbr = lvl_cb + (1440.0 / release) * k
            amp[n_on:] = 10 ** (-np.minimum(cbr, 1440.0) / 200.0)
        env = amp

        vg = (vel / 127.0) ** vel_curve
        att = 10 ** (-(g[48] * 0.4) / 200.0)
        s = s * (env * vg * att).astype(np.float32)

        # filter: static cutoff, mod envelope blended in for brightness sweeps
        fc = g[8] + (-1200.0 * (1.0 - vel / 127.0) if g[8] < 13500 else 0.0)
        q_db = max(g[9] / 10.0, 0.0)
        if g[11] > 0 and fc < 13000:
            menv = self._modenv(g, key, n, n_on)
            dark = self._lowpass(s, fc, q_db)
            bright = self._lowpass(s, fc + g[11], q_db)
            s = dark + (bright - dark) * menv.astype(np.float32)
        elif fc < 13000:
            s = self._lowpass(s, fc, q_db)

        # pan (equal power), -500..500
        p = float(np.clip(g[17], -500, 500)) / 500.0
        ang = (p + 1.0) * np.pi / 4.0
        out = np.empty((n, 2), np.float32)
        out[:, 0] = s * np.cos(ang)
        out[:, 1] = s * np.sin(ang)
        return out

    def _modenv(self, g, key, n, n_on):
        delay, attack = tc(g[25]), tc(g[26])
        hold = tc(g[27] + (60 - key) * g[31])
        decay = tc(g[28] + (60 - key) * g[32])
        sus = 1.0 - float(np.clip(g[29], 0, 1000)) / 1000.0
        release = tc(g[30])
        idx = np.arange(n) / SR
        e = np.zeros(n)
        a0, a1 = delay, delay + attack
        h1 = a1 + hold
        m = (idx >= a0) & (idx < a1)
        e[m] = (idx[m] - a0) / max(attack, 1e-4)
        e[idx >= a1] = 1.0
        m = idx >= h1
        e[m] = sus + (1.0 - sus) * np.exp(-(idx[m] - h1) / max(decay * 0.3, 1e-3))
        if n_on < n:
            lvl = e[min(n_on, n - 1)]
            k = idx[n_on:] - idx[n_on]
            e[n_on:] = lvl * np.exp(-k / max(release * 0.3, 1e-3))
        return e

    @staticmethod
    def _lowpass(x, fc_cents, q_db):
        f = 8.176 * 2.0 ** (fc_cents / 1200.0)
        f = min(f, SR * 0.45)
        if f >= SR * 0.449:
            return x
        q = max(10 ** (q_db / 20.0), 0.707)
        w = 2 * np.pi * f / SR
        alpha = np.sin(w) / (2 * q)
        cw = np.cos(w)
        b = np.array([(1 - cw) / 2, 1 - cw, (1 - cw) / 2])
        a = np.array([1 + alpha, -2 * cw, 1 - alpha])
        return lfilter(b / a[0], a / a[0], x).astype(np.float32)
