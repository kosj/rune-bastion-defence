#!/usr/bin/env bash
# 영웅 시작 위치 검사: 레벨마다 영웅이 건설 부지·강·소품·이벤트 자리와 겹치지 않고 서는지 봅니다.
# (level.gd `_hero_spot`이 고른 자리를 test_runner `herocheck=1`이 부지 반경, keepout, 메시 AABB,
# 배경 소품 배치로 다시 확인합니다.) 하나라도 겹치면 실패합니다.
#   tools/check_spawn.sh [레벨 수=10]
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
N=${1:-10}
fail=0
for ((i = 0; i < N; i++)); do
  out=$(timeout 300 $G --headless --path . res://scenes/test_runner.tscn -- level=$i mode=shots intro=0 nowave=1 herocheck=1 max_t=60 2>&1)
  line=$(echo "$out" | grep "^HEROCHECK level")
  echo "${line:-HEROCHECK level $i: 결과 없음}"
  echo "$out" | grep "SCRIPT ERROR" | head -3
  if ! echo "$line" | grep -q " clear$"; then
    echo "$out" | grep "^HEROCHECK   " | head -8
    fail=1
  fi
done
exit $fail
