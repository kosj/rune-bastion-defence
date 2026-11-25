"""Split an exported Godot pack into download chunks (scripts/data/pack_chunks.gd).
Usage: split_pck.py <exported.pck> [--manifest scripts/data/pack_chunks.gd]

<name>.pck is rewritten as the core chunk; every other chunk is written as <name>_<chunk>.pck.
The page downloads them in the manifest's order (core first: the title screen needs only core)
and the game mounts each one with ProjectSettings.load_resource_pack() as it arrives
(scripts/autoload/content.gd).

Chunks are chosen per source file: a `.import` remap goes to the chunk its source path matches,
together with the imported files it points at. Everything else (scripts, scenes, project data)
stays in core. The script refuses to write the packs when a file refers by path to an asset of a
later chunk (it would fail to load before that chunk is mounted). The pack layout (header,
16-byte data alignment, directory at the end) is copied from the input, so the output matches
what this Godot version writes."""
import fnmatch
import json
import os
import re
import struct
import sys

# files that may name assets of any chunk: compiled scripts build paths at run time, the UID
# cache and the class cache list every file of the project
NAME_OK = re.compile(r"(\.gdc|\.gd|uid_cache\.bin|global_script_class_cache\.cfg|\.import|\.remap|project\.binary)$")


def load_manifest(path):
    src = open(path, encoding="utf-8").read()
    a = src.index("# CHUNKS-JSON-BEGIN")
    b = src.index("# CHUNKS-JSON-END")
    body = "\n".join(l for l in src[a:b].splitlines() if not l.strip().startswith("#"))
    return json.loads("{" + body + "}")


def chunk_of(src, man):
    for c in man["match"]:
        for pat in man["chunks"][c]:
            if fnmatch.fnmatchcase(src, pat):
                return c
    return "core"


def read_pack(path):
    d = open(path, "rb").read()
    assert d[:4] == b"GDPC", "not a Godot pack"
    ver, = struct.unpack_from("<I", d, 4)
    assert ver >= 3, "pack format %d not supported" % ver
    base, diroff = struct.unpack_from("<QQ", d, 24)
    off = diroff  # the directory offset is absolute; file offsets are relative to the data base
    n, = struct.unpack_from("<I", d, off)
    off += 4
    entries = []
    for _ in range(n):
        L, = struct.unpack_from("<I", d, off)
        off += 4
        p = d[off:off + L].rstrip(b"\0").decode()
        off += L
        o, s = struct.unpack_from("<QQ", d, off)
        off += 16
        md5 = d[off:off + 16]
        off += 16
        fl, = struct.unpack_from("<I", d, off)
        off += 4
        entries.append({"path": p, "data": d[base + o:base + o + s], "md5": md5, "flags": fl})
    return d[:base], entries


def texture_gaps(a_path, b_path):
    """Textures (.png/.jpg imports) in pack A that pack B lacks. The phone pack is the same project
    with ETC2 textures and phone meshes swapped in, so it must have every texture the desktop pack
    has; a swapped-in model whose maps were not re-extracted shows up here (and untextured in game)."""
    def tex(path):
        return {e["path"] for e in read_pack(path)[1] if re.search(r"\.(png|jpg|jpeg|webp)\.import$", e["path"])}
    return sorted(tex(a_path) - tex(b_path))


def write_pack(path, header, entries):
    base = len(header)
    blob = bytearray()
    dirent = bytearray()
    for e in entries:
        while len(blob) % 16:
            blob.append(0)
        o = len(blob)
        blob += e["data"]
        pb = e["path"].encode()
        pb += b"\0" * ((4 - len(pb) % 4) % 4)
        dirent += struct.pack("<I", len(pb)) + pb + struct.pack("<QQ", o, len(e["data"])) + e["md5"] + struct.pack("<I", e["flags"])
    while len(blob) % 16:
        blob.append(0)
    diroff = len(blob)
    h = bytearray(header)
    struct.pack_into("<Q", h, 32, base + diroff)
    with open(path, "wb") as f:
        f.write(h)
        f.write(blob)
        f.write(struct.pack("<I", len(entries)))
        f.write(dirent)


def main():
    if sys.argv[1] == "--texture-gaps":
        # split_pck.py --texture-gaps <desktop.pck> <mobile.pck>: run before splitting
        gaps = texture_gaps(sys.argv[2], sys.argv[3])
        if gaps:
            sys.exit("split_pck: %s lacks textures of %s:\n  " % (sys.argv[3], sys.argv[2]) + "\n  ".join(gaps[:40]))
        print("texture sets match:", sys.argv[2], sys.argv[3])
        return
    src = sys.argv[1]
    here = os.path.dirname(os.path.abspath(__file__))
    man_path = os.path.join(here, "..", "scripts", "data", "pack_chunks.gd")
    if "--manifest" in sys.argv:
        man_path = sys.argv[sys.argv.index("--manifest") + 1]
    man = load_manifest(man_path)
    order = man["order"]
    header, entries = read_pack(src)
    by_path = {e["path"]: e for e in entries}
    owner = {}       # pack path -> chunk
    names = {c: set() for c in order}  # chunk -> source file names (for the reference check)
    for e in entries:
        p = e["path"]
        if not p.endswith(".import"):
            continue
        source = p[:-len(".import")]
        c = chunk_of(source, man)
        if c == "core":
            continue
        owner[p] = c
        names[c].add(os.path.basename(source))
        for m in re.finditer(r'^path(?:\.\w+)?="res://([^"]+)"', e["data"].decode("utf-8", "replace"), re.M):
            if m.group(1) in by_path:
                owner[m.group(1)] = c
    # a file of chunk A must not name an asset of a later chunk
    rank = {c: i for i, c in enumerate(order)}
    bad = []
    for e in entries:
        if NAME_OK.search(e["path"]):
            continue
        c = owner.get(e["path"], "core")
        later = [n for k in order[rank[c] + 1:] for n in names[k]]
        if not later:
            continue
        m = re.search("|".join(re.escape(n) for n in sorted(later, key=len, reverse=True)).encode(), e["data"])
        if m:
            bad.append("%s (%s) -> %s" % (e["path"], c, m.group(0).decode()))
    if bad:
        sys.exit("split_pck: files refer to assets of a later chunk:\n  " + "\n  ".join(bad))
    stem = src[:-4]
    legacy = stem + "_content.pck"
    if os.path.exists(legacy):
        os.remove(legacy)
    out = []
    over = []
    for c in order:
        part = [e for e in entries if owner.get(e["path"], "core") == c]
        if c != "core" and not part:
            continue
        path = src if c == "core" else "%s_%s.pck" % (stem, c)
        write_pack(path, header, part)
        mb = sum(len(e["data"]) for e in part) / 1e6
        out.append("%s %d files %.1f MB" % (c, len(part), mb))
        cap = man.get("budget_mb", {}).get(c)
        if cap and mb > cap:
            over.append("%s %.1f MB > %.1f MB" % (c, mb, cap))
    print("split %s: %s" % (os.path.basename(src), ", ".join(out)))
    if over:
        # the budgets guard the first-visit load (title = core, first battle = core+menu+stage1)
        sys.exit("split_pck: chunk over budget (scripts/data/pack_chunks.gd budget_mb): " + "; ".join(over))


if __name__ == "__main__":
    main()
