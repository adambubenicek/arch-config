#!/usr/bin/env bash

f() {
  owner="$1"
  group="$2"
  mode="$3"
  path="$4"
  content_encoded="$5"

  if [[ ! -f "$path" ]]; then
    echo "Creating file: $path"
    touch "$path"
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    c chmod "$mode" "$path"
  fi

  if [[ $(stat -c "%U" "$path") != "$owner" ]]; then
    echo "Changing owner: $path $owner"
    c chown "$owner" "$path"
  fi

  if [[ $(stat -c "%G" "$path") != "$group" ]]; then
    echo "Changing group: $path $owner"
    c chgrp "$group" "$path"
  fi

  temp=$(mktemp)
  echo "$content_encoded" | base64 -d > "$temp"
  if ! diff --color "$path" "$temp"; then
    cp "$temp" "$path"
  fi
  rm "$temp"

}

d() {
  owner="$1"
  group="$2"
  mode="$3"
  path="$4"

  if [[ ! -d "$path" ]]; then
    c mkdir "$path"
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    c chmod "$mode" "$path"
  fi

  if [[ $(stat -c "%U" "$path") != "$owner" ]]; then
    echo "Changing owner: $path $owner"
    c chown "$owner" "$path"
  fi

  if [[ $(stat -c "%G" "$path") != "$group" ]]; then
    echo "Changing group: $path $owner"
    c chgrp "$group" "$path"
  fi
}

c() {
  echo "$*"
  "$@"
}
