#!/bin/sh

# Updated to Markham, ON coordinates
LAT="43.8561"
LON="-79.3370"
URL="https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,weather_code,precipitation&timezone=auto"

DATA=$(curl -s "$URL")

FORECAST=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&hourly=precipitation&forecast_hours=2&timezone=auto&precipitation_unit=mm")

RAIN_NEXT_2HRS=$(echo "$FORECAST" | jq '[.hourly.precipitation[0:2][]] | add')

TEMP=$(echo "$DATA" | jq -r '.current.temperature_2m') # e.g. 20.5 (Celsius)
CODE=$(echo "$DATA" | jq -r '.current.weather_code') # e.g. 2
PRECIP=$(echo "$DATA" | jq -r '.current.precipitation') # e.g. 0.0

# Map WMO code to icon 
case $CODE in
  0) ICON="" ;;      # Clear sky
  1) ICON="" ;;      # Mainly clear
  2) ICON="" ;;      # Partly cloudy
  3) ICON="" ;;      # Overcast
  45|48) ICON="" ;;  # Fog or depositing rime fog
  51|53|55) ICON="" ;;  # Drizzle: Light, moderate, dense
  56|57) ICON="?" ;;      # Freezing drizzle
  61|63|65) ICON="" ;;  # Rain: slight, moderate, heavy
  66|67) ICON="?" ;;      # Freezing rain
  71|73|75) ICON="󰖘" ;;  # Snowfall
  77) ICON="?" ;;         # Snow grains
  80|81|82) ICON="" ;;  # Rain showers
  85|86) ICON="?" ;;      # Snow showers
  95) ICON="󰖓" ;;        # Thunderstorm
  96|99) ICON="?" ;;      # Thunderstorm with hail
  *) ICON="" ;;         # Unknown
esac

# Format temp: round to nearest integer, add degree symbol
TEMP_LABEL="$(printf "%.0f°C" "$TEMP")"

# Only show rain label/color if rain is expected soon
if [ "$(echo "$RAIN_NEXT_2HRS > 0" | bc -l)" -eq 1 ]; then
  # Format the raw decimal to exactly one decimal place
  FORMATTED_RAIN=$(printf "%.1f" "$RAIN_NEXT_2HRS")
  LABEL="$TEMP_LABEL, ${FORMATTED_RAIN} mm"
  
  sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
else
  LABEL="$TEMP_LABEL"
  sketchybar --set "$NAME" icon="$ICON" label="$LABEL"
fi
