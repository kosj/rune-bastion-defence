#!/bin/bash
# Publish build/web_hosted to the gh-pages branch (GitHub Pages static hosting).
# usage: ./tools/build_web.sh && ./tools/deploy_pages.sh [remote]
# The branch is rebuilt from scratch on every deploy so old builds don't pile up in history.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC="$ROOT/build/web_hosted"
REMOTE=${1:-origin}
[ -f "$SRC/index.html" ] || { echo "run ./tools/build_web.sh first"; exit 1; }
URL=$(git -C "$ROOT" remote get-url "$REMOTE")
REV=$(git -C "$ROOT" rev-parse --short HEAD)
TMP=$(mktemp -d)
cp -r "$SRC"/. "$TMP"/
touch "$TMP/.nojekyll"
cd "$TMP"
git init -q -b gh-pages
git add -A
git commit -q -m "Deploy web build ($REV)"
git push -f "$URL" gh-pages
rm -rf "$TMP"
echo "deployed $REV -> gh-pages"
