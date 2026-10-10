#!/bin/bash

# Kinetic frames for "GROWTH" / "PLANTER"
FRAMES=("P L A N T E R" "p l a n t e r" ". p l a n t e r ." ".. p l a n t e r ..")
INDEX=$(sketchybar --query kinetic_text | jq -r '.user.index // 0')

# Update text and cycle index
sketchybar --set $NAME label="${FRAMES[$INDEX]}" \
           --set $NAME user.index=$(((INDEX + 1) % ${#FRAMES[@]}))
