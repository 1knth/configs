# #!/bin/sh

# # The $NAME variable is passed from sketchybar and holds the name of
# # the item invoking this script:

# sketchybar --set "$NAME" label="$(date +'%a, %b %d %-I:%M %p')" padding_left=0



# SketchyBar passes the name of the triggering item via the $NAME variable

if [ "$NAME" = "clock.date" ]; then
  # Only execute and set the date format if clock.date triggered the script
  sketchybar --set "$NAME" label="$(date +'%a, %b %d')"

elif [ "$NAME" = "clock.time" ]; then
  # Only execute and set the time format if clock.time triggered the script
  sketchybar --set "$NAME" label="$(date +'%-I:%M %p')"
fi