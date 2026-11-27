#!/usr/bin/env python3
"""웨이브를 목표 곡선(지수 추세 x 톱니)에 맞춰 다시 짭니다. scripts/data/db.gd의 웨이브 줄을 고칩니다.

사용:
  python3 tools/balance/shape_waves.py /tmp/curve.jsonl [--dry] [--levels 0,3]
  python3 tools/balance/shape_waves.py /tmp/curve.jsonl --check   # 지금 웨이브가 곡선을 따르는지만 봄(CI)

곡선(docs/BALANCE.md):
  긴장도 R(w) = 웨이브 위협 / 그 웨이브 전까지 모은 골드
  목표 R(w) = R0 x (R_end / R0)^(w/(N-1)) x 톱니(w)   (w = 0..N-1)
  - R0: 레벨의 첫 웨이브. 캠페인을 따라 천천히 오름(R0_BASE + R0_STEP x 레벨), 보스 다음 레벨은 한 번 내려감
  - R_end = R0 x END_RATIO. 보스는 위협에서 빼고(체력은 시뮬레이션으로 따로 맞춤) 함께 오는 무리만 곡선에 맞춤
  - 톱니: 4웨이브 주기(평온, 오름, 고비, 숨 고르기). 마지막 웨이브는 절정(FINALE)
적 구성(어떤 적이 언제 나오는지)은 그대로 두고 수만 늘리거나 줄입니다. 곡선의 모양은 웨이브별 마릿수로,
레벨의 높이는 레벨 체력 배수(hp_mult)로 맞춥니다. 레벨의 총 마릿수는 처음 짠 웨이브와 같게 둡니다(무리의 크기와 수입 유지). 보스와 한두 마리뿐인
대형 적은 그대로 두고 나머지 무리로 맞춥니다. 수를 바꾸면 출현 간격을 반대로 바꿔 웨이브 길이를 유지합니다.
"""
import json, math, re, sys, os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from curve import load, threat  # noqa: E402

DB = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "scripts/data/db.gd")

R0_FIRST = 0.7           # 첫 레벨(튜토리얼)의 첫 웨이브
R0_BASE, R0_STEP = 0.95, 0.08
END_RATIO = 2.0
POST_BOSS_DIP = 0.9      # 보스 레벨 다음 레벨의 첫 웨이브는 조금 쉽게(캠페인 단위의 톱니)
SAW = [0.94, 1.03, 1.16, 0.87]   # 평온, 오름, 고비, 숨 고르기(평균 1.0)
FINALE = 1.12
# 시뮬레이션으로 맞춘 보정(tools/balance/tuning.json, calibrate.py가 고침):
#   level_scale: 지형·갈래 수·적 조합 때문에 같은 R이라도 더 어렵거나 쉬운 레벨의 배수
#   wave_adj: 특정 웨이브("레벨:웨이브", 1부터)의 배수. 조합 때문에 튀는 웨이브를 누름
TUNING = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tuning.json")
_t = json.load(open(TUNING)) if os.path.exists(TUNING) else {}
LEVEL_SCALE = {int(k): v for k, v in _t.get("level_scale", {}).items()}
WAVE_ADJ = _t.get("wave_adj", {})
# 레벨마다 처음 손으로 짠 웨이브의 총 마릿수: 곡선에 맞춰도 무리의 크기(와 수입)는 유지
ENEMY_TOTAL = {int(k): v for k, v in _t.get("enemy_total", {}).items()}
CHECK_TOL = 0.2          # --check: 목표에서 이만큼(20%)까지는 반올림 오차로 봄
BIG_HP = 600             # 이보다 체력이 큰 적(족장·오우거)은 한두 마리면 수를 건드리지 않음


def targets(level, n, boss_levels):
    r0 = R0_FIRST if level == 0 else R0_BASE + R0_STEP * level
    if level - 1 in boss_levels:
        r0 *= POST_BOSS_DIP
    r0 *= LEVEL_SCALE.get(level, 1.0)
    end = r0 * END_RATIO
    out = []
    for w in range(n):
        trend = r0 * (end / r0) ** (w / max(n - 1, 1))
        saw = 1.0 if w == 0 else (FINALE if w == n - 1 else SAW[w % 4])
        out.append(trend * saw * WAVE_ADJ.get("%d:%d" % (level, w + 1), 1.0))
    return out


