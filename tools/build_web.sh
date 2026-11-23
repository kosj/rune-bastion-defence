#!/usr/bin/env bash
# Build pipeline: import -> role-aware texture settings -> Web export -> gzip/split for static hosting.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}

echo "== import"
timeout 900 $GODOT --headless --path . --import >/dev/null 2>&1 || true

echo "== texture import settings (role-aware: lossy albedo, lossless normal/ORM; no VRAM compression)"
python3 tools/patch_imports.py
timeout 900 $GODOT --headless --path . --import >/dev/null 2>&1 || true

echo "== export"
rm -rf build/web && mkdir -p build/web
timeout 900 $GODOT --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "ALSA|audio" | tail -5 || true
ls -la build/web

echo "== package for static hosting"
python3 tools/package_web.py build/web build/web_hosted
python3 tools/package_web.py build/web build/web_artifact --b64
ls -la build/web_hosted
