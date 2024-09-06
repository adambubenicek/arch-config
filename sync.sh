#!/usr/bin/env bash

set -ue

ssh_args=(
  -o ControlPath=$XDG_RUNTIME_DIR/ssh-%C
  -o ControlMaster=auto 
  -o ControlPersist=60
)

function rdo() {
  local user=adam
  if [[ $stage == install ]]; then
    user=root
  fi

  ssh ${ssh_args[@]} $user@$ip $@
}

function sync() {
  local host=$1
  local ip=10.98.217.93
  local stage=install

  if [[ $stage == install ]]; then
    rdo sgdisk --clear /dev/nvme0n1 \
      --new=1:0:+1024M \
      --typecode=1:ef00 \
      --new=2:0:0 \
      --typecode=2:8304 # 8309 for LUKS

    rdo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
    rdo mkfs.ext4 -L root /dev/nvme0n1p2

    rdo mount /dev/nvme0n1p2 /mnt
    rdo mount --mkdir /dev/nvme0n1p1 /mnt/boot

    rdo pacstrap -K /mnt \
      rsync \
      openssh \
      polkit \
      base \
      linux \
      linux-firmware \
      iptables-nft \
      mkinitcpio \
      amd-ucode

    rdo arch-chroot /mnt groupadd adam -g 1000
    rdo arch-chroot /mnt useradd adam -u 1000 -g 1000 -m -G wheel

    systemd-ask-password "Password for user 'adam'" \
      | rdo passwd --root /mnt --stdin adam
  fi

  mkdir tmp
  cp -r *$host*/* tmp
  chmod 0440 tmp/etc/sudoers.d/wheel

  chmod 0700 tmp/home/adam
  chmod 0700 tmp/home/adam/.ssh

  if [[ $stage == install ]]; then
    rsync -rpv -e "ssh ${ssh_args[*]}" --exclude="/home/adam" tmp/ root@$ip:/mnt
    rsync -rpv -e "ssh ${ssh_args[*]}" --chown=1000:1000 tmp/home/adam/ root@$ip:/mnt/home/adam
  else
    rsync -rpv -e "ssh ${ssh_args[*]}" --exclude="/home/adam" --rsync-path="sudo /usr/bin/rsync" tmp/ adam@$ip:/
    rsync -rpv -e "ssh ${ssh_args[*]}" tmp/home/adam/ adam@$ip:/home/adam
  fi

  rm -rf tmp

  if [[ $stage == install ]]; then
    rdo arch-chroot /mnt locale-gen
    rdo arch-chroot /mnt bootctl install
    rdo arch-chroot /mnt mkinitcpio -P
    rdo arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
    rdo ln -sf ../run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf

    rdo arch-chroot /mnt systemctl enable systemd-timesyncd.service
    rdo arch-chroot /mnt systemctl enable systemd-boot-update.service
    rdo arch-chroot /mnt systemctl enable systemd-networkd.service
    rdo arch-chroot /mnt systemctl enable systemd-resolved.service
    rdo arch-chroot /mnt systemctl enable sshd.service
  fi
}

sync kangaroo
