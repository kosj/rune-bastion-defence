#!/usr/bin/env bash
# 팝업(시트) 닫기 검사: 모든 메뉴 시트와 지역 카드, 일시 정지를 닫기 버튼·바깥 탭·Esc로 닫아 봅니다.
# 가로와 세로 창 모두에서 돌립니다. 하나라도 안 닫히면 실패합니다.
cd "$(dirname "$0")/.."
G=${GODOT:-godot}
fail=0
run() {  # label, args...
  local label=$1; shift
  out=$(timeout 300 $G --headless --path . --fixed-fps 20 "$@" 2>&1)
  echo "$out" | grep -E "CLOSETEST .*FAIL|SCRIPT ERROR" | sed "s/^/[$label] /"
  if ! echo "$out" | grep -q "CLOSETEST DONE fails=0"; then
    echo "[$label] 실패"; fail=1
  else
    echo "[$label] 통과 ($(echo "$out" | grep -c 'CLOSETEST .* ok')건)"
  fi
}
run "메뉴 가로" res://scenes/test_runner.tscn -- win=1280x720 mode=menu progress=1 progress_all=1 closetest=1 max_t=900
run "메뉴 세로" res://scenes/test_runner.tscn -- win=430x932 mode=menu progress=1 progress_all=1 closetest=1 max_t=900
run "전투 가로" res://scenes/test_runner.tscn -- win=1280x720 level=2 mode=shots intro=0 nowave=1 closetest=1 max_t=900
run "전투 세로" res://scenes/test_runner.tscn -- win=430x932 level=2 mode=shots intro=0 nowave=1 closetest=1 max_t=900
exit $fail
