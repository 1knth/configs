#!/bin/zsh
# Set AeroSpace gap presets, then reload config.
# Usage: set-gaps.sh 0|20|35|roomy|regular

set -euo pipefail

CONFIG="$HOME/.aerospace.toml"
VALUE="${1:?usage: set-gaps.sh 0|20|35|roomy|regular}"
DEBUG_AEROSPACE="$HOME/coding/aerospace/.debug/aerospace"
DEBUG_SOCKET="/tmp/bobko.aerospace.debug-$(whoami).sock"

if [[ -n "${AEROSPACE_BIN:-}" ]]; then
  AEROSPACE="$AEROSPACE_BIN"
elif [[ -x "$DEBUG_AEROSPACE" && -S "$DEBUG_SOCKET" ]]; then
  AEROSPACE="$DEBUG_AEROSPACE"
else
  AEROSPACE="aerospace"
fi

python3 - "$CONFIG" "$VALUE" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
value = sys.argv[2]
text = path.read_text()

if value == "regular":
    replacements = {
        "inner.horizontal": 'inner.horizontal =  [{ monitor."built-in" = 4 }, 0]',
        "inner.vertical": 'inner.vertical =    [{ monitor."built-in" = 4 }, 0]',
        "outer.bottom": 'outer.bottom =      [{ monitor."built-in" = 4 }, 0]',
        "outer.top": 'outer.top =         [{ monitor."built-in" = 9 }, 37]',
        "outer.left": 'outer.left =        [{ monitor."built-in" = 4 }, 0]',
        "outer.right": 'outer.right =       [{ monitor."built-in" = 4 }, 0]',
    }
elif value == "roomy":
    replacements = {
        "inner.horizontal": "inner.horizontal = 15",
        "inner.vertical": "inner.vertical = 15",
        "outer.bottom": "outer.bottom = 35",
        "outer.top": "outer.top = 50",
        "outer.left": "outer.left = 35",
        "outer.right": "outer.right = 35",
    }
elif value.isdigit():
    top = "3" if value == "0" else value
    side = "1" if value == "0" else value
    replacements = {
        "inner.horizontal": f"inner.horizontal = {value}",
        "inner.vertical": f"inner.vertical = {value}",
        "outer.bottom": f"outer.bottom = {value}",
        "outer.top": f"outer.top = {top}",
        "outer.left": f"outer.left = {side}",
        "outer.right": f"outer.right = {side}",
    }
else:
    raise SystemExit("usage: set-gaps.sh 0|20|35|roomy|regular")

for key, line in replacements.items():
    text, count = re.subn(rf"^{re.escape(key)}\s*=.*$", line, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise SystemExit(f"Could not find gap setting: {key}")

path.write_text(text)
PY

"$AEROSPACE" reload-config
