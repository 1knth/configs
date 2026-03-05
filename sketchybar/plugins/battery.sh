#!/bin/sh

source "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
CHARGING="$(pmset -g batt | grep 'AC Power')"

if [ "$PERCENTAGE" = "" ]; then
  exit 0
fi

case "${PERCENTAGE}" in
  9[0-9]|100) ICON=""
  ;;
  [6-8][0-9]) ICON=""
  ;;
  [3-5][0-9]) ICON=""
  ;;
  [0-2][0-9]) ICON=""
  ;;
  *) ICON=""
esac

# Check charging status first
if [[ "$CHARGING" != "" ]]; then
  ICON=""
  COLOR="$GREEN"
else
  # Only apply percentage colors if NOT charging
  if [ "$PERCENTAGE" -le 30 ]; then
    COLOR="$RED"
  elif [ "$PERCENTAGE" -le 40 ]; then
    COLOR="$ORANGE"
  else
    COLOR="$WHITE"
  fi
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  label="${PERCENTAGE}%" \
  icon.color="$COLOR" \
  label.color="$COLOR" \
  padding_right=0
