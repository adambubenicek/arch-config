#!/usr/bin/env bash

set -uea
shopt -s globstar dotglob
source .env

ssh_args=(
  -o ControlPath=$XDG_RUNTIME_DIR/ssh-%C
  -o ControlMaster=auto 
  -o ControlPersist=60
)

function confirm() {
  local prompt="$1"
  local answer
  local result

  while true; do
    read -p "$prompt [yn]" answer

    case "$answer" in
      y|Y) result=0; break;;
      n|N) result=1; break;;
      *) continue;; 
    esac
  done
}

function cmd() {
  local force=false
  local user="root"
  local ssh_user
  local ssh_command

  # Parse options
  while true; do
    case "$1" in
      --user=*) user="${1#*=}"; shift;;
      --user) user="adam"; shift;;
      --force) force=true; shift;;
      *) break;;
    esac
  done

  # Check if command should be run during this boot.
  if [[ " ${cmd_boots[*]} " != *" $boot "* && "$force" == false ]]; then
    # Nothing to do, exit early.
    return 0 
  fi


  if [[ "$boot" == "install" ]]; then
    ssh_user="root"
    ssh_command="$@"

    if [[ "$user" != "$ssh_user" ]]; then
      echo "Only root can be used to execute commands during install."
      exit 1
    fi 
  fi

  if [[ "$boot" == "install-chroot" ]]; then
    ssh_user="root"

    if [[ "$user" == "$ssh_user" ]]; then
      ssh_command="arch-chroot /mnt $@"
    else
      ssh_command="arch-chroot -u $user /mnt $@"
    fi 
  fi

  if [[ "$boot" == "first" || "$boot" == "regular" ]]; then
    ssh_user="adam"

    if [[ "$user" == "$ssh_user" ]]; then
      ssh_command="$@"
    elif [[ "$user" == "root" ]]; then
      ssh_command="sudo $@"
    else
      ssh_command="sudo -u $user $@"
    fi 
  fi

  ssh ${ssh_args[@]} "$ssh_user@$ssh_host" "$ssh_command"
}

