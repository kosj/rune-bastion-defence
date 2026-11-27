#!/bin/bash
# UI 화면 점검: 주요 화면(오늘의 도전 카드, 선택 카드와 알림이 겹치지 않는지 보는 notes 포함)을
# PC(D, 1600x900), 폰 세로(P, 430x932), 폰 가로(L, 932x430)로 찍습니다.
# 사용: DISPLAY=:77 [UILANG=en|ja|ko] tools/ui_shots.sh <출력 폴더> [동시 실행 수] [형태 필터 D|P|L] [화면 필터]
#   예: UILANG=en tools/ui_shots.sh /tmp/ui_en 2 "P" "pause|win"
#   UILANG을 주면 그 언어로 찍습니다(번역이 길어 넘치는 곳 찾기). UISAFE는 노치 여백을 흉내 냅니다.
# 이미 있는 파일은 건너뜁니다. 화면이 느리면(소프트웨어 렌더링) 동시 실행 수를 2 이하로 둡니다.
out=$1; J=${2:-2}; RF=${3:-.}; NF=${4:-.}; mkdir -p "$out"
cd "$(dirname "$0")/.."
LA=""; [ -n "$UILANG" ] && LA="lang=$UILANG"
# UISAFE=l,t,r,b: 노치·홈 표시줄 여백(캔버스 단위)을 흉내 냅니다. 예: 폰 가로 UISAFE=64,0,64,28
[ -n "$UISAFE" ] && LA="$LA safe=$UISAFE"
M="mode=menu progress=1 progress_all=1 max_t=7.5 $LA"
Lv="level=2 mode=shots intro=0 nowave=1 $LA"
{
for R in "1600x900 D" "430x932 P" "932x430 L"; do
  set -- $R
  for spec in \
    "title|$M shot_times=6" \
    "map|$M open=_open_select shot_times=6.8" \
    "card|$M open=_open_select map_card=2 shot_times=7" \
    "daily|$M open=_open_select map_card=d shot_times=7" \
    "upg|$M open=_open_upgrades shot_times=6.8" \
    "set|$M open=_open_settings shot_times=6.8" \
    "hero|$M open=_open_heroes shot_times=6.8" \
    "best|$M open=_open_bestiary shot_times=6.8" \
    "ach|$M open=_open_achievements shot_times=6.8" \
    "hud|$Lv shot_times=4 max_t=4.5" \
    "pause|$Lv ui=pause ui_at=3 shot_times=4.5 max_t=5" \
    "win|$Lv ui=victory ui_at=3 shot_times=9.5 max_t=10 end_wait=20" \
    "lose|$Lv ui=defeat ui_at=3 shot_times=7 max_t=8 end_wait=20" \
    "tower|$Lv ui=tower ui_at=3 shot_times=4.5 max_t=5" \
    "plot|$Lv ui=plot ui_at=3 shot_times=4.5 max_t=5" \
    "enemy|$Lv ui=enemy ui_at=3 shot_times=5 max_t=5.5" \
    "notes|$Lv ui=notes ui_at=3 shot_times=4.8 max_t=5.3"; do
    name=${spec%%|*}; a=${spec#*|}
    echo "$2" | grep -qE "$RF" || continue
    echo "$name" | grep -qE "$NF" || continue
    [ -f "$out/${name}_$2_00.png" ] && continue
    echo "$1 ${name}_$2 $a"
  done
done
} | xargs -P "$J" -L 1 bash -c 'res=$0; tag=$1; shift; timeout 300 godot --path . --rendering-driver opengl3 --resolution $res --fixed-fps ${UIFPS:-10} res://scenes/test_runner.tscn -- shots='"$out"' tag=$tag "$@" > /tmp/ui_shot_$tag.log 2>&1'
ls "$out" | wc -l
