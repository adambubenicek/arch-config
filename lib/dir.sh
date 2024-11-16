#!/usr/bin/env bash

dremote() {
  path="$1"
  mode="$2"

  if [[ ! -d "$path" ]]; then
    set -x
    mkdir "$path"
    set +x
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    set -x
    chmod "$mode" "$path"
    set +x
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

