#!/usr/bin/env bash

SCRIPT=$(< remote.sh)
SCRIPT+=$'\n'

f() {
  path="$4"

  script=""
  while IFS= read -r line; do
    if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
      script+="${BASH_REMATCH[1]}"$'\n'
    elif [[ "$line" =~ [^[:space:]]*%=[[:space:]]*(.*)$ ]]; then
      script+="echo \"${BASH_REMATCH[1]}\""$'\n'
    else
      script+="echo '${line//\'/\'\"\'\"\'}'"$'\n'
    fi
  done < ".$path"

  content_encoded=$(eval "$script" | base64 --wrap=0)
  SCRIPT+="f $* $content_encoded"$'\n'
}

d() {
  SCRIPT+="d $*"$'\n'
}

c() {
  SCRIPT+="c $*"$'\n'
}

run() {
  user="$1"
  host="$2"
  ssh "$user@$host" bash -c "'$SCRIPT'"
}
