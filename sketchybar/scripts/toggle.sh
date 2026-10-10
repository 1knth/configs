#!/bin/zsh
# Toggle SketchyBar visibility.

set -euo pipefail

hidden="$(sketchybar --query bar | python3 -c 'import json,sys; print(json.load(sys.stdin).get("hidden", "off"))')"

if [[ "$hidden" == "on" ]]; then
  sketchybar --bar hidden=off
else
  sketchybar --bar hidden=on
fi
