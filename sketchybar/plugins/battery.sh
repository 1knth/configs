#!/bin/sh

source "$CONFIG_DIR/colors.sh"

PERCENTAGE="$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)"
POWER_SOURCE="$(pmset -g ps | awk -F"'" '/Now drawing from/ { print $2; exit }')"
LOW_POWER_MODE="$(pmset -g | awk '/lowpowermode/ { print $2; exit }')"

if [ "$SENDER" = "power_source_change" ] && [ -n "$INFO" ]; then
  POWER_SOURCE="$INFO"
fi

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

# Green is reserved for the plugged-in AC state. On plug-in, SketchyBar's
# power_source_change event can arrive before pmset reports "charging", so use
# the event's $INFO when available.
if [ "$POWER_SOURCE" = "AC" ] || [ "$POWER_SOURCE" = "AC Power" ]; then
  ICON=""
  COLOR="$GREEN"
elif [ "$PERCENTAGE" -le 20 ]; then
  COLOR="$RED"
elif [ "$LOW_POWER_MODE" = "1" ]; then
  COLOR="$YELLOW"
elif [ "$PERCENTAGE" -le 40 ]; then
  COLOR="$ORANGE"
else
  COLOR="$GLASS_TEXT"
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  label="${PERCENTAGE}%" \
  icon.color="$COLOR" \
  label.color="$COLOR" \
  padding_right=0
