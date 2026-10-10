#!/bin/zsh
# Toggle JankyBorders.

set -euo pipefail

if pgrep -x borders >/dev/null; then
  killall borders
else
  borders active_color=0xffffffff width=2 order=a
fi
