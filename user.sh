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
    *) echo "Unknown option: ${OPTKEY}"; usage; exit 1;;
  esac
done
shift $((OPTIND-1))

ssh_dest="$1"
ssh_opts=(
 -o ControlMaster=auto
 -o ControlPath=~/.ssh/%C
 -o ControlPersist=60
 "$ssh_dest"
)

source lib/file.sh
source lib/dir.sh
source lib/cmd.sh
source .env
source colors.sh

remote_host=$(ssh "${ssh_opts[@]}" uname -n)
known_hosts=( kangaroo hippo )

while  [[ " ${known_hosts[*]} " != *" ${remote_host} "* ]]; do
  echo "Unknown host name: ${remote_host}"
  read -rp "Set a new host name: " remote_host
done

c sudo hostnamectl set-hostname --static "$remote_host"

c dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-\$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-\$(rpm -E %fedora).noarch.rpm"

c dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
c dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
c dnf swap -y ffmpeg-free ffmpeg --allowerasing

c dnf install -y \
  ripgrep \
  neovim \
  fzf \
  nodejs \
  shellcheck \
  gimp \
  inkscape \
  blender \
  steam

c npm install -g \
  bash-language-server \
  typescript-language-server \
  svelte-language-server \
  prettier

f root root 644 /etc/hosts

d root root 700 /root/.ssh
f root root 644 /root/.ssh/authorized_keys
f root root 600 /root/.ssh/id_ed25519
f root root 644 /root/.ssh/id_ed25519.pub

d root root 755 /usr/lib64/firefox/
f root root 644 /usr/lib64/firefox/firefox.cfg
d root root 755 /usr/lib64/firefox/defaults/
d root root 755 /usr/lib64/firefox/defaults/pref
f root root 644 /usr/lib64/firefox/defaults/pref/autoconfig.js

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys
f adam adam 600 /home/adam/.ssh/id_ed25519
f adam adam 644 /home/adam/.ssh/id_ed25519.pub
d adam adam 755 /home/adam/.bashrc.d
f adam adam 644 /home/adam/.bashrc.d/overrides
d adam adam 755 /home/adam/.config/git
f adam adam 644 /home/adam/.config/git/config
d adam adam 755 /home/adam/.config/nvim
f adam adam 644 /home/adam/.config/nvim/init.lua
d adam adam 755 /home/adam/.config/ripgrep
f adam adam 644 /home/adam/.config/ripgrep/ripgreprc

ssh "${ssh_opts[@]}" bash -c "'$REMOTE_SCRIPT'"

