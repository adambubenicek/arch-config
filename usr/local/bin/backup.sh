#!/usr/bin/env bash

set -e

ssh_opts=(
 -o AddKeysToAgent=yes
)

rsync_opts=(
  --archive 
  --delete
  --relative
  --backup
  --info='stats1,progress2'
)

ssh "${ssh_opts[@]}" sloth cryptsetup open /dev/disk/by-label/elephant-crypt elephant < /etc/cryptsetup-keys.d/luks.key
ssh "${ssh_opts[@]}" sloth mount --mkdir /dev/mapper/elephant /media/elephant

eval "$(ssh-agent)" >/dev/null

ssh -At "${ssh_opts[@]}" sloth rsync "${rsync_opts[@]}" \
  --backup-dir="/media/elephant/owl.$(date "+%F-%T")" \
  owl:/var/lib/adguard/ \
  owl:/srv/caddy/ \
  owl:/etc/caddy/conf.d/ \
  /media/elephant/owl

ssh -At "${ssh_opts[@]}" sloth rsync "${rsync_opts[@]}" \
  --backup-dir="/media/elephant/sloth.$(date "+%F-%T")" \
  sloth:/var/lib/qbittorrent/ \
  sloth:/var/lib/homeassistant/ \
  /media/elephant/sloth

rsync "${rsync_opts[@]}" \
  --backup-dir="/media/elephant/pigeon.$(date "+%F-%T")" \
  /media/pigeon \
  sloth:/media/elephant/pigeon

ssh "${ssh_opts[@]}" sloth sync
ssh "${ssh_opts[@]}" sloth umount /media/elephant
ssh "${ssh_opts[@]}" sloth cryptsetup close elephant

ssh-agent -k >/dev/null
