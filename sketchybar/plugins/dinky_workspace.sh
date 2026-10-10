#!/bin/bash

source "$CONFIG_DIR/colors.sh"

DINKY=/Applications/dinky.app/Contents/MacOS/dinky
WORKSPACE="${NAME#dinky.}"
FOCUSED_WORKSPACE=$("$DINKY" list-workspaces --focused 2>/dev/null)

if [ "$WORKSPACE" = "$FOCUSED_WORKSPACE" ]; then
  COLOR="$WHITE"
else
  COLOR="$INACTIVE_WORKSPACE"
fi

sketchybar --set "$NAME" \
  label="$WORKSPACE" \
  label.color="$COLOR" \
  drawing=on
