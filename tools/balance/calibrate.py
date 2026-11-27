#!/usr/bin/env python3
"""시뮬레이션 결과로 tuning.json을 고칩니다(tools/balance/shape_waves.py가 읽음).

사용: python3 tools/balance/calibrate.py <sim.json> [--apply] [--no-up]
규칙(expert, 보통 난이도):
  - 마지막이 아닌 웨이브의 평균 생명 손실이 LOSS_MID를 넘으면 그 웨이브 목표를 넘친 만큼 낮춤(0.75~0.92배)
  - 마지막 웨이브는 LOSS_FINAL까지 허용(절정)
  - 레벨 평균 남은 생명이 LIVES_MIN 밑이고 튀는 웨이브가 없으면 레벨 전체 x STEP_DOWN
  - 모든 판에서 생명을 하나도 잃지 않은 레벨(튜토리얼 제외)은 x STEP_UP(긴장을 조금 되살림). casual이 이미
    힘든 단계라면 --no-up으로 끕니다
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOSS_MID, LOSS_FINAL, LIVES_MIN = 1.0, 2.5, 16.5
STEP_DOWN, STEP_UP = 0.88, 1.04


def main():
    sim = json.load(open(sys.argv[1]))
    tpath = os.path.join(HERE, "tuning.json")
    t = json.load(open(tpath))
    ls, wa = t.setdefault("level_scale", {}), t.setdefault("wave_adj", {})
    for r in sim["rows"]:
        if r["skill"] != "expert" or r["diff"] != 0:
            continue
        L, loss = r["level"], r["loss"]
        n = len(loss)
        spikes = []
        for w, v in enumerate(loss):
            lim = LOSS_FINAL if w == n - 1 else LOSS_MID
            if v is not None and v > lim:
                spikes.append(w + 1)
                k = "%d:%d" % (L, w + 1)
                # the bigger the overshoot, the bigger the cut (0.75..0.92 per round)
                wa[k] = round(wa.get(k, 1.0) * max(0.75, min(0.92, (lim / v) ** 0.2)), 3)
        if not spikes and r["lives"] < LIVES_MIN:
            ls[str(L)] = round(ls.get(str(L), 1.0) * STEP_DOWN, 3)
        if "--no-up" not in sys.argv and L > 0 and r["win"] == 1.0 and all(not v for v in loss if v is not None) and r["lives"] >= r["max_lives"]:
            ls[str(L)] = round(ls.get(str(L), 1.0) * STEP_UP, 3)
        print("L%d 생명 %.1f 고비 웨이브 %s" % (L + 1, r["lives"], spikes or "-"))
    if "--apply" in sys.argv:
        json.dump(t, open(tpath, "w"), indent=1, sort_keys=True)
    print(json.dumps(t, sort_keys=True))


if __name__ == "__main__":
    main()