function file() {
  local force=false
  local user="root"
  local template=false
  local mode=644
  local owner
  local group

  # Parse options
  while true; do
    case "$1" in
      --user=*) user="${1#*=}"; shift;;
      --user) user="adam"; shift;;
      --mode=*) mode="${1#*=}"; shift;;
      --owner=*) owner="${1#*=}"; shift;;
      --group=*) group="${1#*=}"; shift;;
      --template) template=true; shift;;
      --force) force=true; shift;;
      *) break;;
    esac
  done

  # Check if file should be installed during this boot.
  if [[ " ${file_boots[*]} " != *" $boot "* && "$force" == false ]]; then
    # Nothing to do, exit early.
    return 0 
  fi

  owner="${owner:-$user}"
  group="${group:-$user}"
  cmd_args=( --user="$user" --force )

  local path="$1"
  local local_copy_path="$(mktemp)"

  if [[ "$template" == true ]]; then
    envsubst < *$host*"$path" > "$local_copy_path"
  else
    cat *$host*"$path" > "$local_copy_path"
  fi

  # Check if file already exists on remote.
  if cmd ${cmd_args[@]} test -f "$path"; then
    local remote_copy_path="$(mktemp)"
    local remote_stat=( $(cmd ${cmd_args[@]} stat -c \'%a %U %G\' "$path") )

    cmd ${cmd_args[@]} "cat $path" > "$remote_copy_path"
    
    if ! diff --color "$remote_copy_path" "$local_copy_path"; then
      if confirm "Overwrite changes?"; then
        cmd ${cmd_args[@]} "tee $path >/dev/null" < "$local_copy_path"
      fi
    fi

    if [[ "${remote_stat[0]}" != "$mode" ]]; then
      if confirm "Change mode of $path from ${remote_stat[0]} to $mode?"; then
        cmd ${cmd_args[@]} chmod "$mode" "$path"
      fi
    fi

    if [[ "${remote_stat[1]}" != "$owner" ]]; then
      if confirm "Change owner of $path from ${remote_stat[1]} to $owner?"; then
        cmd ${cmd_args[@]} chown "$owner" "$path"
      fi
    fi

    if [[ "${remote_stat[2]}" != "$group" ]]; then
      if confirm "Change group of $path from ${remote_stat[2]} to $group?"; then
        cmd ${cmd_args[@]} chown "$group" "$path"
      fi
    fi

    rm "$remote_copy_path"
  else
    cmd ${cmd_args[@]} "tee $path >/dev/null" < "$local_copy_path"
    cmd ${cmd_args[@]} "chmod $mode $path"
    cmd ${cmd_args[@]} "chown $owner $path"
    cmd ${cmd_args[@]} "chgrp $group $path"
  fi

  rm "$local_copy_path"
}

function dir() {
  local force=false
  local user="root"
  local mode=755
  local owner
  local group

  # Parse options
  while true; do
    case "$1" in
      --user=*) user="${1#*=}"; shift;;
      --user) user="adam"; shift;;
      --mode=*) mode="${1#*=}"; shift;;
      --owner=*) owner="${1#*=}"; shift;;
      --group=*) group="${1#*=}"; shift;;
      --force) force=true; shift;;
      *) break;;
    esac
  done

  # Check if file should be installed during this boot.
  if [[ " ${dir_boots[*]} " != *" $boot "* && "$force" == false ]]; then
    # Nothing to do, exit early.
    return 0 
  fi

  owner="${owner:-$user}"
  group="${group:-$user}"
  cmd_args=( --user="$user" --force )

  local path="$1"

  # Check if directory already exists on remote.
  if cmd ${cmd_args[@]} test -d "$path"; then
    local remote_stat=( $(cmd ${cmd_args[@]} stat -c \'%a %U %G\' "$path") )

    if [[ "${remote_stat[0]}" != "$mode" ]]; then
      if confirm "Change mode of $path from ${remote_stat[0]} to $mode?"; then
        cmd ${cmd_args[@]} chmod "$mode" "$path"
      fi
    fi

    if [[ "${remote_stat[1]}" != "$owner" ]]; then
      if confirm "Change owner of $path from ${remote_stat[1]} to $owner?"; then
        cmd ${cmd_args[@]} chown "$owner" "$path"
      fi
    fi

    if [[ "${remote_stat[2]}" != "$group" ]]; then
      if confirm "Change group of $path from ${remote_stat[2]} to $group?"; then
        cmd ${cmd_args[@]} chown "$group" "$path"
      fi
    fi
  else
    cmd ${cmd_args[@]} "mkdir -p $path"
    cmd ${cmd_args[@]} "chmod $mode $path"
    cmd ${cmd_args[@]} "chown $owner $path"
    cmd ${cmd_args[@]} "chgrp $group $path"
  fi

}

function sync() {
  local host=$1
  local boot=$2
  local ssh_host=$3

  # Installation
  cmd_boots=( install )
  file_boots=( install )
  dir_boots=( install )

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
  cmd_boots=( install-chroot )
  file_boots=( install-chroot first regular )
  dir_boots=( install-chroot first regular )

  # Fstab
  file /etc/fstab

  # Hostname
  file /etc/hostname

  # Pacman
  file /etc/pacman.conf
  cmd pacman -Syu

  # Utilities
  cmd pacman -S \
    man-db \
    tree

  # Drivers and microcode
  cmd pacman -S \
    mesa \
    libva-mesa-driver \
    vulkan-radeon \
    lib32-vulkan-radeon \
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
  file --mode=755 /boot/loader/loader.conf
  file --mode=755 /boot/loader/entries/arch.conf

  # Initramfs
  file /etc/mkinitcpio.conf.d/systemd.conf
  cmd mkinitcpio -P

  # Sudo
  cmd pacman -S sudo
  file --mode=440 /etc/sudoers.d/wheel

  # User
  # TODO automate adding password
  cmd useradd -m -G wheel adam

  # Polkit
  cmd pacman -S polkit

  # SSH
  cmd pacman -S openssh
  cmd systemctl enable sshd.service

  dir --user --mode=700 /home/adam/.ssh
  file --template --mode=644 --user /home/adam/.ssh/authorized_keys

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    file --template --mode=600 --user /home/adam/.ssh/id_ed25519
    file --template --mode=644 --user /home/adam/.ssh/id_ed25519.pub
  fi


  # Boot
  cmd_boots=( first )
  file_boots=( first regular )
  dir_boots=( first regular )

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

    dir /usr/lib/firefox/defaults/pref
    file /usr/lib/firefox/defaults/pref/autoconfig.js
  fi
}

sync kangaroo install 10.98.217.93
