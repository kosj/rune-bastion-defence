"""List every Korean string literal in the GDScript sources (the source language), with the files
that use it, and report which ones are still missing from the English table (scripts/i18n/lang_en.gd).
usage: python3 tools/i18n_extract.py [--missing] [--json out.json]"""
import glob
import json
import re
import sys

HANGUL = re.compile(r"[가-힣]")
LIT = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def literals():
    found = {}
    for f in sorted(glob.glob("scripts/**/*.gd", recursive=True)):
        if "/tools/" in f or f.endswith("lang_en.gd"):
            continue
        for ln, line in enumerate(open(f, encoding="utf-8"), 1):
            code = line.split("#")[0] if line.lstrip().startswith("#") else line
            for m in LIT.finditer(code):
                s = m.group(1)
                if HANGUL.search(s):
                    found.setdefault(s, []).append("%s:%d" % (f, ln))
    return found


def table():
    src = open("scripts/i18n/lang_en.gd", encoding="utf-8").read()
    keys = set()
    for m in re.finditer(r'^\s*"((?:[^"\\]|\\.)*)"\s*:', src, re.M):
        keys.add(m.group(1))
    return keys


if __name__ == "__main__":
    found = literals()
    keys = table()
    miss = [s for s in found if s not in keys]
    if "--json" in sys.argv:
        json.dump(found, open(sys.argv[sys.argv.index("--json") + 1], "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    if "--missing" in sys.argv:
        for s in miss:
            print(json.dumps(s, ensure_ascii=False), "  #", found[s][0])
    print("strings:", len(found), "translated:", len(found) - len(miss), "missing:", len(miss), file=sys.stderr)
