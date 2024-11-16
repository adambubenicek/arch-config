#!/usr/bin/env bash

cremote() {
  command_encoded="$1"
  command=$(echo "$command_encoded" | base64 -d)

  set -x
  eval "$command"
  set +x
}

c() {
  command_encoded=$(echo "$*" | base64 --wrap=0)

  if [[ "$CMD_ENABLED" == true ]]; then
    REMOTE_SCRIPT+="cremote $command_encoded"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f cremote)"$'\n'
