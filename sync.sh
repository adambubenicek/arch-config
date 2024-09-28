#!/usr/bin/env bash
set -ue
cd "$(dirname "$0")" || exit

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
    echo ensure_file "$dest_path" "./$src_path"
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
    echo ensure_dir "$dest_path" "$mode"
    echo ensure_attributes "$dest_path" "$mode" "$owner" "$group"
  } >> "$sync_dir/remote.sh"
}

function c() {
  if [[ " ${c_boots[*]} " != *" $boot "* ]]; then
    return 0 
  fi

  echo "run_command $*" >> "$sync_dir/remote.sh"
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
  sync_dir="$(mktemp -d)"

  cp remote.sh "$sync_dir/remote.sh"

  # Installation
  c_boots=( install )
  f_boots=( install )
  d_boots=( install )

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    dev=/dev/nvme0n1
    dev_root_part=/dev/nvme0n1p2
    dev_boot_part=/dev/nvme0n1p1
  elif [[ $host == "owl" ]]; then
    dev=/dev/sda
    dev_root_part=/dev/sda2
    dev_boot_part=/dev/sda1
  fi


  c sgdisk --clear "$dev" \
    --new=1:0:+1024M \
    --typecode=1:ef00 \
    --new=2:0:0 \
    --typecode=2:8304 # 8309 for LUKS

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    d /etc/cryptsetup-keys.d -m 750
    f /etc/cryptsetup-keys.d/root.key -t -m 440

    c cryptsetup luksFormat \
      --key-file=/etc/cryptsetup-keys.d/root.key \
      --label=root-crypt
      "$dev_root_part" 
    dev_root_part=/dev/mapper/root
  fi

  c mkfs.fat -F 32 -n boot "$dev_boot_part"
  c mkfs.ext4 -L root "$dev_root_part"
  c mount "$dev_root_part" /mnt
  c mount --mkdir "$dev_boot_part" /mnt/boot

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
    ripgrep \
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

  f /etc/fstab -t
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

  if [[ $host == "hippo" || $host == "kangaroo" ]]; then
    f /etc/sysctl.d/overrides.conf

    f /etc/crypttab -m 440
    f /etc/crypttab.initramfs -m 440
    d /etc/cryptsetup-keys.d -m 750
    f /etc/cryptsetup-keys.d/pigeon.key -t -m 440
    f /etc/cryptsetup-keys.d/turtle.key -t -m 440
  fi

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
  d /home/adam/.config/ripgrep -o adam
  f /home/adam/.config/ripgrep/ripgreprc -o adam

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
      i3status \
      foot \
      mpv \
      firefox \
      sway \
      swaybg \
      swayidle \
      swaylock \
      libnotify \
      mako

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
    f /home/adam/.config/sway/set-volume.sh -m 755 -o adam
    f /home/adam/.config/sway/set-brightness.sh -m 755 -o adam
    d /home/adam/.config/swayidle -o adam
    f /home/adam/.config/swayidle/config -o adam
    d /home/adam/.config/swaylock -o adam
    f /home/adam/.config/swaylock/config -o adam
    d /home/adam/.config/mako -o adam
    f /home/adam/.config/mako/config -o adam
    d /home/adam/.config/i3status -o adam
    f /home/adam/.config/i3status/config -t -o adam
    d /home/adam/.config/foot -o adam
    f /home/adam/.config/foot/foot.ini -o adam
    d /home/adam/.config/mpv -o adam
    f /home/adam/.config/mpv/mpv.conf -o adam
  fi


  # Maintenance
  c_boots=( first regular )
  f_boots=( first regular )
  d_boots=( first regular )

  # Sync
  case "$host" in
    kangaroo) ssh_host="$KANGAROO_HOST";;
    hippo) ssh_host="$HIPPO_HOST";;
    owl) ssh_host="$OWL_HOST";;
  esac

  ssh_opts=(
   -o ControlMaster=auto
   -o ControlPath=/root/.ssh/%C
   -o ControlPersist=60
  )
  remote_sync_dir=$(ssh "${ssh_opts[@]}" "$ssh_host" mktemp -d)
  
  scp "${ssh_opts[@]}" -q "$sync_dir"/* "$ssh_host:$remote_sync_dir" 
  ssh "${ssh_opts[@]}" "$ssh_host" "$remote_sync_dir"/remote.sh || true
  ssh "${ssh_opts[@]}" "$ssh_host" rm -rf "$remote_sync_dir"

  rm -rf "$sync_dir"
done
