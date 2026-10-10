##!/bin/bash
#if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
#  sketchybar --set "$NAME" background.drawing=off label.color=0xffffffff
#else
#  sketchybar --set "$NAME" background.drawing=off label.color=0x88ffffff
#fi
#
#  background.color=0x30ffffff

#!/bin/bash

source "$CONFIG_DIR/colors.sh"

FOCUSED_WORKSPACE="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"
NONEMPTY_WORKSPACES="$(aerospace list-workspaces --monitor all --empty no 2>/dev/null)"

if ! echo "$NONEMPTY_WORKSPACES" | grep -qx "$1" && [ "$1" != "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "$NAME" \
    drawing=on \
    background.drawing=off \
    label.color="$WHITE"
else
  sketchybar --set "$NAME" \
    drawing=on \
    background.drawing=off \
    label.color="$INACTIVE_WORKSPACE"
fi
