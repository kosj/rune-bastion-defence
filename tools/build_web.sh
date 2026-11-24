#!/usr/bin/env bash
# Build pipeline: import -> role-aware texture settings -> Web export (desktop pack) ->
# mobile pack (ETC2 textures, built in a throw-away copy of the project) -> gzip/split for hosting.
#   GODOT=<binary>   Godot 4.7 editor binary (default: godot)
#   MOBILE_PACK=0    skip the mobile pack
#   BUILD_ID=<id>    cache-busting id for the part URLs (default: timestamp + git hash)
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
GODOT=${GODOT:-godot}
BUILD_ID=${BUILD_ID:-$(date +%Y%m%d%H%M)-$(git rev-parse --short HEAD 2>/dev/null || echo local)}

echo "== import"
timeout 1800 $GODOT --headless --path . --import >/dev/null 2>&1 || true

echo "== texture import settings (role-aware: lossy albedo, lossless normal/ORM; no VRAM compression)"
python3 tools/patch_imports.py
timeout 1800 $GODOT --headless --path . --import >/dev/null 2>&1 || true

echo "== export (desktop pack)"
rm -rf build/web && mkdir -p build/web
timeout 1800 $GODOT --headless --path . --export-release "Web" build/web/index.html 2>&1 | grep -vE "ALSA|audio" | tail -5 || true

if [ "${MOBILE_PACK:-1}" = "1" ]; then
  echo "== mobile pack (ETC2 / EAC textures, size caps for phones)"
  TMP=$(mktemp -d)
  MP="$TMP/rb_mobile"
  mkdir -p "$MP"
  tar --exclude=./build --exclude=./.git -cf - . | (cd "$MP" && tar -xf -)
  (
    cd "$MP"
    # lighter towers / castle / portal for phones; drop the textures extracted from the desktop
    # meshes so the re-baked maps of the phone meshes are extracted instead
    for g in mobile/models/*.glb; do
      n=$(basename "$g" .glb)
      cp "$g" "assets/models/$n.glb"
      rm -f assets/models/${n}_albedo.png* assets/models/${n}_normal.png* assets/models/${n}_orm.png*
    done
    timeout 1800 $GODOT --headless --path . --import >/dev/null 2>&1 || true
    python3 tools/patch_imports.py --mobile
    # only the mobile (ETC2/ASTC) variants are needed in this pack
    grep -q "import_s3tc_bptc" project.godot || \
      sed -i 's#^textures/vram_compression/import_etc2_astc=true#textures/vram_compression/import_etc2_astc=true\ntextures/vram_compression/import_s3tc_bptc=false#' project.godot
    timeout 1800 $GODOT --headless --path . --import >/dev/null 2>&1 || true
  )
  timeout 1800 $GODOT --headless --path "$MP" --export-pack "WebMobile" "$ROOT/build/web/index_mobile.pck" 2>&1 | grep -vE "ALSA|audio" | tail -3 || true
  rm -rf "$TMP"
fi
ls -la build/web

echo "== package for static hosting (build $BUILD_ID)"
rm -rf build/web_hosted build/web_artifact
python3 tools/package_web.py build/web build/web_hosted --build-id "$BUILD_ID"
python3 tools/package_web.py build/web build/web_artifact --b64 --no-mobile
ls -la build/web_hosted
