#!/usr/bin/env python3
"""밸런스 곡선 분석: 레벨마다 웨이브의 위협(유효 체력)과 경제(골드)를 곡선으로 봅니다.

사용:
  godot --headless --path . res://scenes/test_runner.tscn -- curve=1 | grep -E '^(CURVE|ENEMIES|TOWERS)' > /tmp/curve.jsonl
  python3 tools/balance/curve.py /tmp/curve.jsonl [--png 그림.png [--before 전.jsonl]]

보는 값(docs/BALANCE.md):
  - 위협: 유효 체력(방어력·마법 저항을 물리·마법 반반 기준으로 반영) x 속도 배수 x 특수 능력 x 공중 배수의 합(보스 제외)
  - 성장률 g: 레벨 안에서 EHP가 웨이브마다 몇 %씩 느는지(로그 회귀)
  - 긴장도 R = EHP / (그 웨이브 전까지 쓸 수 있는 골드). 1골드어치 방어가 이번 웨이브에서 잡아야 할 체력
  - 현상금 법칙: 적 처치 골드 ≈ k x HP^0.75 (Kingdom Rush 수치에서 맞춘 지수)
곡선을 따르는지의 검사는 shape_waves.py --check(tools/check_balance.sh)가 합니다.
"""
import json, math, sys

BOUNTY_EXP = 0.75


def load(path):
    levels, enemies, towers = [], {}, {}
    for line in open(path, encoding="utf-8"):
        tag, _, js = line.partition(" ")
        if tag == "CURVE":
            levels.append(json.loads(js))
        elif tag == "ENEMIES":
            enemies = json.loads(js)
        elif tag == "TOWERS":
            towers = json.loads(js)
    return levels, enemies, towers


def fit_growth(vals):
    """log(v) = a + b*w 최소제곱. 성장률 e^b - 1과 각 웨이브의 추세 대비 비율(톱니)."""
    n = len(vals)
    xs = list(range(n))
    ys = [math.log(max(v, 1e-6)) for v in vals]
    mx, my = sum(xs) / n, sum(ys) / n
    b = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / max(sum((x - mx) ** 2 for x in xs), 1e-9)
    a = my - b * mx
    resid = [math.exp(y - (a + b * x)) for x, y in zip(xs, ys)]
    return math.exp(b) - 1.0, resid


SPEED_REF = 2.0   # 고블린 근처의 보통 속도
SPEED_EXP = 0.5   # 빠를수록 사거리 안에 짧게 머묾(느린 대형 적도 병사를 묶어 두므로 지수는 1보다 작게)
AIR_MULT = 1.5    # 공중 적은 궁수·마법사만 칠 수 있어 필요한 화력이 그만큼 큼
# 특수 능력: 병사 기절(내려찍기), 주변 가속(함성), 치유, 자폭, 소환은 체력 이상으로 위험함
MECH_MULT = {"slam": 1.3, "warcry": 1.2, "heal": 1.2, "explode": 1.2, "summon": 1.0,
             "stealth": 1.3, "aura": 1.3, "ranged": 1.15}


def threat(types, enemies, hp_mult):
    """웨이브의 위협 = 각 적의 유효 체력 x 속도 배수 x 공중 배수의 합.
    필요한 초당 피해(DPS)는 체력 x 속도에 비례합니다(빠른 적은 사거리 안에 짧게 머묾)."""
    t = 0.0
    for k, c in types.items():
        e = enemies[k]
        hp = e["hp"] * hp_mult * (1.5 if e.get("revive") else 1.0)
        f = 1.0 / (0.5 * (1.0 - e["armor"]) + 0.5 * (1.0 - max(e["mr"], -0.5)))
        sp = (e["speed"] / SPEED_REF) ** SPEED_EXP
        mech = 1.0
        for m in e.get("mech", []):
            mech *= MECH_MULT.get(m, 1.0)
        t += c * hp * f * sp * mech * (AIR_MULT if e.get("flying") else 1.0)
    return t


