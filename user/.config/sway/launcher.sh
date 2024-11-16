#!/usr/bin/env bash

declare -A actions
actions=(
  ["Capture screen to file"]='grim'
  ["Capture region to file"]='grim -g "$(slurp)"'
  ["Capture screen"]='grim - | wl-copy -t image/png'
  ["Capture region"]='grim -g "$(slurp)" - | wl-copy -t image/png'
  ["Firefox"]='firefox'
  ["Foot"]='foot'
  ["Gimp"]='gimp'
  ["Inkscape"]='inkscape'
  ["Steam"]='steam'
  ["Suspend"]='systemctl suspend'
  ["Reboot"]='systemctl reboot'
  ["Poweroff"]='systemctl poweroff'
  ["Lock"]='swaylock -f'
)

printf '%s\n' "${!actions[@]}" 

selected=$(printf '%s\n' "${!actions[@]}" | sort | fzf --print-query --border=none | tail -1)

if [[ -n "$selected" ]]; then
  swaymsg exec "${actions[$selected]:-$selected}"
fi

