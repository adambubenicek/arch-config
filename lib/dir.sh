#!/usr/bin/env bash

dremote() {
  path="$1"
  mode="$2"

  if [[ ! -d "$path" ]]; then
    cremote mkdir "$path"
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    cremote chmod "$mode" "$path"
  fi
}

d() {
  path="$1"
  mode="${2:-755}"

  if [[ "$DIR_ENABLED" == true ]]; then
    REMOTE_SCRIPT+="dremote $REMOTE_PREFIX/$path $mode"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f dremote)"$'\n'
