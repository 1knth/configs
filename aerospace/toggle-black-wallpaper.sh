#!/bin/zsh
# Switch all macOS desktops between a black wallpaper and the last real wallpaper.
#
#   toggle-black-wallpaper.sh          toggle (manual, bound to alt-shift-w)
#   toggle-black-wallpaper.sh auto     follow the focused window's fullscreen state
#   toggle-black-wallpaper.sh on|off   force black on / restore

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
BLACK="$STATE_DIR/black.png"
LAST="$STATE_DIR/last-wallpaper"
MODE="$STATE_DIR/mode"          # cached "black" | "normal", avoids a 100ms osascript
LOCK="$STATE_DIR/.lock"

mkdir -p "$STATE_DIR"

if [[ ! -f "$BLACK" ]]; then
  python3 - "$BLACK" <<'PY'
import struct, sys, zlib
path = sys.argv[1]
w, h = 16, 16
raw = b''.join(b'\x00' + b'\x00\x00\x00' * w for _ in range(h))
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 9))
png += chunk(b'IEND', b'')
open(path, 'wb').write(png)
PY
fi

# --- what do we want? -------------------------------------------------------

HELPER="${0:A:h}/bin/wallpaper-helper"

# Build the helper on first run (or after a macOS/Xcode update invalidates it).
if [[ ! -x "$HELPER" && -f "$HELPER.swift" ]] && command -v swiftc >/dev/null; then
  swiftc -O "$HELPER.swift" -o "$HELPER" 2>/dev/null || true
fi

read_wallpaper() {
  if [[ -x "$HELPER" ]]; then
    "$HELPER" current
  else
    osascript -e 'tell application "System Events" to get picture of current desktop'
  fi
}

current_mode() {
  # Trust the cache when present; it is only written after a successful apply.
  if [[ -s "$MODE" ]]; then
    cat "$MODE"
  elif [[ "$(read_wallpaper)" == "$BLACK" ]]; then
    print -r -- black
  else
    print -r -- normal
  fi
}

focused_is_fullscreen() {
  local out
  out="$(aerospace list-windows --focused --format '%{window-is-fullscreen}' 2>/dev/null)" || return 1
  [[ "$out" == true ]]
}

have="$(current_mode)"

case "${1:-toggle}" in
  auto)   if focused_is_fullscreen; then want=black; else want=normal; fi ;;
  on)     want=black  ;;
  off)    want=normal ;;
  toggle) if [[ "$have" == black ]]; then want=normal; else want=black; fi ;;
  *) print -u2 "usage: ${0:t} [auto|on|off|toggle]"; exit 2 ;;
esac

[[ "$want" == "$have" ]] && exit 0

# --- apply ------------------------------------------------------------------

# Serialize: on-focus-changed can fire several times in a row.
# mkdir is atomic; a stale dir older than 30s is assumed abandoned.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [[ -n "$(find "$LOCK" -maxdepth 0 -mmin +0.5 2>/dev/null)" ]]; then
    rmdir "$LOCK" 2>/dev/null || true
    mkdir "$LOCK" 2>/dev/null || exit 0
  else
    exit 0
  fi
fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

# Re-read under the lock in case another invocation just won the race.
[[ "$want" == "$(current_mode)" ]] && exit 0

if [[ -x "$HELPER" ]]; then
  # One process does read + write; ~20ms instead of two ~100ms osascript hops.
  if [[ "$want" == black ]]; then
    "$HELPER" black "$STATE_DIR"
  else
    "$HELPER" restore "$STATE_DIR"
  fi
else
  if [[ "$want" == black ]]; then
    # Remember the real wallpaper, but never remember black as "the last one".
    real="$(read_wallpaper)"
    [[ "$real" != "$BLACK" ]] && print -r -- "$real" > "$LAST"
    target="$BLACK"
  else
    [[ -s "$LAST" ]] || exit 0     # nothing to restore to
    target="$(cat "$LAST")"
    [[ -e "$target" ]] || exit 0
  fi

  osascript - "$target" <<'APPLESCRIPT'
on run argv
  set wallpaperPath to POSIX file (item 1 of argv)
  tell application "System Events"
    set picture of every desktop to wallpaperPath
  end tell
end run
APPLESCRIPT
fi

print -r -- "$want" > "$MODE"
