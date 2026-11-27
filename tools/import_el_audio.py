#!/usr/bin/env python3
"""Import ElevenLabs renders (sfx, voice barks) into the game.

Usage: import_el_audio.py <src_dir> [--dry]

<src_dir> holds the downloaded renders named <key>_<take>.mp3 (take 1-based), e.g.
bow_1.mp3, bow_2.mp3, vo_kael_1.mp3. For every sfx key the best take is chosen
(clean onset, least noise floor, sensible length), trimmed, faded and
loudness-matched to the sound it replaces; keys the game plays with variants
(bow, clash, sword, boom) keep several takes. Voice files hold one line per
"[long pause]" block and are cut at the silences into the per-line names the game
asks for (kael_select, ann_wave ...). Everything is written as Ogg Vorbis.
"""
import json, os, subprocess, sys
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_OUT = os.path.join(ROOT, "assets/audio/sfx")
VO_OUT = os.path.join(ROOT, "assets/audio/voice")
SR = 44100

# key -> (max length s, number of variants the game expects; 0 = single file)
SFX = {
    "bow": (0.9, 2), "magic": (1.4, 0), "cannon": (1.4, 0), "boom": (1.8, 2),
    "clash": (0.6, 3), "sword": (0.5, 3), "build": (1.6, 0), "coin": (0.9, 0),
    "meteor_cast": (2.2, 0), "boss_roar": (2.6, 0), "warcry": (2.0, 0),
    "die_small": (0.9, 0), "die_big": (1.4, 0), "click": (0.25, 0), "zap": (1.0, 0),
    "frost": (1.4, 0), "slam": (1.6, 0), "life_lost": (1.0, 0), "reinforce": (2.0, 0),
    "whirl": (1.6, 0), "fuse": (1.2, 0), "sell": (1.0, 0),
}
# orchestral stingers made for the score (make_music.py) stay; the EL takes are kept
# only if asked for with --stingers
STINGERS = {"upgrade": (1.4, 0), "horn": (2.4, 0), "victory": (4.5, 0), "defeat": (4.5, 0), "levelup": (2.0, 0)}

# (game line name, text) in the order the take speaks them; the text is only used to
# count syllables so the cuts land between lines, not inside an "잠깐... 쉬어야겠어..."
VOICE = {
    "vo_kael": [("kael_select", "명령을 내려라!"), ("kael_move", "바로 가겠다!"), ("kael_skill", "불꽃 검무다!"),
                ("kael_levelup", "더 강해졌다!"), ("kael_death", "아직... 끝나지 않았어..."), ("kael_respawn", "다시 싸운다!")],
    "vo_sera": [("sera_select", "별빛이 함께하길."), ("sera_move", "그쪽으로 갈게요!"), ("sera_skill", "별빛 폭풍!"),
                ("sera_levelup", "마력이 차오른다!"), ("sera_death", "잠깐... 쉬어야겠어..."), ("sera_respawn", "다시 돌아왔어요!")],
    "vo_ren": [("ren_select", "바람이 길을 알려줄 거야."), ("ren_move", "바람을 따라간다!"), ("ren_skill", "화살비다!"),
               ("ren_levelup", "활이 더 가벼워졌어."), ("ren_death", "여기까지인가..."), ("ren_respawn", "다시 활을 든다!")],
    # tower barks (build, upgrade, specialisation; barracks also when a rally point is set)
    "vo_archer": [("archer_build", "궁수대, 배치 완료!"), ("archer_up", "화살은 충분하다!"), ("archer_master", "바람보다 빠르게!")],
    "vo_barracks": [("barracks_build", "이 길은 못 지나간다!"), ("barracks_up", "방패를 들어라!"),
                    ("barracks_master", "왕국을 위하여!"), ("barracks_rally", "자리로 이동!")],
    "vo_mage": [("mage_build", "마력이 깨어난다..."), ("mage_up", "지식은 곧 힘이지."), ("mage_master", "비전의 힘을 보아라!")],
    "vo_artillery": [("artillery_build", "대포 설치 끝! 쏴 볼까?"), ("artillery_up", "더 큰 포탄으로!"), ("artillery_master", "펑! 하하하!")],
    "vo_announcer": [("ann_wave_first", "적이 몰려옵니다!"), ("ann_wave", "다음 웨이브!"), ("ann_final", "마지막 웨이브다! 버텨라!"),
                     ("ann_boss", "보스가 나타났다!"), ("ann_victory", "승리!"), ("ann_defeat", "성이 함락되었다..."),
                     ("ann_danger", "성문이 위험하다!")],
}


