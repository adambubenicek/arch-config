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
    read -p "$prompt [Yn] " answer

    case "$answer" in
      y|Y|'') result=0; break;;
      n|N) result=1; break;;
      *) continue;; 
    esac
  done

  return $result
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
  local dest_path="$1"
  local src_path=".$dest_path"

  if [[ ! -f "$src_path" ]]; then
    src_path="$(dirname "$src_path")/*$host*/$(basename $src_path)"
  fi

  local src_copy_path="$(mktemp)"
  chmod 600 "$src_copy_path"

  if [[ "$template" == true ]]; then
    cat $src_path | envsubst > "$src_copy_path"
  else
    cat $src_path > "$src_copy_path"
  fi

  # Check if file already exists on remote.
  if cmd ${cmd_args[@]} test -f "$dest_path"; then
    local dest_copy_path="$(mktemp)"
    chmod 600 "$dest_copy_path"

    local remote_stat=( $(cmd ${cmd_args[@]} stat -c \'%a %U %G\' "$dest_path") )

    cmd ${cmd_args[@]} "cat $dest_path" > "$dest_copy_path"
    
    if ! diff --color "$dest_copy_path" "$src_copy_path"; then
      if confirm "Overwrite changes?"; then
        cmd ${cmd_args[@]} "tee $dest_path >/dev/null" < "$src_copy_path"
      fi
    fi

    if [[ "${remote_stat[0]}" != "$mode" ]]; then
      if confirm "Change mode of $dest_path from ${remote_stat[0]} to $mode?"; then
        cmd ${cmd_args[@]} chmod "$mode" "$dest_path"
      fi
    fi

    if [[ "${remote_stat[1]}" != "$owner" ]]; then
      if confirm "Change owner of $dest_path from ${remote_stat[1]} to $owner?"; then
        cmd ${cmd_args[@]} chown "$owner" "$dest_path"
      fi
    fi

    if [[ "${remote_stat[2]}" != "$group" ]]; then
      if confirm "Change group of $dest_path from ${remote_stat[2]} to $group?"; then
        cmd ${cmd_args[@]} chown "$group" "$dest_path"
      fi
    fi

    rm "$dest_copy_path"
  else
    cmd ${cmd_args[@]} "tee $dest_path >/dev/null" < "$src_copy_path"
    cmd ${cmd_args[@]} "chmod $mode $dest_path"
    cmd ${cmd_args[@]} "chown $owner $dest_path"
    cmd ${cmd_args[@]} "chgrp $group $dest_path"
  fi

  rm "$src_copy_path"
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

  local dest_path="$1"

  # Check if directory already exists on remote.
  if cmd ${cmd_args[@]} test -d "$dest_path"; then
    local remote_stat=( $(cmd ${cmd_args[@]} stat -c \'%a %U %G\' "$dest_path") )

    if [[ "${remote_stat[0]}" != "$mode" ]]; then
      if confirm "Change mode of $dest_path from ${remote_stat[0]} to $mode?"; then
        cmd ${cmd_args[@]} chmod "$mode" "$dest_path"
      fi
    fi

    if [[ "${remote_stat[1]}" != "$owner" ]]; then
      if confirm "Change owner of $dest_path from ${remote_stat[1]} to $owner?"; then
        cmd ${cmd_args[@]} chown "$owner" "$dest_path"
      fi
    fi

    if [[ "${remote_stat[2]}" != "$group" ]]; then
      if confirm "Change group of $dest_path from ${remote_stat[2]} to $group?"; then
        cmd ${cmd_args[@]} chown "$group" "$dest_path"
      fi
    fi
  else
    cmd ${cmd_args[@]} "mkdir -p $dest_path"
    cmd ${cmd_args[@]} "chmod $mode $dest_path"
    cmd ${cmd_args[@]} "chown $owner $dest_path"
    cmd ${cmd_args[@]} "chgrp $group $dest_path"
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
  file --template /etc/hostname

  # Pacman
  file /etc/pacman.conf
  cmd pacman -Syu --noconfirm

  # Utilities
  cmd pacman -S --noconfirm \
    man-db \
    tree \
    rsync \

  # Drivers and microcode
  cmd pacman -S --noconfirm \
    mesa \
    libva-mesa-driver \
    vulkan-radeon \
    lib32-vulkan-radeon \
    amd-ucode

  # Network
  file /etc/systemd/network/90-dhcp.network
  cmd systemctl enable systemd-networkd.service

  # DNS
  cmd systemctl enable systemd-resolved.service

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
  file /etc/vconsole.conf

  cmd mkinitcpio -P

  # Sudo
  cmd pacman -S --noconfirm sudo
  file --mode=440 /etc/sudoers.d/wheel

  # User
  cmd useradd \
    --create-home \
    --groups wheel \
    --password \'"$user_password_encrypted"\' \
    adam

  # Polkit
  cmd pacman -S --noconfirm polkit

  # SSH
  cmd pacman -S --noconfirm openssh
  cmd systemctl enable sshd.service

  dir --user --mode=700 /home/adam/.ssh
  file --template --mode=644 --user /home/adam/.ssh/authorized_keys

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    file --template --mode=600 --user /home/adam/.ssh/id_ed25519
    file --template --mode=644 --user /home/adam/.ssh/id_ed25519.pub
  fi

  if [[ $host == "kangaroo" ]]; then
    # Wifi
    cmd pacman -S --noconfirm iwd
    cmd systemctl enable iwd.service

    # Power management
    cmd pacman -S --noconfirm tlp
    cmd systemctl enable tlp.service
  fi


  # Boot
  cmd_boots=( first )
  file_boots=( first regular )
  dir_boots=( first regular )

  # DNS
  cmd ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  # Bash
  file --user /home/adam/.bashrc 

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    # Git
    cmd pacman -S --noconfirm git
    dir --user /home/adam/.config/git
    file --user /home/adam/.config/git/config

    # Vim
    cmd pacman -S --noconfirm \
      shellcheck \
      bash-language-server \
      vim \
      fzf

    dir --user /home/adam/.config/vim
    file --user /home/adam/.config/vim/vimrc

    cmd --user curl -fLo ~/.config/vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    # Desktop
    cmd pacman -S --noconfirm \
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
      xdg-desktop-portal-wlr

    # Sway
    cmd pacman -S --noconfirm sway swaybg
    dir --user /home/adam/.config/sway
    file --user /home/adam/.config/sway/config

    # i3status-rust
    cmd pacman -S --noconfirm i3status-rust
    dir --user /home/adam/.config/i3status-rust
    file --user /home/adam/.config/i3status-rust/config.toml

    # Foot
    cmd pacman -S --noconfirm foot
    dir --user /home/adam/.config/foot
    file --user /home/adam/.config/foot/foot.ini

    # Keyd
    cmd pacman -S --noconfirm keyd
    cmd systemctl enable keyd
    file /etc/keyd/default.conf

    # Mpv
    cmd pacman -S --noconfirm mpv

    dir --user /home/adam/.config/mpv
    file --user /home/adam/.config/mpv/mpv.conf

    # Firefox
    cmd pacman -S --noconfirm firefox

    dir /usr/lib/firefox/
    file /usr/lib/firefox/firefox.cfg

    dir /usr/lib/firefox/defaults/pref
    file /usr/lib/firefox/defaults/pref/autoconfig.js

    # GTK
    cmd --user gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
  fi
}

sync kangaroo first 10.98.217.99
# sync kangaroo install-chroot 10.98.217.93
# sync kangaroo first 10.98.217.93
# sync kangaroo regular 10.98.217.93
