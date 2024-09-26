#!/usr/bin/env bash

set -ue

# shellcheck source=/dev/null
source .env

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
    local script=""

    while IFS= read -r line; do
      if [[ "$line" =~ [^[:space:]]*%%[[:space:]]*(.*)$ ]]; then
        script+="${BASH_REMATCH[1]}"$'\n'
      else
        script+="echo \"${line//\"/\\\"}\""$'\n'
      fi
    done < ".$dest_path"

    eval "$script" > "$sync_dir/$src_path"
  else
    cat ".$dest_path" > "$sync_dir/$src_path"
  fi
  
  {
    echo ensure_content "$dest_path" "./$src_path"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$sync_dir/remote.sh"
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
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$sync_dir/remote.sh"
}

function c() {
  if [[ " ${c_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  echo "$*" >> "$sync_dir/remote.sh"
}

boot=regular
OPTIND=1
while getopts "b:" opt; do
  case "$opt" in
    b) boot=$OPTARG;;
    *) break;;
  esac
done
shift $((OPTIND-1))

if (( "$#" > 0 )); then
  hosts=( "$@" )
else
  hosts=( hippo kangaroo owl )
fi

for host in "${hosts[@]}"; do
  sync_dir="./tmp"
  rm -rf "$sync_dir"
  mkdir "$sync_dir"
  cp remote.sh "$sync_dir/remote.sh"

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
    --password \'"$ADAM_PASSWORD_ENCRYPTED"\' \
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
  f /home/adam/.config/vim/vimrc -t -o adam

  c sudo -u adam curl -fLo ~/.config/vim/autoload/plug.vim --create-dirs \
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

  pushd "$sync_dir" >/dev/null

  case "$host" in
    kangaroo) ssh_host="$KANGAROO_HOST";;
    hippo) ssh_host="$HIPPO_HOST";;
    owl) ssh_host="$OWL_HOST";;
  esac

  tar -c . | ssh -T "root@$ssh_host" '
    dir="$(mktemp -d)"
    pushd "$dir" >/dev/null
    tar -x
    source ./remote.sh
    popd >/dev/null
    rm -rf "$dir"'
  popd >/dev/null
done
