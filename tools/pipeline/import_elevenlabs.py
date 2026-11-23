"""Convert downloaded ElevenLabs generations into game-ready audio.

usage: python3 import_elevenlabs.py <download_dir> <project_dir>

<download_dir> holds files named <key>_<n>.mp3 (n = take index, 1-based), where key is
an SFX name (bow, magic, ...), music_<name>, or vo_<speaker>.
 - SFX: silence-trimmed, peak-normalised, mono OGG.  Keys listed in VARIANTS keep several
   takes as <key>_1.ogg.. so the game can randomise them; others keep take 1.
 - Music: take 1, stereo OGG with short fades so the loop point does not click.
 - Voice: each take-1 file is split on silences into the lines listed in VOICE_LINES.
"""
import os
import re
import subprocess
import sys

SRC, PROJ = sys.argv[1], sys.argv[2]
SFX_DIR = os.path.join(PROJ, "assets/audio/sfx")
MUSIC_DIR = os.path.join(PROJ, "assets/audio/music")
VOICE_DIR = os.path.join(PROJ, "assets/audio/voice")
os.makedirs(VOICE_DIR, exist_ok=True)

VARIANTS = {"bow": 4, "clash": 4, "sword": 4, "boom": 3, "die_small": 3, "die_big": 2, "magic": 2, "coin": 2}
VOICE_LINES = {
    "vo_kael": ["kael_select", "kael_move", "kael_skill", "kael_levelup", "kael_death", "kael_respawn"],
    "vo_sera": ["sera_select", "sera_move", "sera_skill", "sera_levelup", "sera_death", "sera_respawn"],
    "vo_announcer": ["ann_wave_first", "ann_wave", "ann_final", "ann_boss", "ann_victory", "ann_defeat", "ann_danger"],
}
TRIM = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse," \
       "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse"


def run(args):
    return subprocess.run(args, capture_output=True, text=True)


def duration(path):
    r = run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path])
    return float(r.stdout.strip() or 0)


def to_ogg(src, dst, mono=True, extra="", quality=4, rate=44100):
    filt = TRIM + (("," + extra) if extra else "")
    tmp = dst + ".tmp.wav"
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af", filt, "-ac", "1" if mono else "2", "-ar", str(rate), tmp])
    # peak-normalise to -1 dBFS
    vol = run(["ffmpeg", "-i", tmp, "-af", "volumedetect", "-f", "null", "-"]).stderr
    m = re.search(r"max_volume: (-?[\d.]+) dB", vol)
    gain = (-1.0 - float(m.group(1))) if m else 0.0
    run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", "volume=%.2fdB" % gain,
         "-c:a", "libvorbis", "-q:a", str(quality), dst])
    os.remove(tmp)


files = {}
for f in sorted(os.listdir(SRC)):
    m = re.match(r"(.+)_(\d+)\.mp3$", f)
    if m:
        files.setdefault(m.group(1), {})[int(m.group(2))] = os.path.join(SRC, f)

for key, takes in files.items():
    if key.startswith("music_"):
        name = key[6:]
        src = takes[min(takes)]
        d = duration(src)
        out = os.path.join(MUSIC_DIR, name + ".ogg")
        run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-af",
             "afade=t=in:d=0.3,afade=t=out:st=%.2f:d=1.2" % max(d - 1.2, 0), "-ac", "2", "-ar", "44100",
             "-c:a", "libvorbis", "-q:a", "3", out])
        print("music", name, round(d, 1), "s")
    elif key.startswith("vo_"):
        src = takes[min(takes)]
        names = VOICE_LINES.get(key, [])
        det = run(["ffmpeg", "-i", src, "-af", "silencedetect=noise=-38dB:d=0.4", "-f", "null", "-"]).stderr
        starts = [float(x) for x in re.findall(r"silence_start: ([\d.]+)", det)]
        ends = [float(x) for x in re.findall(r"silence_end: ([\d.]+)", det)]
        total = duration(src)
        # speech segments are the gaps between silences
        segs = []
        cur = 0.0
        for s, e in zip(starts, ends + [total] * (len(starts) - len(ends))):
            if s - cur > 0.25:
                segs.append((cur, s))
            cur = e
        if total - cur > 0.25:
            segs.append((cur, total))
        print(key, "segments", len(segs), "expected", len(names))
        for i, (a, b) in enumerate(segs[:len(names)]):
            tmp = os.path.join(SRC, "%s_seg%d.wav" % (key, i))
            run(["ffmpeg", "-y", "-loglevel", "error", "-i", src, "-ss", "%.3f" % max(a - 0.05, 0),
                 "-to", "%.3f" % (b + 0.12), tmp])
            to_ogg(tmp, os.path.join(VOICE_DIR, names[i] + ".ogg"), quality=3)
    else:
        n = VARIANTS.get(key, 1)
        idx = sorted(takes)[:n]
        for j, t in enumerate(idx):
            out = os.path.join(SFX_DIR, ("%s_%d.ogg" % (key, j + 1)) if n > 1 else key + ".ogg")
            to_ogg(takes[t], out, rate=44100)
        # the synthesized placeholder of the same name is no longer needed
        for old in os.listdir(SFX_DIR):
            if re.match(r"%s(_\d+)?\.wav(\.import)?$" % re.escape(key), old):
                os.remove(os.path.join(SFX_DIR, old))
        print("sfx", key, "takes", len(idx))