def load(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def save_ogg(x, path, q=5):
    x = np.clip(x, -1.0, 1.0).astype(np.float32)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", str(q), path], input=x.tobytes(), check=True)


def env_db(x, win=0.01):
    n = max(1, int(SR * win))
    m = len(x) // n
    if m == 0:
        return np.array([-120.0])
    fr = x[: m * n].reshape(m, n)
    return 20 * np.log10(np.sqrt((fr ** 2).mean(axis=1)) + 1e-9)


def rms_db(x):
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)


def trim(x, max_len, thresh=-64.0, rel=42.0):
    """Drop leading/trailing silence (rel dB under the peak, never below thresh),
    cap the length, fade the tail."""
    e = env_db(x)
    on = np.where(e > max(thresh, e.max() - rel))[0]
    if len(on) == 0:
        return x[:0]
    n = int(SR * 0.01)
    a = max(0, on[0] * n - int(SR * 0.004))
    b = min(len(x), (on[-1] + 1) * n + int(SR * 0.03))
    y = x[a:b]
    y = y[: int(SR * max_len)]
    fo = min(len(y) // 3, int(SR * 0.08))
    if fo > 0:
        y[-fo:] *= np.linspace(1.0, 0.0, fo) ** 2
    fi = min(len(y), int(SR * 0.002))
    y[:fi] *= np.linspace(0.0, 1.0, fi)
    return y


def score(y, max_len):
    """Higher is better: punchy onset, quiet floor, not truncated, not tiny."""
    if len(y) < SR * 0.05:
        return -1e9
    e = env_db(y)
    peak_t = int(np.argmax(e)) * 0.01
    floor = np.percentile(e, 10)
    dyn = e.max() - floor
    trunc = 1.0 if len(y) >= SR * max_len * 0.98 else 0.0
    return dyn - 6.0 * peak_t - 8.0 * trunc


def match_loudness(y, ref_path, default_db=-16.0):
    target = default_db
    if ref_path and os.path.exists(ref_path):
        try:
            r = load(ref_path)
            target = rms_db(r[np.abs(r) > 1e-4]) if np.any(np.abs(r) > 1e-4) else default_db
        except subprocess.CalledProcessError:
            pass
    act = y[np.abs(y) > 1e-4]
    g = 10 ** ((target - rms_db(act if len(act) else y)) / 20)
    y = y * g
    pk = np.abs(y).max() + 1e-9
    return y * (0.95 / pk) if pk > 0.95 else y


def existing(key):
    for ext in (".ogg", ".wav", ".mp3"):
        for nm in (key, key + "_1"):
            p = os.path.join(SFX_OUT, nm + ext)
            if os.path.exists(p):
                return p
    return None


def takes(src, key):
    out = []
    k = 1
    while os.path.exists(os.path.join(src, f"{key}_{k}.mp3")):
        out.append(os.path.join(src, f"{key}_{k}.mp3"))
        k += 1
    return out


def syllables(text):
    return max(1, sum(1 for c in text if "\uac00" <= c <= "\ud7a3"))


def split_lines(x, texts):
    """Cut a multi-line take between its lines. Voiced runs are found on the level
    envelope; of all ways to place len(texts)-1 cuts in the silences, the one whose
    pieces best match each line's syllable count (and that prefers long silences) wins.
    Returns (pieces, cost) or None."""
    import itertools
    hop = 0.02
    e = env_db(x, hop)
    voiced = e > (e.max() - 38.0)
    runs = []
    i = 0
    while i < len(voiced):
        if voiced[i]:
            j = i
            while j < len(voiced) and voiced[j]:
                j += 1
            if runs and (i - runs[-1][1]) * hop < 0.12:
                runs[-1][1] = j
            else:
                runs.append([i, j])
            i = j
        else:
            i += 1
    runs = [r for r in runs if (r[1] - r[0]) * hop >= 0.06]
    n = len(texts)
    if len(runs) < n:
        return None
    syl = [syllables(t) for t in texts]
    gaps = [(runs[k + 1][0] - runs[k][1]) * hop for k in range(len(runs) - 1)]
    best = None
    for cuts in itertools.combinations(range(len(gaps)), n - 1):
        bounds = [0] + [c + 1 for c in cuts] + [len(runs)]
        durs = [(runs[bounds[k + 1] - 1][1] - runs[bounds[k]][0]) * hop for k in range(n)]
        rate = sum(durs) / sum(syl)
        fit = sum(((d - rate * s_) / (rate * s_ + 0.25)) ** 2 for d, s_ in zip(durs, syl))
        sil = sum(np.log(gaps[c] + 0.05) for c in cuts)
        cost = fit - 0.6 * sil
        if best is None or cost < best[0]:
            best = (cost, bounds)
    cost, bounds = best
    m = int(SR * hop)
    pieces = []
    for k in range(n):
        a = runs[bounds[k]][0]
        b = runs[bounds[k + 1] - 1][1]
        lo = (runs[bounds[k] - 1][1] + a) // 2 if bounds[k] > 0 else 0
        hi = (b + runs[bounds[k + 1]][0]) // 2 if bounds[k + 1] < len(runs) else len(voiced)
        pieces.append(x[lo * m: hi * m])
    return pieces, cost


def main():
    src = sys.argv[1]
    dry = "--dry" in sys.argv
    report = {}
    table = dict(SFX)
    if "--stingers" in sys.argv:
        table.update(STINGERS)
    os.makedirs(VO_OUT, exist_ok=True)
    for key, (max_len, nvar) in table.items():
        cands = []
        for p in takes(src, key):
            y = trim(load(p), max_len)
            cands.append((score(y, max_len), p, y))
        if not cands:
            continue
        cands.sort(key=lambda c: -c[0])
        ref = existing(key)
        names = [f"{key}_{k + 1}" for k in range(nvar)] if nvar else [key]
        picks = [cands[k % len(cands)] for k in range(len(names))]
        for nm, (sc, p, y) in zip(names, picks):
            y = match_loudness(y, ref)
            report[nm] = {"from": os.path.basename(p), "len": round(len(y) / SR, 2), "score": round(float(sc), 1)}
            if not dry:
                for ext in (".wav", ".mp3", ".ogg"):
                    old = os.path.join(SFX_OUT, nm + ext)
                    if os.path.exists(old):
                        os.remove(old)
                        if os.path.exists(old + ".import"):
                            os.remove(old + ".import")
                save_ogg(y, os.path.join(SFX_OUT, nm + ".ogg"))
    for key, lines in VOICE.items():
        best = None
        for p in takes(src, key):
            r = split_lines(load(p), [t for _, t in lines])
            if r is None:
                continue
            if best is None or r[1] < best[0]:
                best = (r[1], p, r[0])
        if best is None:
            if takes(src, key):
                report[key] = "could not split"
            continue
        for (nm, _), q in zip(lines, best[2]):
            y = trim(q, 6.0, -60.0, 40.0)
            y = match_loudness(y, None, -15.0)
            report[nm] = {"from": os.path.basename(best[1]), "len": round(len(y) / SR, 2)}
            if not dry:
                save_ogg(y, os.path.join(VO_OUT, nm + ".ogg"), 4)
    print(json.dumps(report, indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
