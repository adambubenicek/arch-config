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
files_only=false
commands_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
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


cmd() {
  [[ "$commands_enabled" != true ]] && return 0

  local command="$*"

  if [[ -t 1 ]]; then
    echo "Running: $command"
  fi
  eval "$command"
}

template() {
  [[ "$files_enabled" != true ]] && return 0

  local dest="$1"
  local src="$2"
  local tmp
  local content

  tmp="$(mktemp)"

  content=$(envsubst < "$src")
  content=${content//\\n/$'\n'} # Replace escaped new lines with literal ones
  echo "$content" > "$tmp"

  file "$dest" "$tmp"

  rm "$tmp"
}

file() {
  [[ "$files_enabled" != true ]] && return 0

  local dest="$1"
  local src="$2"

  if ! test -f "$dest"; then
    echo "Creating file: $dest"
    cp "$src" "$dest"
  else
    if ! diff --color "$dest" "$src"; then
      echo "File has changed: $dest"

      local answer
      read -rp "Overwrite? [Y/n] " answer
      if [[ "$answer" == "" || "$answer" =~ ^[Yy]$ ]]; then
        cp "$src" "$dest"
      fi
    else
      echo "File has not changed: $dest"
    fi
  fi
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
if [[ ! -f /usr/local/bin/sops ]]; then
  if [[ "$USER" != "root" ]]; then
    echo "Sops is not installed, run again as root."
    exit 1
  fi

  mkdir -p /usr/local/bin
  architecture="$(uname -m)"

  case "$architecture" in
    x86_64) url=https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.amd64;;
    aarch64) url=https://github.com/getsops/sops/releases/download/v3.9.1/sops-v3.9.1.linux.arm64;;
  esac

  curl -o /usr/local/bin/sops -L "$url"
  chmod +x /usr/local/bin/sops

  unset architecture url
fi

# Install sops key
if [[ ! -f ~/.config/sops/age/keys.txt ]]; then
  echo "Age keys file not found for user $USER: $HOME/.config/sops/age/keys.txt"
  read -r -p "Create it with a key: " key

  mkdir -p ~/.config/sops/age/
  echo "$key" > ~/.config/sops/age/keys.txt
  chmod 600 ~/.config/sops/age/keys.txt
fi


# Configure system
if [[ "$USER" == "root" ]];then
  eval "$(sops decrypt .sops/root.env)"
  hippo && eval "$(sops decrypt .sops/root.hippo.env)"
  kangaroo && eval "$(sops decrypt .sops/root.kangaroo.env)"
  sloth && eval "$(sops decrypt .sops/root.sloth.env)"
  owl && eval "$(sops decrypt .sops/root.owl.env)"

  cmd hostnamectl hostname "$host"

  hippo && template /etc/hosts hosts/hippo
  kangaroo && template /etc/hosts hosts/kangaroo

  cmd dnf install -y \
      wireguard-tools \
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
      steam

    cmd mkdir -p /usr/lib64/firefox/defaults/pref
    file /usr/lib64/firefox/defaults/pref/autoconfig.js firefox/autoconfig.js
    file /usr/lib64/firefox/firefox.cfg firefox/firefox.cfg

    file /etc/udev/rules.d/overrides.rules udev/overrides.rules

    if [[ ! -f /usr/local/bin/keyd ]]; then
        tmp=$(cmd mktemp -d)
        cmd git clone --branch v2.5.0 --depth 1 https://github.com/rvaiya/keyd/ "$tmp"

        cmd make -C "$tmp"
        cmd make -C "$tmp" install
        cmd rm -rf "$tmp"
    fi

    file /etc/keyd/default.conf keyd/default.conf
    cmd systemctl enable keyd
  fi

  if sloth; then
    file /etc/containers/systemd/homeassistant.container containers/homeassistant.container
    file /etc/containers/systemd/qbittorrent.container containers/qbittorrent.container
  fi

  if owl; then
    file /etc/containers/systemd/adguard.container containers/adguard.container
    file /etc/containers/systemd/caddy.container containers/caddy.container
  fi

  hippo && template /etc/wireguard/wg0.conf wireguard/hippo/wg0.conf
  kangaroo && template /etc/wireguard/wg0.conf wireguard/kangaroo/wg0.conf
  sloth && template /etc/wireguard/wg0.conf wireguard/sloth/wg0.conf
  owl && template /etc/wireguard/wg0.conf wireguard/owl/wg0.conf
  cmd chmod 600 /etc/wireguard/wg0.conf

  cmd systemctl enable --now wg-quick@wg0

  if sloth; then
    template /etc/wireguard/wg1.conf wireguard/sloth/wg1.conf
    cmd chmod 600 /etc/wireguard/wg1.conf
    cmd systemctl enable --now wg-quick@wg1
  fi

  file /etc/ssh/sshd_config.d/overrides.conf ssh/sshd.conf
  cmd chmod 600 /etc/ssh/sshd_config.d/overrides.conf


  cmd firewall-cmd --set-default-zone=public

  cmd firewall-cmd --zone=trusted --add-interface=wg0
  cmd firewall-cmd --zone=trusted --add-interface=wg0 --permanent

  if owl; then
    cmd firewall-cmd --add-port="$WG0_OWL_PORT/udp"
    cmd firewall-cmd --add-port="$WG0_OWL_PORT/udp" --permanent

    cmd firewall-cmd --add-port="80/tcp"
    cmd firewall-cmd --add-port="80/tcp" --permanent

    cmd firewall-cmd --add-port="443/tcp"
    cmd firewall-cmd --add-port="443/tcp" --permanent

    cmd firewall-cmd --add-port="443/udp"
    cmd firewall-cmd --add-port="443/udp" --permanent
  fi
