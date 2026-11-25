#!/usr/bin/env bash
# Build the size-optimized web export template described in tools/engine/web_template.env.
# Usage: tools/engine/build_template.sh <godot source dir> <output zip> [advanced|fallback]
# Needs Emscripten ($EM_VERSION, emcc on PATH) and SCons. The source must be checked out at
# $GODOT_REF: an export template only works with the editor version it was built from.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
SRC=$1
OUT=$2
# shellcheck disable=SC1091
source "$here/web_template.env"
flags="$SCONS_FLAGS"
TEXT_SERVER=${3:-${TEXT_SERVER:-advanced}}
if [ "$TEXT_SERVER" = "fallback" ]; then
  flags="$flags module_text_server_adv_enabled=no module_text_server_fb_enabled=yes"
fi
echo "== emcc $(emcc --version | head -1)"
echo "== scons $flags"
cd "$SRC"
# shellcheck disable=SC2086
scons -j"$(nproc)" $flags
zip=$(ls -t bin/godot.web.template_release.wasm32*.zip | head -1)
mkdir -p "$(dirname "$OUT")"
cp "$zip" "$OUT"
unzip -l "$OUT"
