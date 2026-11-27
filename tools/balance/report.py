#!/usr/bin/env python3
"""시뮬레이션 결과를 그림과 표로: 조정 전후 비교.

사용: python3 tools/balance/report.py <후.json[,후2.json]> [--before <전.json[,전2.json]>] [--png 그림.png] [--md]
  --md: docs/BALANCE.md "결과" 절에 붙일 표(마크다운)를 출력합니다.
"""
import json, sys

CATS = [("expert", 0, "보통 · expert"), ("casual", 0, "보통 · casual"), ("casual", 2, "쉬움 · casual"), ("expert", 1, "영웅 · expert")]


def rows_by(paths):
    """한 파일 또는 쉼표로 이은 여러 파일(sim.py를 나눠 돌린 결과)."""
    out = {}
    for path in paths.split(","):
        for r in json.load(open(path))["rows"]:
            out[(r["skill"], r["diff"], r["level"])] = r
    return out


def md_table(after, before, nlev):
    head = "| 레벨 | " + " | ".join(c[2] for c in CATS) + " |"
    sep = "|---|" + "---|" * len(CATS)
    out = [head, sep]
    for L in range(nlev):
        cells = []
        for sk, df, _ in CATS:
            a = after.get((sk, df, L))
            b = before.get((sk, df, L)) if before else None
            fa = "%d%% / %.1f" % (round(a["win"] * 100), a["lives"]) if a else "-"
            fb = "%d%% / %.1f → " % (round(b["win"] * 100), b["lives"]) if b else ""
            cells.append(fb + fa)
        out.append("| %d | %s |" % (L + 1, " | ".join(cells)))
    return "\n".join(out)


def plot(after, before, nlev, path):
    """위: 승률, 아래: 평균 남은 생명(최대 대비 %, 진 판은 0). 회색 전, 파랑 후."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axs = plt.subplots(2, len(CATS), figsize=(15, 6.2), sharey="row", sharex=True)
    xs = list(range(1, nlev + 1))
    names = {"보통 · expert": "Normal · expert", "보통 · casual": "Normal · casual",
             "쉬움 · casual": "Easy · casual", "영웅 · expert": "Heroic · expert"}
    metrics = [("win rate %", lambda r: r["win"] * 100), ("lives left % of max", lambda r: r["lives"] / r["max_lives"] * 100)]
    for row, (label, f) in enumerate(metrics):
        for col, (sk, df, name) in enumerate(CATS):
            ax = axs[row][col]
            for data, color, lw, lab in ((before, "#9aa3ad", 1.8, "before"), (after, "#2f6fd0", 2.2, "after")):
                if not data:
                    continue
                ax.plot(xs, [f(data[(sk, df, L)]) if (sk, df, L) in data else float("nan") for L in range(nlev)],
                        color=color, lw=lw, marker="o", ms=4, label=lab)
            if row == 0:
                ax.set_title(names[name], fontsize=11)
            else:
                ax.set_xlabel("level")
            ax.set_xticks(xs)
            ax.set_ylim(-5, 105)
            ax.grid(alpha=0.25)
            ax.spines[["top", "right"]].set_visible(False)
        axs[row][0].set_ylabel(label)
    axs[1][0].legend(frameon=False, fontsize=9, loc="lower left")
    fig.tight_layout()
    fig.savefig(path, dpi=110)


if __name__ == "__main__":
    a = sys.argv[1:]
    after = rows_by(a[0])
    before = rows_by(a[a.index("--before") + 1]) if "--before" in a else None
    nlev = 1 + max(k[2] for k in after)
    if "--md" in a:
        print(md_table(after, before, nlev))
    if "--png" in a:
        plot(after, before, nlev, a[a.index("--png") + 1])
