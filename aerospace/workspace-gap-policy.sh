#!/bin/zsh
# Automatically switch AeroSpace gaps based on the focused workspace window count.
# - 0/1 windows: roomy gaps
# - 2+ windows: no gaps and tiled layout

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/aerospace"
LOCK_DIR="$STATE_DIR/workspace-gap-policy.lock"
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

apply_policy() {
  local workspace count desired current

  workspace="${1:-}"
  if [[ -z "$workspace" ]]; then
    workspace="$($AEROSPACE list-workspaces --focused | head -n 1)"
  fi
  if [[ -z "$workspace" ]]; then
    return 0
  fi

  count="$($AEROSPACE list-windows --workspace "$workspace" --count)"

  if (( count <= 1 )); then
    desired="roomy"
  else
    desired="0"
  fi

  current=""
  if [[ -f "$PRESET_FILE" ]]; then
    current="$(cat "$PRESET_FILE")"
  fi

  if [[ "$current" != "$desired" ]]; then
    print -r -- "$desired" > "$PRESET_FILE"
    "$SET_GAPS" "$desired"
  fi

  if [[ "$desired" == "0" ]]; then
    "$AEROSPACE" layout tiles >/dev/null 2>&1 || true
  fi
}

if [[ "${1:-}" == "--once" ]]; then
  apply_policy "${2:-}"
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  # Already running.
  exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

# Apply once on startup.
apply_policy

# Keep reconnecting if AeroSpace restarts or reloads drop the subscription.
while true; do
  "$AEROSPACE" subscribe --no-send-initial focused-workspace-changed window-detected window-closed |
  while IFS= read -r event; do
    if [[ "$event" == *'"_event":"focused-workspace-changed"'* ]]; then
      apply_policy
    else
      # Window open/close count can lag briefly behind the event.
      sleep 0.03
      apply_policy
    fi
  done || true

  sleep 0.25
  apply_policy || true
done
