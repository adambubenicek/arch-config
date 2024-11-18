#!/usr/bin/env bash


usage() {
  echo "Usage: $0 [OPTION]"
  echo ""
  echo "Options:"
  echo "  -u, --user-only      only run tasks for current user"
  echo "  -f, --files-only     only sync files"
  echo "  -c, --commands-only  only run commands"
  echo "  -h, --help           show this help"
}


user_only=false
files_only=false
commands_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user-only|-u) user_only=true; shift;;
    --files-only|-f) files_only=true; shift;;
    --commands-only|-c) files_only=true; shift;;
    --help|-h) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

files_enabled=true
commands_enabled=true

if [[ "$files_only" == true ]]; then
  commands_enabled=false
fi

if [[ "$commands_only" == true ]]; then
  files_enabled=false
fi


_run() {
  local command="$*"

  if [[ "$run_as" != "$USER" ]]; then
    command="sudo -u $run_as $command"
  fi

  eval "$command"
}


cmd() {
  [[ "$commands_enabled" != true ]] && return 0
  [[ "$user_only" == true && "$run_as" != "$USER" ]] && return 0

  local command="$*"

  if [[ -t 1 ]]; then
    echo "Running: $command"
  fi
  _run "$command"
}


file() {
  [[ "$files_enabled" != true ]] && return 0
  [[ "$user_only" == true && "$run_as" != "$USER" ]] && return 0

  local dest="$1"
  local src="$2"
  local tmp

  tmp="$(_run mktemp)"

  _run cat "$src" | while IFS= read -r line; do
    while [[ "$line" =~ ^(.*)\{\{[[:space:]]*([a-zA-Z0-9_]*)[[:space:]]*\}\}(.*)$ ]]; do
      local var="${BASH_REMATCH[2]}"
      line="${BASH_REMATCH[1]}${!var//\\n/$'\n'}${BASH_REMATCH[3]}"
    done

    echo "$line"
  done | _run dd status=none of="$tmp"

  if ! _run test -f "$dest"; then
    echo "Creating file: $dest"
    _run cp "$tmp" "$dest"
  else
    if ! _run diff --color "$dest" "$tmp"; then
      echo "File has changed: $dest"

      local answer
      read -rp "Overwrite? [Y/n] " answer
      if [[ "$answer" == "" || "$answer" =~ ^[Yy]$ ]]; then
        _run cp "$tmp" "$dest"
      fi
    else
      echo "File has not changed: $dest"
    fi
  fi

  _run rm "$tmp"
}


known_hosts=( kangaroo hippo )
host=$(hostnamectl --static)

if [[ " ${known_hosts[*]} " != *" $host "* ]]; then
  echo "Unknown host name: $host"
  echo ""
  echo "Select a one of the known host names: "
  select host in "${known_hosts[@]}"; do
    break
  done
fi


eval "$(sops decrypt .common.env)"

if [[ "$host" == "hippo" ]]; then
  eval "$(sops decrypt .hippo.env)"
fi


run_as="root"

cmd hostnamectl hostname "$host"

cmd dnf install -y \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

cmd dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
cmd dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
cmd dnf swap -y ffmpeg-free ffmpeg --allowerasing

cmd dnf install -y \
  ripgrep \
  fd-find \
  neovim \
  nodejs \
  shellcheck \
  gimp \
  inkscape \
  blender \
  steam \
  alacritty \
  wireguard-tools

cmd npm install -g \
  bash-language-server \
  typescript-language-server \
  svelte-language-server \
  prettier

cmd mkdir -p /usr/lib64/firefox/defaults/pref
file /usr/lib64/firefox/defaults/pref/autoconfig.js firefox/autoconfig.js
file /usr/lib64/firefox/firefox.cfg firefox/firefox.cfg

file /etc/udev/rules.d/overrides.rules udev/overrides.rules
file /etc/wireguard/wg0.conf wireguard/wg0.conf
cmd chmod /etc/wireguard/wg0.conf

cmd systemctl enable --now wg-quick@wg0


run_as="$USER"

(
  tmp=$(cmd mktemp)

  cmd curl -o "$tmp" -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.tar.xz

  cmd mkdir -p ~/.local/share/fonts
  cmd tar -xJf "$tmp" -C ~/.local/share/fonts

  cmd rm "$tmp"
)

cmd mkdir -p ~/.bashrc.d/
file ~/.bashrc.d/overrides.sh bash/overrides.sh

cmd mkdir -p ~/.config/nvim
file ~/.config/nvim/init.lua nvim/init.lua

cmd mkdir -p ~/.config/alacritty
file ~/.config/alacritty/alacritty.toml alacritty/alacritty.toml

cmd mkdir -p ~/.config/git
file ~/.config/git/config git/config

cmd mkdir -p ~/.ssh
cmd chmod 700 ~/.ssh
file ~/.ssh/id_ed25519 ssh/id_ed25519
cmd chmod 600 ~/.ssh/id_ed25519

file ~/.ssh/id_ed25519.pub ssh/id_ed25519.pub
file ~/.ssh/authorized_keys ssh/authorized_keys


