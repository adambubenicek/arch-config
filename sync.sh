#!/usr/bin/env bash

set -uea
shopt -s globstar dotglob
source .env

ssh_args=(
  -o ControlPath=$XDG_RUNTIME_DIR/ssh-%C
  -o ControlMaster=auto 
  -o ControlPersist=60
)

function cmd() {
  :
}

function file() {
  :
}

function dir() {
  :
}

function sync() {
  local host=$1
  local stage=$2
  local ip=$3

  # Installation
  cmd_stages=( install )
  file_stages=( install )
  dir_stages=( install )

  # Partition drives
  cmd sgdisk --clear /dev/nvme0n1 \
    --new=1:0:+1024M \
    --typecode=1:ef00 \
    --new=2:0:0 \
    --typecode=2:8304 # 8309 for LUKS

  # Format partitions
  cmd mkfs.fat -F 32 -n boot /dev/nvme0n1p1
  cmd mkfs.ext4 -L root /dev/nvme0n1p2

  # Mount partitions
  cmd mount /dev/nvme0n1p2 /mnt
  cmd mount --mkdir /dev/nvme0n1p1 /mnt/boot

  # Bootstrap system
  cmd pacstrap -K /mnt \
    base \
    linux \
    linux-firmware \
    iptables-nft \
    mkinitcpio


  # Chroot
  cmd_stages=( chroot )
  file_stages=( chroot firstboot regularboot )
  dir_stages=( chroot firstboot regularboot )

  # Fstab
  file /etc/fstab

  # Hostname
  file /etc/hostname

  # Utilities
  cmd pacman -S \
    man-db \
    tree

  # Drivers and microcode
  cmd pacman -S \
    mesa \
    libva-mesa-driver \
    vulcan-radeon \
    lib32-vulcan-radeon \
    amd-ucode

  # Network
  file /etc/systemd/network/90-dhcp.network
  cmd systemctl enable systemd-networkd.service

  # Locale
  file /etc/locale.gen
  file /etc/locale.conf

  cmd locale-gen

  # Timezone
  cmd ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
  cmd systemctl enable systemd-timesyncd.service

  # Bootloader
  cmd bootctl install
  cmd systemctl enable systemd-boot-update.service
  file /boot/loader/loader.conf
  file /boot/loader/entries/arch.conf

  # Initramfs
  file /etc/mkinitcpio.conf.d/systemd.conf
  cmd mkinitcpio -P

  # Sudo
  cmd pacman -S sudo
  file --mode 440 /etc/sudoers.d/wheel

  # User
  # TODO automate adding password
  cmd useradd -m -G wheel adam

  # Polkit
  cmd pacman -S polkit

  # SSH
  cmd pacman -S openssh
  cmd systemctl enable sshd.service

  dir --mode 700 /home/adam/.ssh
  file --template --mode 600 --user /home/adam/.ssh/authorized_keys

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    file --template --mode 600 --user /home/adam/.ssh/id_ed25519
    file --template --mode 644 --user /home/adam/.ssh/id_ed25519.pub
  fi


  # Boot
  cmd_stages=( firstboot )
  file_stages=( firstboot regularboot )
  dir_stages=( firstboot regularboot )

  # DNS
  cmd systemctl enable systemd-resolved.service
  cmd ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    # Git
    cmd pacman -S git
    dir --user /home/adam/.config/git
    file --user /home/adam/.config/git/config

    # Vim
    cmd pacman -S vim fzf
    cmd --user curl -fLo ~/.config/vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    # Sway
    cmd pacman -S \
      noto-fonts \
      noto-fonts-emoji \
      sway \
      sway-bg \
      i3status-rust \
      playerctl \
      xorg-xwayland \
      foot \
      pipewire \
      pipewire-pulse \
      pipewire-jack \
      xdg-desktop-portal \
      xdg-desktop-portal-gtk \
      xdg-desktop-portal-wlr

    # Keyd
    cmd pacman -S keyd
    file /etc/keyd/default.conf

    # Firefox
    cmd pacman -S firefox
    dir /usr/lib/firefox/
    file /usr/lib/firefox/firefox.cfg
    dir /usr/lib/firefox/defaults
    dir /usr/lib/firefox/defaults/pref
    file /usr/lib/firefox/defaults/pref/autoconfig.js
  fi
}

sync kangaroo normal 10.98.217.93
