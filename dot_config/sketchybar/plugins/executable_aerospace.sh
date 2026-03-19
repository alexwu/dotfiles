#!/usr/bin/env bash

# make sure it's executable with:
# chmod +x ~/.config/sketchybar/plugins/aerospace.sh

# if [ "$1" = "$FOCUSED_WORKSPACE" ]; then
#     sketchybar --set $NAME background.drawing=on
# else
#     sketchybar --set $NAME background.drawing=off
# fi

SID=$1
visible_workspaces=$(aerospace list-workspaces --visible)
visible=$(echo "$visible_workspaces" | grep -q "$SID" && echo "on" || echo "off")

sketchybar --set $NAME icon.highlight=$visible label.highlight=$visible
