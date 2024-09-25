#!/usr/bin/env bash

set -uea

source .env

function ensure_content() {
  if ! cmp -s "$1" "$2"; then
    echo "Updating file '$1'"
    diff --color "$1" "$2"
    # cat "$2" > "$1"
  fi
}

function ensure_dir() {
  if [[ ! -d "$1" ]]; then
    echo "Creating directory '$1'"
    # mkdir --mode="$2" "$1"
  fi
}

function ensure_mode() {
  local mode
  mode="$(stat -c '%a' "$1")"

  if [[ "$mode" != "$2" ]]; then
    echo "Changing mode of '$1' from '$mode' to '$2'"
    # chmod "$2" "$1"
  fi
}

function ensure_owner() {
  local owner
  owner="$(stat -c '%U' "$1")"

  if [[ "$owner" != "$2" ]]; then
    echo "Changing owner of '$1' from '$owner' to '$2'"
    # chown "$2" "$1"
  fi
}

function ensure_group() {
  local group
  group="$(stat -c '%G' "$1")"

  if [[ "$group" != "$2" ]]; then
    echo "Changing group of '$1' from '$group' to '$2'"
    # chgrp "$2" "$1"
  fi
}

function f() {
  if [[ " ${f_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  local src_path
  local dest_path
  local template
  local mode
  local owner
  local group

  src_path="$(uuidgen)" 
  dest_path="$1"
  shift

  OPTIND=1
  while getopts "tm:o:g:" opt; do
    case "$opt" in
      t) template=true;;
      m) mode=$OPTARG;;
      o) owner=$OPTARG;;
      g) group=$OPTARG;;
      *) break;;
    esac
  done

  template=${template:-false}
  mode=${mode:-644}
  owner=${owner:-root}
  group=${group:-$owner}

  if [[ "$template" == true ]]; then
    local script_path
    script_path="$(mktemp)"

    while IFS= read -r line; do
      if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
        echo "${BASH_REMATCH[1]}" >> "$script_path"
      else
        echo "echo \"${line//\"/\\\"}\"" >> "$script_path"
      fi
    done < ".$dest_path"

    /usr/bin/env bash "$script_path" > "$sync_dir/$src_path"
    rm "$script_path"
  else
    cat ".$dest_path" > "$sync_dir/$src_path"
  fi
  
  {
    echo ensure_content "$dest_path" "./$src_path"
    echo ensure_mode "$dest_path" "$mode"
    echo ensure_owner "$dest_path" "$owner"
    echo ensure_group "$dest_path" "$group"
  } >> "$sync_dir/script.sh"
}

function d() {
  if [[ " ${d_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  local dest_path
  local mode
  local owner
  local group

  dest_path="$1"
  shift

  OPTIND=1
  while getopts "m:o:g:" opt; do
    case "$opt" in
      m) mode=$OPTARG;;
      o) owner=$OPTARG;;
      g) group=$OPTARG;;
      *) break;;
    esac
  done

  mode=${mode:-755}
  owner=${owner:-root}
  group=${group:-$owner}

  {
    echo ensure_dir "$dest_path" 
    echo ensure_mode "$dest_path" "$mode"
    echo ensure_owner "$dest_path" "$owner"
    echo ensure_group "$dest_path" "$group"
  } >> "$sync_dir/script.sh"
}

function c() {
  if [[ " ${c_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  echo "$*" >> "$sync_dir/script.sh"
}


boot=regular
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --boot=*) boot="${1#*=}"; shift;;
    *) break;;
  esac
done

if [[ "$#" -gt 0 ]]; then
  hosts=( "$@" )
else
  hosts=( hippo kangaroo owl )
fi

