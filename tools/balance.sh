#!/usr/bin/env bash
# Run AI playthroughs for every level in parallel.  usage: tools/balance.sh <mode> <diff> [extra args]
cd "$(dirname "$0")/.."
MODE=${1:-smart}; DIFF=${2:-0}; shift 2 || true
mkdir -p /tmp/bal
LEVELS=${LEVELS:-0 1 2 3 4 5 6 7 8 9}
for L in $LEVELS; do
  (timeout 1000 godot --headless --path . res://scenes/test_runner.tscn -- level=$L mode=$MODE diff=$DIFF speed=5 max_t=900 "$@" > /tmp/bal/${MODE}_${DIFF}_${TAG:-x}_$L.log 2>&1 &)
done
sleep 5
while pgrep -f "test_runner.tscn" >/dev/null; do sleep 5; done
for L in $LEVELS; do echo "L$L $(grep -E 'RESULT|TIMEOUT|SCRIPT ERROR' /tmp/bal/${MODE}_${DIFF}_${TAG:-x}_$L.log | head -2 | tr '\n' ' ')"; done