def wave_threat(groups, enemies, hp_mult):
    """웨이브 위협(보스 제외). 보스는 따로 맞춥니다: 보스 체력은 시뮬레이션으로 정하고(docs/BALANCE.md),
    보스 웨이브의 곡선 목표는 함께 오는 무리에만 적용합니다."""
    types = {}
    for g in groups:
        if enemies[g[0]].get("boss"):
            continue
        types[g[0]] = types.get(g[0], 0) + g[1]
    return threat(types, enemies, hp_mult)


def floor_of(g, enemies):
    """A group's smallest size: a swarm stays a swarm (at least 3), a pack at least 2 (groups of one
    goblin look like a bug), a big enemy may come alone."""
    hp = enemies[g[0]]["hp"]
    return min(g[1], 3 if hp < 100 else (2 if hp < BIG_HP else 1))


def rescale(groups, factor, enemies, hp_mult):
    """수를 factor 배로. 반올림 뒤 위협이 목표에 가장 가깝게 무리 하나를 한 마리씩 조정합니다."""
    goal = wave_threat(groups, enemies, hp_mult) * factor
    # a lone big enemy (warchief, ogre) keeps its count unless the wave has to change a lot
    big_ok = factor < 0.8 or factor > 1.5
    flex = [i for i, g in enumerate(groups)
            if not enemies[g[0]].get("boss") and (big_ok or not (enemies[g[0]]["hp"] >= BIG_HP and g[1] <= 2))]
    if not flex:
        return groups

    mins = {i: floor_of(groups[i], enemies) for i in flex}
    new = [list(g) for g in groups]
    for i in flex:
        new[i][1] = max(mins[i], round(groups[i][1] * factor))
    for _ in range(40):
        cur = wave_threat(new, enemies, hp_mult)
        err = cur - goal
        best, best_i, best_d = abs(err), None, 0
        for i in flex:
            for d in (-1, 1):
                if new[i][1] + d < mins[i] or new[i][1] + d > 40:
                    continue
                new[i][1] += d
                e2 = abs(wave_threat(new, enemies, hp_mult) - goal)
                new[i][1] -= d
                if e2 < best - 1e-6:
                    best, best_i, best_d = e2, i, d
        if best_i is None:
            break
        new[best_i][1] += best_d
    for i, g in enumerate(new):
        c0 = groups[i][1]
        if g[1] != c0:
            # same length of wave: the interval shrinks as the count grows
            # (a thinner group is spread at most 1.6 times wider: fewer enemies come a little sooner)
            iv = groups[i][2] * (c0 - 1) / max(g[1] - 1, 1) if c0 > 1 else groups[i][2]
            g[2] = round(min(max(iv, 0.28), groups[i][2] * 1.6, 6.0), 2)
    return new


def fmt_wave(groups):
    return "[" + ", ".join('["%s", %d, %s, %s, %d]' % (g[0], g[1], fnum(g[2]), fnum(g[3]), g[4]) for g in groups) + "]"


def fnum(v):
    s = ("%.2f" % float(v)).rstrip("0")
    return s + "0" if s.endswith(".") else s


