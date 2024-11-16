#!/usr/bin/env bash

cremote() {
  echo "> $*"
  "$@"
}

c() {
  if [[ "$CMD_ENABLED" == true ]]; then
    REMOTE_SCRIPT+="cremote $*"$'\n'
  fi
}

REMOTE_SCRIPT+="$(declare -f cremote)"$'\n'
