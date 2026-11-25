#!/usr/bin/env bash
# Check that every scene only loads assets of the download chunks it waits for
# (scripts/data/pack_chunks.gd). Runs the game headless with the Content autoload pretending
# that only some chunks have arrived (user arg chunks=...); any load of a missing chunk prints
# "CHUNK MISS <path> (<chunk>)" and fails the check.
#   title screen        core only
#   menu screens        core + menu
#   3D title diorama    core + title_3d_needs
#   first battle        core + first_battle.needs (AI plays level 1 to the end)
# Usage: tools/check_chunks.sh   (GODOT=<binary>, default godot; needs an imported project)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
man() { python3 -c "import sys; sys.path.insert(0, 'tools'); from split_pck import load_manifest as m; d = m('scripts/data/pack_chunks.gd'); print($1)"; }
FIRST_LEVEL=$(man 'd["first_battle"]["level"]')
FIRST_NEEDS=$(man '",".join(d["first_battle"]["needs"])')
TITLE3D=$(man '",".join(d["title_3d_needs"])')
LOG=$(mktemp -d)
fail=0
run() {  # name, expect-regex, args...
  local name=$1 expect=$2; shift 2
  timeout 900 $GODOT --headless --path . res://scenes/test_runner.tscn -- "$@" > "$LOG/$name.log" 2>&1
  local miss
  miss=$(grep -c "CHUNK MISS" "$LOG/$name.log")
  if [ "$miss" -gt 0 ] || ! grep -qE "$expect" "$LOG/$name.log" || grep -q "SCRIPT ERROR" "$LOG/$name.log"; then
    echo "FAIL $name"; grep -E "CHUNK MISS|SCRIPT ERROR" "$LOG/$name.log" | sort | uniq -c | head -12
    fail=1
  else
    echo "ok   $name"
  fi
}
run title "menu_first_frame" mode=menu chunks=none max_t=4
for o in _open_select _open_heroes _open_bestiary _open_achievements _open_upgrades _open_settings; do
  run "menu$o" "menu_first_frame" mode=menu chunks=menu open=$o max_t=6
done
run title_3d "menu_world_built" mode=menu chunks="$TITLE3D" max_t=6
run first_battle "RESULT won" level="$FIRST_LEVEL" hero=kael mode=smart speed=5 max_t=900 chunks="$FIRST_NEEDS"
rm -rf "$LOG"
exit $fail
