#!/usr/bin/env bash
cd "$(dirname "$0")" || exit

printf -v divider '%80s' '' 
divider="\e[30m${divider// /-}\e[0m"

function ensure_file() {
  local path="$1"
  local content_path="$2"

  if [[ ! -f "$path" ]]; then
    echo -e "$divider"
    echo -e "> Creating file '\e[1;37m$path\e[0m'."
  elif ! cmp -s "$path" "$content_path"; then
    echo -e "$divider"
    echo -e "> Updating file '\e[1;37m$path\e[0m'."
    diff --color=always "$path" "$content_path"
  fi

  run_command quiet cat "$content_path" \> "$path"
}

function ensure_dir() {
  local path="$1"
  local mode="$2"

  if [[ ! -d "$path" ]]; then
    echo -e "$divider"
    echo -e "> Creating directory '\e[1;37m$path\e[0m'."
    run_command quiet mkdir --mode="$mode" "$path"
  fi
}

function ensure_attributes() {
  local path="$1"
  local mode="$2"
  local owner="$3"
  local group="$4"

  local existing
  read -r -a existing < <(stat -c '%a %U %G' "$1")

  local existing_mode="${existing[0]}"
  local existing_owner="${existing[1]}"
  local existing_group="${existing[2]}"

  if [[ "$mode" != "$existing_mode" ]]; then
    echo -e "$divider"
    echo -en "> Changing mode of '\e[1;37m$path\e[0m' "
    echo -en "from '\e[1;37m$existing_mode\e[0m' "
    echo -e "to '\e[1;37m$mode\e[0m'."
    run_command quiet chmod "$mode" "$path"
  fi

  if [[ "$owner" != "$existing_owner" ]]; then
    echo -e "$divider"
    echo -en "> Changing owner of '\e[1;37m$path\e[0m' "
    echo -en "from '\e[1;37m$existing_owner\e[0m' "
    echo -e "to '\e[1;37m$owner\e[0m'."
    run_command quiet chown "$owner" "$path"
  fi

  if [[ "$group" != "$existing_group" ]]; then
    echo -e "$divider"
    echo -en "> Changing group of '\e[1;37m$path\e[0m' "
    echo -en "from '\e[1;37m$existing_group\e[0m' "
    echo -e "to '\e[1;37m$group\e[0m'."
    run_command quiet chgrp "$group" "$path"
  fi
}

function run_command() {
  local quiet=false

  if [[ "$1" == "quiet" ]]; then
    quiet=true
    shift
  fi

  local command="$*"

  if [[ "$quiet" == false ]]; then 
    echo -e "$divider"
    echo -e "> Running '\e[1;37m$command\e[0m'" 
  fi

  while ! eval "$command"; do
    while true; do
      echo -e "$divider"
      echo -en "\e[31m>\e[0m Running '\e[1;37m$command\e[0m' failed. What do? " 
      echo -en "\e[30m[\e[0m"
      echo -en "\e[1ms\e[0mkip"
      echo -en "\e[30m|\e[0m"
      echo -en "\e[1mr\e[0metry"
      echo -en "\e[30m|\e[0m"
      echo -en "\e[1me\e[0mxit"
      echo -en "\e[30m] \e[0m"
      read -r answer
      case "$answer" in
        s|skip) break 2;;
        r|retry) continue 2;;
        e|exit) exit 1;;
      esac
    done
  done
}
