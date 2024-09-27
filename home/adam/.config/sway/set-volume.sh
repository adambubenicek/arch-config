#!/usr/bin/env bash

wpctl set-volume @DEFAULT_SINK@ "$1"

volume="$(wpctl get-volume @DEFAULT_SINK@ \
  | awk '{ print $2 * 100 }')"

notify-send \
  "Volume: $volume%" \
  -t 2000 \
  -h string:x-canonical-private-synchronous:volume \
  -h "int:value:$volume"

