#!/usr/bin/env bash
# Pre-render the title-screen backdrops (one per hero) used while the 3D content streams in on the
# web: the diorama at the opening camera pose, no UI, 2.4:1 so a centred crop fits any screen.
# Needs a display (e.g. Xvfb: DISPLAY=:77). Re-run whenever the title diorama changes.
#   GODOT=<binary>  (default: godot)    SIZE=<w>x<h> render size (default 3240x1350, stored at 2880x1200)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
SIZE=${SIZE:-3240x1350}
OUT=assets/ui/backdrop
mkdir -p "$OUT"
for hero in kael:hero sera:sera ren:ranger; do
  id=${hero%%:*}; model=${hero##*:}
  timeout 300 $GODOT --path . --rendering-driver opengl3 --resolution "$SIZE" res://scenes/test_runner.tscn -- \
    mode=menu hq=1 hero=$id backdrop=/tmp/rb_backdrop_$model.png 2>&1 | grep -E "BACKDROP|ERROR" || true
  python3 - "$model" "$OUT" <<'EOF'
import sys
from PIL import Image
m, out = sys.argv[1], sys.argv[2]
Image.open("/tmp/rb_backdrop_%s.png" % m).convert("RGB").resize((2880, 1200), Image.LANCZOS).save("%s/menu_%s.jpg" % (out, m), quality=93, optimize=True, progressive=True)
print("wrote %s/menu_%s.jpg" % (out, m))
EOF
done
