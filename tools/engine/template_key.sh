#!/usr/bin/env bash
# Cache key of the web template: changes with the engine version, Emscripten, the build flags,
# the text server choice and the build script. Usage: template_key.sh [advanced|fallback]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "$here/web_template.env"
ts=${1:-${TEXT_SERVER:-advanced}}
h=$( { echo "$GODOT_REF $EM_VERSION $ts"; echo "$SCONS_FLAGS" | tr -s ' \n' ' '; cat "$here/build_template.sh"; } | sha256sum | cut -c1-16)
echo "web-template-${GODOT_REF}-${ts}-${h}"