def analyse(levels, enemies):
    out = []
    for lv in levels:
        ws = lv["waves"]
        gold = float(lv["gold"])
        rows = []
        for i, w in enumerate(ws):
            # bosses are tuned apart (their health by simulation): the curve is the rest of the wave
            boss = any(enemies[k].get("boss") for k in w["types"])
            th = threat({k: c for k, c in w["types"].items() if not enemies[k].get("boss")}, enemies, lv["hp_mult"])
            r = th / gold
            rows.append({"w": i + 1, "ehp": th, "gold_before": gold, "bounty": w["gold"], "r": r,
                         "n": w["n"], "lives": w["lives"], "boss": boss})
            gold += w["gold"]
        g, resid = fit_growth([w["ehp"] for w in rows])
        out.append({"level": lv["level"], "id": lv["id"], "hp_mult": lv["hp_mult"], "start": lv["gold"],
                    "waves": rows, "growth": g, "saw": resid, "income": gold - lv["gold"]})
    bounty = {}
    for k, e in enemies.items():
        hp = e["hp"] * (1.5 if e.get("revive") else 1.0)
        bounty[k] = e["gold"] / (hp ** BOUNTY_EXP)
    return out, bounty


def report(res, bounty):
    print("레벨별 곡선 (위협 성장률, 긴장도 R 첫→끝, 수입)")
    for L in res:
        r0, r1 = L["waves"][0]["r"], L["waves"][-1]["r"]
        rmax = max(w["r"] for w in L["waves"])
        print("  L%-2d %-11s 웨이브 %2d  성장 %+5.1f%%  R %.2f → %.2f (최대 %.2f, 끝/첫 %.1f배)  시작 %4d  수입 %5d  hp x%.2f" % (
            L["level"], L["id"], len(L["waves"]), L["growth"] * 100, r0, r1, rmax, r1 / r0, L["start"], L["income"], L["hp_mult"]))
        print("      톱니(추세 대비): " + " ".join("%.2f" % s for s in L["saw"]))
        print("      R: " + " ".join("%.2f" % w["r"] for w in L["waves"]))
    print("현상금 계수 k = 골드 / HP^%.2f" % BOUNTY_EXP)
    for k, v in sorted(bounty.items(), key=lambda kv: kv[1]):
        print("  %-16s %.3f" % (k, v))


def plot(res, path, before=None):
    """긴장도 R 곡선: 조정 전(있으면)과 후를 나란히. 보스 웨이브는 별표."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    sets = [("Before", before), ("After", res)] if before else [("Tension R", res)]
    fig, ax = plt.subplots(1, len(sets), figsize=(6.6 * len(sets), 4.4), sharey=True, squeeze=False)
    cmap = plt.get_cmap("viridis")
    for a, (title, data) in zip(ax[0], sets):
        for i, L in enumerate(data):
            c = cmap(i / max(len(data) - 1, 1))
            xs = [w["w"] for w in L["waves"]]
            a.plot(xs, [w["r"] for w in L["waves"]], color=c, lw=1.6, label="L%d" % (L["level"] + 1))
            for w in L["waves"]:
                if w.get("boss"):
                    a.plot([w["w"]], [w["r"]], marker="*", ms=11, color=c, mec="#333", mew=0.6)
        a.set_title(title + "  (R = wave threat / gold so far; * boss wave)", fontsize=10)
        a.set_xlabel("wave")
        a.grid(alpha=0.25)
        a.spines[["top", "right"]].set_visible(False)
    ax[0][0].set_ylabel("tension R")
    ax[0][-1].legend(ncol=2, fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(path, dpi=110)


if __name__ == "__main__":
    args = sys.argv[1:]
    levels, enemies, _ = load(args[0])
    res, bounty = analyse(levels, enemies)
    report(res, bounty)
    if "--png" in args:
        before = None
        if "--before" in args:
            bl, be, _ = load(args[args.index("--before") + 1])
            before, _ = analyse(bl, be)
        plot(res, args[args.index("--png") + 1], before)
