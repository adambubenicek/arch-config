#!/usr/bin/env bash

host=$(hostnamectl --static)

export RESTIC_REPOSITORY=rest:http://10.98.218.23:8000
export RESTIC_PASSWORD

while true; do
  read -r -s -p "Enter password: " RESTIC_PASSWORD
  if restic stats; then
    break
  fi
done

${SHELL}
