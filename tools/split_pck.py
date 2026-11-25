"""Split an exported Godot pack into a small core pack and a streamed content pack.
Usage: split_pck.py <exported.pck> [--content-out <path>]

The core pack (written back over <exported.pck>) holds everything the title screen, the world map
and the menus need: scripts, scenes, UI art, fonts, sound effects, voice lines, the menu music and
the pre-rendered title backdrops. The content pack (<name>_content.pck) holds the 3D models and
characters (their imported scenes and textures) and the battle music: the bulk of the download.
The web shell fetches it right after the core pack while the title screen is already up, and the
game mounts it with ProjectSettings.load_resource_pack() (scripts/autoload/content.gd).

Content is chosen per source file: every `.import` remap under the content folders goes to the
content pack together with the imported files it points at. The script refuses to write the packs
if a core scene or resource refers to content by path (it would fail to load before the mount).
The pack layout (header, 16-byte data alignment, directory at the end) is copied from the input,
so the output matches what this Godot version writes."""
import os
import re
import struct
import sys

CONTENT_PREFIXES = (
    "assets/models/",
    "assets/characters/",
    "assets/audio/music/battle",   # battle.ogg, battle_dark.ogg
    "assets/audio/music/boss",
)
# core files that may name content paths: compiled scripts build the paths at run time, the UID
# cache and the class cache list every file of the project
NAME_OK = re.compile(r"(\.gdc|\.gd|uid_cache\.bin|global_script_class_cache\.cfg|\.import|\.remap|project\.binary)$")


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
    src = sys.argv[1]
    out_content = src[:-4] + "_content.pck"
    if "--content-out" in sys.argv:
        out_content = sys.argv[sys.argv.index("--content-out") + 1]
    header, entries = read_pack(src)
    by_path = {e["path"]: e for e in entries}
    content = set()
    for e in entries:
        p = e["path"]
        if p.endswith(".import") and p.startswith(CONTENT_PREFIXES):
            content.add(p)
            for m in re.finditer(r'^path(?:\.\w+)?="res://([^"]+)"', e["data"].decode("utf-8", "replace"), re.M):
                if m.group(1) in by_path:
                    content.add(m.group(1))
    if not content:
        sys.exit("split_pck: no content found in " + src)
    # content source names (castle.glb, castle_albedo.png, battle.ogg ...) for the reference check
    names = sorted({os.path.basename(p)[:-len(".import")] for p in content if p.endswith(".import")})
    pat = re.compile("|".join(re.escape(n) for n in names).encode())
    bad = []
    for e in entries:
        if e["path"] in content or NAME_OK.search(e["path"]):
            continue
        m = pat.search(e["data"])
        if m:
            bad.append("%s -> %s" % (e["path"], m.group(0).decode()))
    if bad:
        sys.exit("split_pck: core files refer to streamed content:\n  " + "\n  ".join(bad))
    core_e = [e for e in entries if e["path"] not in content]
    cont_e = [e for e in entries if e["path"] in content]
    write_pack(out_content, header, cont_e)
    write_pack(src, header, core_e)
    cs = sum(len(e["data"]) for e in core_e)
    ns = sum(len(e["data"]) for e in cont_e)
    print("split %s: core %d files %.1f MB, content %d files %.1f MB -> %s" % (
        os.path.basename(src), len(core_e), cs / 1e6, len(cont_e), ns / 1e6, os.path.basename(out_content)))


main()
