#!/usr/bin/env bash

set -ue

ssh_args=(
  -o ControlPath=$XDG_RUNTIME_DIR/ssh-%C
  -o ControlMaster=auto 
  -o ControlPersist=60
)

function rdo() {
  local user=root
  if [[ $1 == --user ]]; then
    user_name=adam
    shift
  fi

  ssh ${ssh_args[@]} $user@$ip $@
}

function sync() {
  local host=$1
  local ip=10.98.217.93
  local stage=install
  local prefix=/

  if [[ $stage == install ]]; then
    prefix=/mnt/
    rdo sgdisk --clear /dev/nvme0n1 \
      --new=1:0:+1024M \
      --typecode=1:ef00 \
      --new=2:0:0 \
      --typecode=2:8304 # 8309 for LUKS

    rdo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
    rdo mkfs.ext4 -L root /dev/nvme0n1p2

    rdo mount /dev/nvme0n1p2 $prefix
    rdo mount --mkdir /dev/nvme0n1p1 $prefix/boot

    rdo pacstrap -K $prefix base linux linux-firmware amd-ucode

    rdo arch-chroot $prefix pacman -S --noconfirm sudo

    rdo arch-chroot $prefix groupadd adam -g 1000
    rdo arch-chroot $prefix useradd adam -u 1000 -g 1000 -m -G wheel

    systemd-ask-password "Password for user 'adam'" \
      | rdo passwd --root $prefix --stdin adam
  fi

  sudo mkdir tmp
  sudo cp -r *$host*/* tmp
  sudo chmod 0440 tmp/etc/sudoers.d/wheel

  sudo chmod 0700 tmp/home/adam
  sudo chown -R 1000:1000 tmp/home/adam
  sudo chmod 0700 tmp/home/adam/.ssh

  sudo rsync -rpgoIv -e "sudo -u adam ssh ${ssh_args[*]}" tmp/ root@$ip:$prefix
  sudo rm -rf tmp

  if [[ $stage == install ]]; then
    rdo arch-chroot $prefix locale-gen
    rdo arch-chroot $prefix bootctl install
    rdo arch-chroot $prefix mkinitcpio -P
    rdo arch-chroot $prefix ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
    rdo ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

    rdo arch-chroot $prefix systemctl enable \
      systemd-timesyncd.service \
      systemd-boot-update.service \
      systemd-networkd.service \
      systemd-resolved.service

    rdo arch-chroot $prefix pacman -S --noconfirm openssh
    rdo arch-chroot $prefix systemctl enable sshd.service
  fi
}

sync kangaroo
