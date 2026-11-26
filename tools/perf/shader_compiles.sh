#!/usr/bin/env bash
# Counts the GL shader programs a battle compiles, and when (docs/PERFORMANCE.md, "셰이더 워밍업").
#   tools/perf/shader_compiles.sh [level=2] [warmup=1] [out=/tmp/glc_<level>_<warmup>.log]
# Needs a display (Xvfb :77) and gcc. Runs the AI player (mode=smart) on native GL (llvmpipe):
# frame times there are useless for hitches, but every compile is counted exactly. Each run starts
# with Godot's desktop shader cache and Mesa's cache off, otherwise nothing is compiled at all.
# GLSHIM_DUMP=<dir> also saves every shader source (diff a late one against the warm-up's) and
# lets the summary count the default-specialization programs the web engine skips.
# STAGED=1: only the warm-up, each group (enemies, towers by level, masteries, effects, rings,
# unlit, overview) on its own frames, to see which group compiles what.
set -euo pipefail
cd "$(dirname "$0")/../.."
LEVEL="${1:-2}"
WARM="${2:-1}"
OUT="${3:-/tmp/glc_${LEVEL}_${WARM}.log}"
SHIM=/tmp/rb_glshim.so
gcc -shared -fPIC -O2 -o "$SHIM" tools/perf/glshim.c -ldl
rm -rf "$HOME/.local/share/godot/app_userdata/Rune Bastion/shader_cache"
ARGS=(level="$LEVEL" mode=smart speed=3 intro=0 newlog=1)
[ "$WARM" = "1" ] && ARGS+=(warmup=1)
[ "${STAGED:-0}" = "1" ] && ARGS+=(warmstaged=1 warmonly=1 mode=watch)
MESA_SHADER_CACHE_DISABLE=true LD_PRELOAD="$SHIM" DISPLAY="${DISPLAY:-:77}" \
  timeout "${TIMEOUT:-2400}" godot --path . --rendering-driver opengl3 --resolution 192x108 \
  res://scenes/test_runner.tscn -- "${ARGS[@]}" > "$OUT" 2>&1 || true
python3 tools/perf/glc_sum.py "$OUT" ${GLSHIM_DUMP:-}
