#!/usr/bin/env bash

fremote() {
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

  temp=$(mktemp)
  echo "$content_encoded" | base64 -d > "$temp"
  if ! diff --color=always "$path" "$temp"; then
    cp "$temp" "$path"
  fi
  rm "$temp"
}

f() {
  if [[ "$FILE_ENABLED" == true ]]; then
    path="$4"

    content=""
    while IFS= read -r line; do
      if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
        content+="${BASH_REMATCH[1]}"$'\n'
      elif [[ "$line" =~ [^[:space:]]*%=[[:space:]]*(.*)$ ]]; then
        content+="echo \"${BASH_REMATCH[1]}\""$'\n'
      else
        content+="echo '${line//\'/\'\"\'\"\'}'"$'\n'
      fi
    done < ".$path"

    content_encoded=$(eval "$content" | base64 --wrap=0)
    REMOTE_SCRIPT+="fremote $* $content_encoded"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f fremote)"$'\n'
