#!/usr/bin/env bash

brightnessctl set "$1"

brightness="$(brightnessctl get \
  | awk -v max="$(brightnessctl max)" \
  '{ printf "%.0f", $0 / max * 100 }')"

notify-send \
  "Brightness: $brightness%" \
  -t 2000 \
  -h string:x-canonical-private-synchronous:brightness \
  -h "int:value:$brightness"

