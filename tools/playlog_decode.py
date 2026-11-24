#!/usr/bin/env python3
"""Decode a Rune Bastion play-log code (Settings > 플레이 기록 보내기) into a readable report.

    python3 tools/playlog_decode.py RBP1-xxxxxx-....      (or pipe the code on stdin)
"""
import base64, gzip, hashlib, json, sys

LEVELS = ["초록 들판", "쌍둥이 여울", "서리바람 고개", "그림자 숲", "트롤 협곡", "검은 성채", "통곡의 폭포", "망자의 신전"]


def decode(code):
    code = "".join(code.split())
    tag, md5, body = code.split("-", 2)
    if tag != "RBP1":
        raise ValueError("not a play-log code")
    if hashlib.md5(body.encode()).hexdigest()[:6] != md5:
        raise ValueError("code damaged (checksum mismatch)")
    return json.loads(gzip.decompress(base64.b64decode(body)).decode("utf-8"))


def main():
    code = sys.argv[1] if len(sys.argv) > 1 else sys.stdin.read()
    data = decode(code)
    runs = data["runs"]
    print(f"{len(runs)} runs (lang {data.get('lang')})")
    for r in runs:
        lv = r.get("lv", 0)
        name = "무한" if r.get("e") else LEVELS[lv] if lv < len(LEVELS) else str(lv)
        diff = "영웅" if r.get("d") == 1 else "보통"
        print(f"- L{lv + 1} {name} [{diff}] {r.get('r')} stars={r.get('s', 0)} wave {r.get('wv')}/{r.get('nw')} "
              f"lives {r.get('li')}/{r.get('ml')} time {r.get('t')}s kills {r.get('k')} spells {r.get('sp')} hero {r.get('h')} Lv{r.get('hl')}")
        if r.get("lw"):
            print("    lives lost by wave:", r["lw"], " leaked:", r.get("lt"))
        print("    towers:", " ".join(r.get("tw", [])))


if __name__ == "__main__":
    main()
