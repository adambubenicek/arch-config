#!/usr/bin/env bash

cd "$(dirname "$0")" || exit

REMOTE_SCRIPT=''
FILE_ENABLED=true
DIR_ENABLED=true
CMD_ENABLED=false

usage() {
  echo "Usage: $0 [-ch] destination"
  echo ""
  echo "Options:"
  echo "  -h  Show this help"
  echo "  -c  Enable running commads"
}

while getopts "ch" option; do
  case "$option" in
    c) CMD_ENABLED=true;;
    h) usage; exit 0;;
    *) echo "Unknown option ${OPTKEY}"; usage; exit 1;;
  esac
done
shift $((OPTIND-1))

source lib/file.sh
source lib/dir.sh
source lib/cmd.sh
source .env
source colors.sh

ssh_opts=(
 -o ControlMaster=auto
 -o ControlPath=~/.ssh/%C
 -o ControlPersist=60
 "$1"
)

remote_host=$(ssh "${ssh_opts[@]}" uname -n)
known_hosts=( kangaroo hippo )

while  [[ " ${known_hosts[*]} " != *" ${remote_host} "* ]]; do
  echo "Unknown host name: ${remote_host}"
  read -rp "Set a new host name: " remote_host
done

c sudo hostnamectl set-hostname --static "$remote_host"

c dnf install -y ripgrep neovim fzf
d root root 755 /usr/lib64/firefox/
f root root 644 /usr/lib64/firefox/firefox.cfg
d root root 755 /usr/lib64/firefox/defaults/
d root root 755 /usr/lib64/firefox/defaults/pref
f root root 644 /usr/lib64/firefox/defaults/pref/autoconfig.js

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys
d adam adam 755 /home/adam/.bashrc.d
f adam adam 644 /home/adam/.bashrc.d/overrides
d adam adam 755 /home/adam/.config/git
f adam adam 644 /home/adam/.config/git/config
d adam adam 755 /home/adam/.config/nvim
f adam adam 644 /home/adam/.config/nvim/init.lua
d adam adam 755 /home/adam/.config/ripgrep
f adam adam 644 /home/adam/.config/ripgrep/ripgreprc

ssh "${ssh_opts[@]}" bash -c "'$REMOTE_SCRIPT'"

