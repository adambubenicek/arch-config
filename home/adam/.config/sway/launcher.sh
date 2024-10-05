#!/usr/bin/env bash

declare -A actions
actions=(
  ["Screenshot to file"]='grim'
  ["Screenshot (region) to file"]='grim -g "$(slurp)"'
  ["Screenshot"]='grim - | wl-copy -t image/png'
  ["Screenshot (region)"]='grim -g "$(slurp)" - | wl-copy -t image/png'
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

selected=$(printf '%s\n' "${!actions[@]}" | sort | fzf --print-query | tail -1)

if [[ -n "$selected" ]]; then
  swaymsg exec "${actions[$selected]:-$selected}"
fi