def main():
    args = sys.argv[1:]
    levels, enemies, _ = load(args[0])
    only = None
    if "--levels" in args:
        only = {int(x) for x in args[args.index("--levels") + 1].split(",")}
    boss_levels = {L["level"] for L in levels if any(enemies[k].get("boss") for w in L["waves"] for k in w["types"])}
    src = open(DB, encoding="utf-8").read().split("\n")
    # wave lines of each level, in order
    wave_lines, cur, depth = [], None, 0
    for i, line in enumerate(src):
        if line.startswith('\t\t"waves": ['):
            cur = []
            wave_lines.append(cur)
            continue
        if cur is not None:
            if line.startswith("\t\t],"):
                cur = None
            elif line.startswith("\t\t\t[["):
                cur.append(i)
    assert len(wave_lines) == len(levels), "레벨 수가 맞지 않습니다"
    check = "--check" in args
    off = []
    hp_lines = {}
    for L, lines in zip(levels, wave_lines):
        li = L["level"]
        if only is not None and li not in only:
            continue
        waves = [json.loads(src[i].strip().rstrip(",")) for i in lines]
        tg = targets(li, len(waves), boss_levels)
        if not check:
            # The shape comes from the counts, the level from the HP multiplier: the counts are
            # fitted to tg x s, with s chosen so the level keeps the size of the horde it was
            # written with (enemy_total), and the HP multiplier divided by s brings R onto tg.
            # (R is linear in HP; the gold does not depend on it. Fitting R by counts alone thins
            # the hordes, because fewer enemies also pay less gold.)
            anchor = ENEMY_TOTAL.get(li) or sum(g[1] for w in waves for g in w)

            def build(sc):
                gold, out = float(L["gold"]), []
                for w, groups in enumerate(waves):
                    th = wave_threat(groups, enemies, L["hp_mult"])
                    new = rescale(groups, tg[w] * sc * gold / th, enemies, L["hp_mult"])
                    gold += sum(g[1] * enemies[g[0]]["gold"] for g in new)
                    out.append(new)
                return out

            lo, hi = 0.15, 6.0
            for _ in range(28):
                mid = (lo * hi) ** 0.5
                if sum(g[1] for w in build(mid) for g in w) < anchor:
                    lo = mid
                else:
                    hi = mid
            sc = (lo * hi) ** 0.5
            new_waves = build(sc)
            hp_new = round(L["hp_mult"] / sc, 2)
            gold = float(L["gold"])
            log = []
            for w, (i, new) in enumerate(zip(lines, new_waves)):
                th2 = wave_threat(new, enemies, hp_new)
                log.append("%.2f(목표 %.2f)" % (th2 / gold, tg[w]))
                src[i] = "\t\t\t" + fmt_wave(new) + ","
                gold += sum(g[1] * enemies[g[0]]["gold"] for g in new)
            hp_lines[li] = hp_new
            print("L%d %s: 적 %d마리(원래 %d), 체력 배수 %.2f → %.2f\n    R %s" % (
                li + 1, L["id"], sum(g[1] for w in new_waves for g in w), anchor, L["hp_mult"], hp_new, " ".join(log)))
            continue
        gold = float(L["gold"])
        log = []
        for w, (i, groups) in enumerate(zip(lines, waves)):
            th = wave_threat(groups, enemies, L["hp_mult"])
            goal = tg[w] * gold
            if check:
                # the data must still follow the curve (a hand edit of a wave shows up here)
                # a wave already at its smallest (one of each: a first ogre with a handful of
                # escorts) may sit above the curve; that is how a new enemy is introduced
                floor = wave_threat([[g[0], floor_of(g, enemies)] + list(g[2:]) for g in groups], enemies, L["hp_mult"])
                at_floor = th <= floor * 1.01
                if abs(th / goal - 1.0) > CHECK_TOL and not (th > goal and at_floor):
                    off.append("L%d 웨이브 %d: R %.2f, 목표 %.2f (%+d%%)" % (li + 1, w + 1, th / gold, tg[w], round((th / goal - 1) * 100)))
                gold += sum(g[1] * enemies[g[0]]["gold"] for g in groups)
                continue
            new = rescale(groups, goal / th, enemies, L["hp_mult"])
            th2 = wave_threat(new, enemies, L["hp_mult"])
            log.append("%.2f→%.2f(목표 %.2f)" % (th / gold, th2 / gold, tg[w]))
            src[i] = "\t\t\t" + fmt_wave(new) + ","
            gold += sum(g[1] * enemies[g[0]]["gold"] for g in new)
        if not check:
            print("L%d %s: %s" % (li, L["id"], " ".join(log)))
    if check:
        for o in off:
            print("곡선에서 벗어남:", o)
        print("웨이브 곡선 검사: %s" % ("통과" if not off else "%d곳 벗어남" % len(off)))
        sys.exit(1 if off else 0)
    if "--dry" not in args:
        # the level HP multipliers, in level order
        k = 0
        for i, line in enumerate(src):
            m = re.match(r'^(\t\t"gold": \d+, "lives": \d+, "hp_mult": )([0-9.]+)(,.*)$', line)
            if m:
                if k in hp_lines:
                    src[i] = m.group(1) + ("%.2f" % hp_lines[k]).rstrip("0").rstrip(".") + m.group(3)
                k += 1
        assert k == len(levels), "체력 배수 줄 수가 맞지 않습니다"
        open(DB, "w", encoding="utf-8").write("\n".join(src))


if __name__ == "__main__":
    main()
