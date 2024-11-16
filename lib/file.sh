#!/usr/bin/env bash

fremote() {
  path="$1"
  mode="$2"
  content_encoded="$3"

  if [[ ! -f "$path" ]]; then
    set -x
    touch "$path"
    set +x
  fi

  if [[ $(stat -c "%a" "$path") != "$mode" ]]; then
    set -x
    chmod "$mode" "$path"
    set +x
  fi

  temp=$(mktemp)
  echo "$content_encoded" | base64 -d > "$temp"
  if ! diff --color=always "$path" "$temp"; then
    set -x
    cp "$temp" "$path"
    set +x
  fi
  rm "$temp"
}

f() {
  if [[ "$FILE_ENABLED" == true ]]; then
    path="$1"
    mode="${2:-644}"

    content=""
    while IFS= read -r line; do
      if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
        content+="${BASH_REMATCH[1]}"$'\n'
      elif [[ "$line" =~ [^[:space:]]*%=[[:space:]]*(.*)$ ]]; then
        content+="echo \"${BASH_REMATCH[1]}\""$'\n'
      else
        content+="echo '${line//\'/\'\"\'\"\'}'"$'\n'
      fi
    done < "$LOCAL_PREFIX/$path"

    content_encoded=$(eval "$content" | base64 --wrap=0)
    REMOTE_SCRIPT+="fremote $REMOTE_PREFIX/$path $mode $content_encoded"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f fremote)"$'\n'
