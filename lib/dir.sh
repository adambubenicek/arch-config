#!/usr/bin/env bash

dremote() {
  owner="$1"
  group="$2"
  mode="$3"
  path="$4"

  if [[ ! -d "$path" ]]; then
    cremote mkdir "$path"
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    cremote chmod "$mode" "$path"
  fi

  if [[ $(stat -c "%U" "$path") != "$owner" ]]; then
    echo "Changing owner: $path $owner"
    cremote chown "$owner" "$path"
  fi

  if [[ $(stat -c "%G" "$path") != "$group" ]]; then
    echo "Changing group: $path $owner"
    cremote chgrp "$group" "$path"
  fi
}

d() {
  if [[ "$DIR_ENABLED" == true ]]; then
    REMOTE_SCRIPT+="dremote $*"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f dremote)"$'\n'
