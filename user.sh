#!/usr/bin/env bash

cd "$(dirname "$0")" || exit

LOCAL_PREFIX=''
REMOTE_SCRIPT=''
REMOTE_PREFIX=''
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

ssh_dest="${1:-localhost}"
ssh_opts=(
 -o ControlMaster=auto
 -o ControlPath=~/.ssh/%C
 -o ControlPersist=60
 "$ssh_dest"
)

source lib/file.sh
source lib/dir.sh
source lib/cmd.sh
source colors.sh

remote_host=$(ssh "${ssh_opts[@]}" uname -n)
remote_user=$(ssh "${ssh_opts[@]}" 'echo $USER')
remote_home=$(ssh "${ssh_opts[@]}" 'echo $HOME')

known_hosts=( kangaroo hippo )

while  [[ " ${known_hosts[*]} " != *" ${remote_host} "* ]]; do
  echo "Unknown host name: ${remote_host}"
  read -rp "Set a new host name: " remote_host
done


if [[ "$remote_user" == "root" ]]; then
  source root.env

  LOCAL_PREFIX="./root"

  c hostnamectl set-hostname --static "$remote_host"

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
    steam \
    celluloid

  c npm install -g \
    bash-language-server \
    typescript-language-server \
    svelte-language-server \
    prettier

  f /etc/hosts

  d /root/.ssh 700
  f /root/.ssh/authorized_keys
  f /root/.ssh/id_ed25519 600
  f /root/.ssh/id_ed25519.pub

  d /usr/lib64/firefox/
  f /usr/lib64/firefox/firefox.cfg
  d /usr/lib64/firefox/defaults/
  d /usr/lib64/firefox/defaults/pref
  f /usr/lib64/firefox/defaults/pref/autoconfig.js

  f /etc/udev/rules.d/logitech-bolt.rules
fi


if [[ "$remote_user" != "root" ]]; then
  source user.env

  LOCAL_PREFIX="./user"
  REMOTE_PREFIX="$remote_home"

  d .ssh 700
  f .ssh/authorized_keys
  f .ssh/id_ed25519 600
  f .ssh/id_ed25519.pub
  d .bashrc.d
  f .bashrc.d/overrides
  d .config/git
  f .config/git/config
  d .config/nvim
  f .config/nvim/init.lua
  d .config/ripgrep
  f .config/ripgrep/ripgreprc

  c gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  c gsettings set org.gnome.desktop.input-sources xkb-options "\"['caps:escape', 'ctrl:swap_ralt_rctl', 'ctrl:swap_lalt_lctl_lwin']\""
  c gsettings set org.gnome.Ptyxis.Shortcuts move-next-tab "'<Control>Tab'"
  c gsettings set org.gnome.Ptyxis.Shortcuts move-previous-tab "'<Shift><Control>Tab'"

  c gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true
  c gsettings set io.github.celluloid-player.Celluloid mpv-options '--hwdec=auto'

fi

ssh "${ssh_opts[@]}" bash -c "'$REMOTE_SCRIPT'"
