#!/bin/zsh
# Switch workspace after applying the gap preset for the target workspace.
# This avoids drawing the target workspace once with the previous workspace's gaps.

set -euo pipefail

target="${1:?workspace required}"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
PRESET_FILE="$STATE_DIR/gap-preset"
SET_GAPS="$HOME/.config/aerospace/set-gaps.sh"
DEBUG_AEROSPACE="$HOME/coding/aerospace/.debug/aerospace"
DEBUG_SOCKET="/tmp/bobko.aerospace.debug-$(whoami).sock"

if [[ -n "${AEROSPACE_BIN:-}" ]]; then
  AEROSPACE="$AEROSPACE_BIN"
elif [[ -x "$DEBUG_AEROSPACE" && -S "$DEBUG_SOCKET" ]]; then
  AEROSPACE="$DEBUG_AEROSPACE"
else
  AEROSPACE="aerospace"
fi

mkdir -p "$STATE_DIR"

count="$($AEROSPACE list-windows --workspace "$target" --count)"
if (( count <= 1 )); then
  desired="roomy"
else
  desired="0"
fi

current=""
if [[ -f "$PRESET_FILE" ]]; then
  current="$(cat "$PRESET_FILE")"
fi

# Set gaps before switching so the destination is drawn with the right preset.
if [[ "$current" != "$desired" ]]; then
  print -r -- "$desired" > "$PRESET_FILE"
  "$SET_GAPS" "$desired"
fi

"$AEROSPACE" workspace "$target"

if [[ "$desired" == "0" ]]; then
  "$AEROSPACE" layout tiles >/dev/null 2>&1 || true
fi