fi

if [[ "$USER" != "root" ]]; then
  eval "$(sops decrypt .sops/user.env)"
  hippo && eval "$(sops decrypt .sops/user.hippo.env)"
  kangaroo && eval "$(sops decrypt .sops/user.kangaroo.env)"
  sloth && eval "$(sops decrypt .sops/user.sloth.env)"
  owl && eval "$(sops decrypt .sops/user.owl.env)"

  if hippo || kangaroo; then
    tmp=$(cmd mktemp)
    cmd curl -Lo "$tmp" https://zed.dev/api/releases/stable/latest/zed-linux-x86_64.tar.gz
    cmd tar -xvf "$tmp" -C ~/.local
    cmd ln -sf ~/.local/zed.app/bin/zed ~/.local/bin/zed
    cmd rm "$tmp"

    cmd cp ~/.local/zed.app/share/applications/zed.desktop ~/.local/share/applications/dev.zed.Zed.desktop
    cmd sed -i "s|Icon=zed|Icon=$HOME/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png|g" ~/.local/share/applications/dev.zed.Zed.desktop
    cmd sed -i "s|Exec=zed|Exec=$HOME/.local/zed.app/libexec/zed-editor|g" ~/.local/share/applications/dev.zed.Zed.desktop

    cmd mkdir -p ~/.config/environment.d
    file ~/.config/environment.d/electron.conf environment/electron.conf
  fi

  cmd mkdir -p ~/.bashrc.d/
  file ~/.bashrc.d/overrides.sh bash/overrides.sh

  cmd mkdir -p ~/.config/git
  template ~/.config/git/config git/config

  cmd mkdir -p ~/.ssh
  cmd chmod 700 ~/.ssh
  template ~/.ssh/authorized_keys ssh/user/authorized_keys

  if hippo || kangaroo; then
    file ~/.ssh/config ssh/config
  fi

  if hippo; then
    template ~/.ssh/id_ed25519 ssh/user/hippo/id_ed25519
    template ~/.ssh/id_ed25519.pub ssh/user/hippo/id_ed25519.pub
    cmd chmod 600 ~/.ssh/id_ed25519
  fi

  if kangaroo; then
    template  ~/.ssh/id_ed25519 ssh/user/kangaroo/id_ed25519
    template ~/.ssh/id_ed25519.pub ssh/user/kangaroo/id_ed25519.pub
    cmd chmod 600 ~/.ssh/id_ed25519
  fi
fi
