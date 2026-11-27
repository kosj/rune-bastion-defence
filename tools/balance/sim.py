#!/usr/bin/env python3
"""AI 플레이 시뮬레이션: 레벨 x 실력(expert/casual) x 난이도 x 시드를 헤드리스로 돌려 결과를 모읍니다.

사용:
  python3 tools/balance/sim.py [--levels 0-9] [--skills expert,casual] [--diffs 0] [--seeds 4] [--jobs 2] [--out sim.json]

헤드리스 + --fixed-fps 60으로 돌려서 한 판이 몇 초면 끝납니다(실시간 x5 배속과 같은 프레임 간격).
각 판은 test_runner의 smart AI가 합니다. casual은 첫 플레이어 흉내(느린 반응, 반쯤 무작위 타워,
조기 호출 없음)입니다. 출력:
  - 레벨마다 승률, 평균 남은 생명, 별 분포
  - 웨이브마다 평균 생명 손실(어느 웨이브가 고비인지)과 웨이브 호출 때의 남은 골드(여유)
"""
import argparse, json, os, re, subprocess, sys, statistics as st
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GODOT = os.environ.get("GODOT", "godot")


def parse_range(s):
    out = []
    for part in s.split(","):
        if "-" in part:
            a, b = part.split("-")
            out += list(range(int(a), int(b) + 1))
        elif part:
            out.append(int(part))
    return out


def run_one(level, skill, diff, seed, extra):
    cmd = [GODOT, "--headless", "--path", ROOT, "--fixed-fps", "60", "res://scenes/test_runner.tscn", "--",
           "level=%d" % level, "mode=smart", "diff=%d" % diff, "speed=5", "max_t=900", "seed=%d" % seed,
           "skill=%s" % skill] + extra
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        txt = p.stdout + p.stderr
    except subprocess.TimeoutExpired as e:
        txt = (e.stdout or b"").decode() if isinstance(e.stdout, bytes) else (e.stdout or "")
    waves = []
    for m in re.finditer(r"^WAVE (\d+) lives=(-?\d+) gold=(\d+) invested=(\d+) towers=(\d+)", txt, re.M):
        waves.append({"w": int(m.group(1)), "lives": int(m.group(2)), "gold": int(m.group(3)),
                      "invested": int(m.group(4)), "towers": int(m.group(5))})
    m = re.search(r"^RESULT (\w+) wave=(\d+)/(\d+) lives=(-?\d+)/(\d+)", txt, re.M)
    errors = len(re.findall(r"SCRIPT ERROR", txt))
    err_txt = ""
    if errors:
        i = txt.find("SCRIPT ERROR")
        err_txt = txt[max(0, i - 200): i + 600]
    if not m:
        return {"level": level, "skill": skill, "diff": diff, "seed": seed, "result": "none", "errors": errors, "err": err_txt, "waves": waves}
    return {"level": level, "skill": skill, "diff": diff, "seed": seed, "result": m.group(1), "wave": int(m.group(2)),
            "nwaves": int(m.group(3)), "lives": max(int(m.group(4)), 0), "max_lives": int(m.group(5)),
            "errors": errors, "err": err_txt, "waves": waves}


def stars(r):
    if r["result"] != "won":
        return 0
    ml = r["max_lives"]
    return 3 if r["lives"] >= ml - 2 else (2 if r["lives"] >= ml // 2 else 1)


def summarise(runs):
    groups = {}
    for r in runs:
        groups.setdefault((r["skill"], r["diff"], r["level"]), []).append(r)
    rows = []
    for (skill, diff, level), rs in sorted(groups.items()):
        n = len(rs)
        won = [r for r in rs if r["result"] == "won"]
        nw = max((r.get("nwaves", 0) for r in rs), default=0)
        # lives lost per wave (lives when wave w is called minus lives when wave w+1 is called / at the end)
        loss = [[] for _ in range(nw)]
        bank = [[] for _ in range(nw)]
        for r in rs:
            ws = {w["w"]: w for w in r["waves"]}
            for w in range(1, nw + 1):
                if w not in ws:
                    continue
                nxt = ws.get(w + 1, {}).get("lives", r.get("lives", 0) if r["result"] != "none" else None)
                if nxt is None:
                    continue
                loss[w - 1].append(ws[w]["lives"] - nxt)
                bank[w - 1].append(ws[w]["gold"])
        rows.append({
            "skill": skill, "diff": diff, "level": level, "runs": n, "win": len(won) / n,
            "lives": st.mean([r.get("lives", 0) if r["result"] == "won" else 0 for r in rs]),
            "max_lives": rs[0].get("max_lives", 20),
            "stars": [sum(1 for r in rs if stars(r) == s) for s in (0, 1, 2, 3)],
            "reached": st.mean([r.get("wave", 0) for r in rs]), "nwaves": nw,
            "loss": [round(st.mean(x), 2) if x else None for x in loss],
            "bank": [round(st.mean(x)) if x else None for x in bank],
            "errors": sum(r["errors"] for r in rs),
        })
    return rows


def print_rows(rows):
    for r in rows:
        print("%-6s 난이도%d L%-2d 승률 %3d%%  생명 %4.1f/%d  별[0,1,2,3]=%s  도달 %.1f/%d%s" % (
            r["skill"], r["diff"], r["level"] + 1, round(r["win"] * 100), r["lives"], r["max_lives"], r["stars"],
            r["reached"], r["nwaves"], "  스크립트 오류 %d" % r["errors"] if r["errors"] else ""))
        print("        웨이브별 생명 손실: " + " ".join("-" if v is None else ("%.1f" % v if v else ".") for v in r["loss"]))
        print("        호출 때 남은 골드:  " + " ".join("-" if v is None else str(v) for v in r["bank"]))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--levels", default="0-9")
    ap.add_argument("--skills", default="expert,casual")
    ap.add_argument("--diffs", default="0")
    ap.add_argument("--seeds", type=int, default=4)
    ap.add_argument("--seed0", type=int, default=1)
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    ap.add_argument("--out", default="")
    ap.add_argument("--extra", default="", help="test_runner에 더 넘길 인자(공백 구분)")
    a = ap.parse_args()
    jobs = []
    for skill in a.skills.split(","):
        for diff in parse_range(a.diffs):
            for level in parse_range(a.levels):
                for s in range(a.seed0, a.seed0 + a.seeds):
                    jobs.append((level, skill, diff, s))
    extra = a.extra.split() if a.extra else []
    with ThreadPoolExecutor(a.jobs) as ex:
        runs = list(ex.map(lambda j: run_one(*j, extra), jobs))
    rows = summarise(runs)
    print_rows(rows)
    if a.out:
        json.dump({"runs": runs, "rows": rows}, open(a.out, "w"), ensure_ascii=False, indent=1)
    if any(r["errors"] for r in rows):
        sys.exit(2)
