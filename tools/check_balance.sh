#!/bin/bash
# 밸런스 곡선 검사: 웨이브 데이터가 docs/BALANCE.md의 곡선(지수 추세 x 톱니, tuning.json 보정 포함)을
# 따르는지 봅니다. 웨이브를 손으로 고치면 여기서 걸립니다. 고친 뒤에는 tools/balance/shape_waves.py로
# 다시 맞추고 tools/balance/sim.py로 확인합니다.
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
out=$(mktemp)
$G --headless --path . res://scenes/test_runner.tscn -- curve=1 2>/dev/null | grep -E '^(CURVE|ENEMIES|TOWERS)' > "$out"
[ "$(grep -c '^CURVE' "$out")" -gt 0 ] || { echo "곡선 데이터를 뽑지 못했습니다"; exit 1; }
python3 tools/balance/shape_waves.py "$out" --check