for host in "${hosts[@]}"; do
  sync_dir="./tmp"
  rm -rf "$sync_dir"
  mkdir "$sync_dir"

  {
    declare -f ensure_content
    declare -f ensure_dir
    declare -f ensure_mode
    declare -f ensure_owner
    declare -f ensure_group
  } >> "$sync_dir/script.sh"

  # Installation
  c_boots=( install )
  f_boots=( install )
  d_boots=( install )

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    c sgdisk --clear /dev/nvme0n1 \
      --new=1:0:+1024M \
      --typecode=1:ef00 \
      --new=2:0:0 \
      --typecode=2:8304 # 8309 for LUKS

    c mkfs.fat -F 32 -n boot /dev/nvme0n1p1
    c mkfs.ext4 -L root /dev/nvme0n1p2
    c mount /dev/nvme0n1p2 /mnt
    c mount --mkdir /dev/nvme0n1p1 /mnt/boot
  fi

  if [[ $host == "owl" ]]; then
    c sgdisk --clear /dev/sda \
      --new=1:0:+1024M \
      --typecode=1:ef00 \
      --new=2:0:0 \
      --typecode=2:8304 # 8309 for LUKS

    c mkfs.fat -F 32 -n boot /dev/sda1
    c mkfs.ext4 -L root /dev/sda2
    c mount /dev/sda2 /mnt
    c mount --mkdir /dev/sda1 /mnt/boot
  fi

  c pacstrap -K /mnt \
    base \
    linux \
    linux-firmware \
    iptables-nft \
    mkinitcpio


  # Chroot
  c_boots=( install-chroot )
  f_boots=( install-chroot first regular )
  d_boots=( install-chroot first regular )

  f /etc/pacman.conf

  c pacman -Syu --noconfirm \
    man-db \
    tree \
    rsync \
    mesa \
    libva-mesa-driver \
    vulkan-radeon \
    lib32-vulkan-radeon \
    amd-ucode \
    sudo \
    polkit \
    openssh

  c bootctl install

  f /etc/fstab
  f /etc/hostname -t
  f /etc/systemd/network/90-dhcp.network
  f /etc/locale.gen
  f /etc/locale.conf
  f /boot/loader/loader.conf -m 755
  f /boot/loader/entries/arch.conf -m 755
  f /etc/mkinitcpio.conf.d/overrides.conf
  f /etc/vconsole.conf
  f /etc/sudoers.d/overrides -m 440
  d /root/.ssh -m 700
  f /root/.ssh/authorized_keys -t -m 644

  c locale-gen
  c mkinitcpio -P
  c ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
  c systemctl enable systemd-resolved.service
  c systemctl enable systemd-networkd.service
  c systemctl enable systemd-boot-update.service
  c systemctl enable systemd-timesyncd.service
  c systemctl enable sshd.service
  c useradd \
    --create-home \
    --groups wheel \
    --password \'"$adam_password_encrypted"\' \
    adam

  if [[ $host == "kangaroo" ]]; then
    c pacman -S --noconfirm \
      tlp \
      iwd

    c systemctl enable iwd.service
    c systemctl enable tlp.service
  fi


  # Boot
  c_boots=( first )
  f_boots=( first regular )
  d_boots=( first regular )

  c pacman -S --noconfirm \
    crun \
    podman \
    bash-completion \
    vim \
    git \
    fzf

  c ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  d /home/adam/.ssh -m 700 -o adam
  f /home/adam/.ssh/authorized_keys -t -o adam
  f /home/adam/.bashrc -o adam
  d /home/adam/.config/git -o adam
  f /home/adam/.config/git/config -o adam
  d /home/adam/.config/vim -o adam
  f /home/adam/.config/vim/vimrc -o adam

  c sudo -u adam curl -fLo ~/.config/vim/autoload/plug.vim --create-ds \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    c pacman -S --noconfirm \
      keyd \
      shellcheck \
      bash-language-server \
      brightnessctl \
      noto-fonts \
      noto-fonts-emoji \
      playerctl \
      xorg-xwayland \
      pipewire \
      pipewire-pulse \
      pipewire-jack \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk \
      xdg-desktop-portal-wlr \
      i3status-rust \
      foot \
      mpv \
      firefox \
      sway \
      swaybg \
      swayidle \
      swaylock

    c systemctl enable keyd
    c sudo -u adam gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    f /etc/keyd/default.conf
    f /etc/udev/rules.d/logitech-bolt.rules
    d /usr/lib/firefox/
    f /usr/lib/firefox/firefox.cfg
    d /usr/lib/firefox/defaults/pref
    f /usr/lib/firefox/defaults/pref/autoconfig.js
    f /root/.ssh/id_ed25519 -t -m 600
    f /root/.ssh/id_ed25519.pub -t
    f /home/adam/.ssh/id_ed25519 -t -m 600 -o adam
    f /home/adam/.ssh/id_ed25519.pub -t -o adam
    d /home/adam/.config -o adam
    d /home/adam/.config/sway -o adam
    f /home/adam/.config/sway/config -o adam
    d /home/adam/.config/swayidle -o adam
    f /home/adam/.config/swayidle/config -o adam
    d /home/adam/.config/swaylock -o adam
    f /home/adam/.config/swaylock/config -o adam
    d /home/adam/.config/i3status-rust -o adam
    f /home/adam/.config/i3status-rust/config.toml -o adam
    d /home/adam/.config/foot -o adam
    f /home/adam/.config/foot/foot.ini -o adam
    d /home/adam/.config/mpv -o adam
    f /home/adam/.config/mpv/mpv.conf -o adam
  fi
done
