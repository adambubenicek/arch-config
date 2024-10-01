#!/usr/bin/env bash
cd "$(dirname "$0")" || exit

function ensure_file() {
  local path="$1"
  local content_path="$2"

  if [[ ! -f "$path" ]]; then
    echo "Creating file '$path'"
  elif ! cmp -s "$path" "$content_path"; then
    echo "Updating file '$path'"
    diff --color=always "$path" "$content_path"
  fi

  run_command quiet cat "$content_path" \> "$path"
}

function ensure_dir() {
  local path="$1"
  local mode="$2"

  if [[ ! -d "$path" ]]; then
    echo "Creating directory '$path'"
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
    echo "Changing mode of '$path' from '$existing_mode' to '$mode'"
    run_command quiet chmod "$mode" "$path"
  fi

  if [[ "$owner" != "$existing_owner" ]]; then
    echo "Changing owner of '$path' from '$existing_owner' to '$owner'"
    run_command quiet chown "$owner" "$path"
  fi

  if [[ "$group" != "$existing_group" ]]; then
    echo "Changing group of '$path' from '$existing_group' to '$group'"
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
    echo "Running '$command'" 
  fi

  while ! eval "$command"; do
    while true; do
      echo -n "Running '$command' failed, continue? [Yn]: " 
      read -r answer
      case "$answer" in
        Y|y|'') break 2;;
        N|n) exit 1;;
        *) continue;;
      esac
    done
  done
}
