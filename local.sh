#!/usr/bin/env bash

script=$(< remote.sh)
script+=$'\n'

ssh_opts=(
 -o ControlMaster=auto
 -o ControlPath=~/.ssh/%C
 -o ControlPersist=60
 "$SSH_USER@$SSH_HOST"
)
  
export REMOTE_HOSTNAME
REMOTE_HOSTNAME=$(ssh "${ssh_opts[@]}" uname -n)

f() {
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
  script+="f $* $content_encoded"$'\n'
}

d() {
  script+="d $*"$'\n'
}

c() {
  script+="c $*"$'\n'
}

run() {
  ssh "${ssh_opts[@]}" bash -c "'$script'"
}
