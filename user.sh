#!/usr/bin/env bash
cd "$(dirname "$0")" || exit

source .env
source colors.sh
source ./local.sh

d root root 755 /usr/lib64/firefox/
f root root 644 /usr/lib64/firefox/firefox.cfg
d root root 755 /usr/lib64/firefox/defaults/
d root root 755 /usr/lib64/firefox/defaults/pref
f root root 644 /usr/lib64/firefox/defaults/pref/autoconfig.js

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys

run
