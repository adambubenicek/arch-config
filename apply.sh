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


# Parse arguments
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


# Sanitize arguments
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


# Find out which host we are
known_hosts=( kangaroo hippo sloth owl )
host=$(hostnamectl --static)

if [[ " ${known_hosts[*]} " != *" $host "* ]]; then
  echo "Unknown host name: $host"
  echo ""
  echo "Select a one of the known host names: "
  select host in "${known_hosts[@]}"; do
    break
  done
fi

# Convenience host checkers
hippo() { [[ "$host" == "hippo" ]]; }
kangaroo() { [[ "$host" == "kangaroo" ]]; }
sloth() { [[ "$host" == "sloth" ]]; }
owl() { [[ "$host" == "owl" ]]; }


# Install sops
if [[ ! -f ~/.local/bin/sops ]]; then
  mkdir -p ~/.local/bin
  architecture="$(uname -m)"

  case "$architecture" in
    x86_64) url=https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.amd64;;
    aarch64) url=https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.arm64;;
  esac

  curl -o ~/.local/bin/sops -L "$url"
  chmod +x ~/.local/bin/sops

  unset architecture url
fi

# Install sops key
if [[ ! -f ~/.config/sops/age/keys.txt ]]; then
  echo "Age keys file not found: ~/.config/sops/age/keys.txt"
  read -r -p "Create it with a key: " key

  mkdir -p ~/.config/sops/age/
  echo "$key" > ~/.config/sops/age/keys.txt
  chmod 600 ~/.config/sops/age/keys.txt
fi

# Decrypt our secrets and export them into the environment
eval "$(sops decrypt .common.env)"
hippo && eval "$(sops decrypt .hippo.env)"
kangaroo && eval "$(sops decrypt .kangaroo.env)"
sloth && eval "$(sops decrypt .sloth.env)"
owl && eval "$(sops decrypt .owl.env)"


# Configure system
run_as="root"

cmd hostnamectl hostname "$host"

cmd dnf install -y \
    wireguard-tools \
    neovim \
    ripgrep \
    podman

if hippo || kangaroo; then
  cmd dnf install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"

  cmd dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld
  cmd dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld
  cmd dnf swap -y ffmpeg-free ffmpeg --allowerasing

  cmd dnf install -y \
    nodejs \
    shellcheck \
    gimp \
    inkscape \
    blender \
    steam \
    alacritty \

  cmd npm install -g \
    bash-language-server \
    typescript-language-server \
    svelte-language-server \
    prettier

  cmd mkdir -p /usr/lib64/firefox/defaults/pref
  file /usr/lib64/firefox/defaults/pref/autoconfig.js firefox/autoconfig.js
  file /usr/lib64/firefox/firefox.cfg firefox/firefox.cfg

  file /etc/udev/rules.d/overrides.rules udev/overrides.rules
fi

if sloth; then
  file /etc/containers/systemd/homeassistant.container containers/homeassistant.container
  file /etc/containers/systemd/qbittorrent.container containers/qbittorrent.container
fi

hippo && file /etc/wireguard/wg0.conf wireguard/hippo/wg0.conf
kangaroo && file /etc/wireguard/wg0.conf wireguard/kangaroo/wg0.conf
sloth && file /etc/wireguard/wg0.conf wireguard/sloth/wg0.conf
owl && file /etc/wireguard/wg0.conf wireguard/owl/wg0.conf
cmd chmod 600 /etc/wireguard/wg0.conf

cmd systemctl enable --now wg-quick@wg0

if sloth; then
  file /etc/wireguard/wg1.conf wireguard/sloth/wg1.conf
  cmd chmod 600 /etc/wireguard/wg1.conf
  cmd systemctl enable --now wg-quick@wg1
fi

file /etc/ssh/sshd_config.d/overrides.conf ssh/sshd/overrides.conf
cmd chmod 600 /etc/ssh/sshd_config.d/overrides.conf


cmd firewall-cmd --set-default-zone=public

cmd firewall-cmd --zone=trusted --add-interface=wg0
cmd firewall-cmd --zone=trusted --add-interface=wg0 --permanent

if owl; then
  cmd firewall-cmd --add-port="$WG0_OWL_PORT/udp"
  cmd firewall-cmd --add-port="$WG0_OWL_PORT/udp" --permanent
fi

# Configure user
run_as="$USER"

if hippo || kangaroo; then
  tmp=$(cmd mktemp)

  cmd curl -o "$tmp" -sL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/JetBrainsMono.tar.xz

  cmd mkdir -p ~/.local/share/fonts
  cmd tar -xJf "$tmp" -C ~/.local/share/fonts

  cmd rm "$tmp"
  unset tmp
fi

cmd mkdir -p ~/.bashrc.d/
file ~/.bashrc.d/overrides.sh bash/overrides.sh

cmd mkdir -p ~/.config/ripgrep
file ~/.config/ripgrep/ripgreprc ripgrep/ripgreprc

cmd mkdir -p ~/.config/nvim
file ~/.config/nvim/init.lua nvim/init.lua

cmd mkdir -p ~/.config/git
file ~/.config/git/config git/config

if hippo || kangaroo; then
  cmd mkdir -p ~/.config/alacritty
  file ~/.config/alacritty/alacritty.toml alacritty/alacritty.toml
fi

cmd mkdir -p ~/.ssh
cmd chmod 700 ~/.ssh
file ~/.ssh/authorized_keys ssh/authorized_keys

if hippo || kangaroo; then
  file ~/.ssh/config ssh/config
fi

if hippo; then
  file ~/.ssh/id_ed25519 ssh/hippo/id_ed25519
  file ~/.ssh/id_ed25519.pub ssh/hippo/id_ed25519.pub
  cmd chmod 600 ~/.ssh/id_ed25519
fi

if kangaroo; then
  file ~/.ssh/id_ed25519 ssh/kangaroo/id_ed25519
  file ~/.ssh/id_ed25519.pub ssh/kangaroo/id_ed25519.pub
  cmd chmod 600 ~/.ssh/id_ed25519
fi
