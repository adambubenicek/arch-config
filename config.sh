export C_BOOTS
export F_BOOTS
export D_BOOTS

# Installation
C_BOOTS=( install )
F_BOOTS=( install )
D_BOOTS=( install )

if [[ $HOSTNAME == "hippo" || $HOSTNAME == "kangaroo" || $HOSTNAME == "sloth" ]]; then
  dev=/dev/nvme0n1
  dev_root_part=/dev/nvme0n1p2
  dev_boot_part=/dev/nvme0n1p1
elif [[ $HOSTNAME == "owl" ]]; then
  dev=/dev/sda
  dev_root_part=/dev/sda2
  dev_boot_part=/dev/sda1
fi


c sgdisk --clear "$dev" \
  --new=1:0:+1024M \
  --typecode=1:ef00 \
  --new=2:0:0 \
  --typecode=2:8304 # 8309 for LUKS

if [[ $HOSTNAME == "hippo" || $HOSTNAME == "kangaroo" ]]; then
  d root root 750 /etc/cryptsetup-keys.d
  f root root 440 /etc/cryptsetup-keys.d/luks.key

  c cryptsetup luksFormat \
    --key-file=/etc/cryptsetup-keys.d/luks.key \
    --label=root-crypt \
    "$dev_root_part" 

  c cryptsetup open \
    --key-file=/etc/cryptsetup-keys.d/luks.key \
    "$dev_root_part" \
    root

  dev_root_part=/dev/mapper/root
fi

c mkfs.fat -F 32 -n boot "$dev_boot_part"
c mkfs.ext4 -L root "$dev_root_part"
c mount "$dev_root_part" /mnt
c mount --mkdir "$dev_boot_part" /mnt/boot

if [[ $HOSTNAME == "sloth" ]]; then
  c mount --mkdir /dev/disk/by-label/lib /mnt/var/lib
fi

c pacstrap -K /mnt \
  base \
  linux \
  linux-firmware \
  iptables-nft \
  mkinitcpio


# Chroot
C_BOOTS=( install-chroot )
F_BOOTS=( install-chroot first regular )
D_BOOTS=( install-chroot first regular )

f root root 644 /etc/pacman.conf

c pacman -Syu \
  man-db \
  tree \
  ripgrep \
  rsync \
  sudo \
  polkit \
  openssh

if [[ $HOSTNAME == "hippo" || $HOSTNAME == "kangaroo" ]]; then
  c pacman -Syu \
    mesa \
    libva-mesa-driver \
    vulkan-radeon \
    lib32-vulkan-radeon \
    amd-ucode
elif [[ $HOSTNAME == "owl" ]]; then
  c pacman -Syu amd-ucode
elif [[ $HOSTNAME == "sloth" ]]; then
  c pacman -Syu intel-ucode
fi

c bootctl install

f root root 644 /etc/fstab
f root root 644 /etc/hostname
f root root 644 /etc/hosts
f root root 644 /etc/locale.gen
f root root 644 /etc/locale.conf
f root root 755 /boot/loader/loader.conf
f root root 755 /boot/loader/entries/arch.conf
f root root 440 /etc/sudoers.d/overrides
f root root 644 /etc/ssh/sshd_config.d/overrides.conf
d root root 700 /root/.ssh
f root root 644 /root/.ssh/authorized_keys

f root root 644 /etc/systemd/network/90-dhcp.network
f root root 644 /etc/systemd/network/50-wg0.network
f root systemd-network 640 /etc/systemd/network/50-wg0.netdev
if [[ $HOSTNAME == "sloth" ]]; then
  f root root 644 /etc/systemd/network/50-wg1.network
  f root systemd-network 640 /etc/systemd/network/50-wg1.netdev
fi

c locale-gen
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

f root root 644 /etc/mkinitcpio.conf.d/overrides.conf
f root root 644 /etc/vconsole.conf
if [[ $HOSTNAME == "hippo" || $HOSTNAME == "kangaroo" ]]; then
  f root root 644 /etc/sysctl.d/overrides.conf

  f root root 440 /etc/crypttab
  f root root 440 /etc/crypttab.initramfs
  d root root 750 /etc/cryptsetup-keys.d
  f root root 440 /etc/cryptsetup-keys.d/luks.key
fi

c mkinitcpio -P

if [[ $HOSTNAME == "kangaroo" ]]; then
  c pacman -Syu \
    tlp \
    iwd

  c systemctl enable iwd.service
  c systemctl enable tlp.service
fi


# Boot
C_BOOTS=( first )
F_BOOTS=( first regular )
D_BOOTS=( first regular )

c pacman -Syu \
  crun \
  podman \
  bash-completion \
  neovim \
  git \
  fzf

c ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

d adam adam 700 /home/adam/.ssh
f adam adam 644 /home/adam/.ssh/authorized_keys
f adam adam 644 /home/adam/.bashrc
d adam adam 755 /home/adam/.config
d adam adam 755 /home/adam/.config/git
f adam adam 644 /home/adam/.config/git/config
d adam adam 755 /home/adam/.config/nvim
f adam adam 644 /home/adam/.config/nvim/init.lua
d adam adam 755 /home/adam/.config/nvim/colors/
f adam adam 644 /home/adam/.config/nvim/colors/custom.lua
d adam adam 755 /home/adam/.config/ripgrep
f adam adam 644 /home/adam/.config/ripgrep/ripgreprc

if [[ $HOSTNAME == "hippo" || $HOSTNAME == "kangaroo" ]]; then
  f root root 750 /usr/local/bin/backup.sh
  c pacman -Syu \
    keyd \
    shellcheck \
    bash-language-server \
    typescript-language-server \
    prettier \
    nodejs \
    npm \
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
    mako \
    steam \
    gimp \
    inkscape \
    grim \
    slurp \
    wl-clipboard

  c systemctl enable keyd

  f root root 644 /etc/keyd/default.conf
  f root root 644 /etc/udev/rules.d/logitech-bolt.rules
  d root root 755 /usr/lib/firefox/
  f root root 644 /usr/lib/firefox/firefox.cfg
  d root root 755 /usr/lib/firefox/defaults/pref
  f root root 644 /usr/lib/firefox/defaults/pref/autoconfig.js
  f root root 600 /root/.ssh/id_ed25519
  f root root 644 /root/.ssh/id_ed25519.pub
  f adam adam 600 /home/adam/.ssh/id_ed25519
  f adam adam 644 /home/adam/.ssh/id_ed25519.pub
  d adam adam 755 /home/adam/.config
  d adam adam 755 /home/adam/.config/sway
  f adam adam 644 /home/adam/.config/sway/config
  f adam adam 755 /home/adam/.config/sway/launcher.sh
  f adam adam 755 /home/adam/.config/sway/set-volume.sh
  f adam adam 755 /home/adam/.config/sway/set-brightness.sh
  d adam adam 755 /home/adam/.config/swayidle
  f adam adam 644 /home/adam/.config/swayidle/config
  d adam adam 755 /home/adam/.config/swaylock
  f adam adam 644 /home/adam/.config/swaylock/config
  d adam adam 755 /home/adam/.config/mako
  f adam adam 644 /home/adam/.config/mako/config
  d adam adam 755 /home/adam/.config/i3status
  f adam adam 644 /home/adam/.config/i3status/config
  d adam adam 755 /home/adam/.config/foot
  f adam adam 644 /home/adam/.config/foot/foot.ini
  d adam adam 755 /home/adam/.config/mpv
  f adam adam 644 /home/adam/.config/mpv/mpv.conf
fi

d root root 755 /etc/containers
d root root 755 /etc/containers/systemd

if [[ $HOSTNAME == "sloth" ]]; then
  d adam adam 700 /var/lib/qbittorrent
  d adam adam 755 /var/lib/qbittorrent/config
  d adam adam 755 /var/lib/qbittorrent/downloads
  f root root 644 /etc/containers/systemd/qbittorrent.container

  d root root 700 /var/lib/homeassistant
  d root root 755 /var/lib/homeassistant/config
  f root root 644 /etc/containers/systemd/homeassistant.container
fi

c systemctl enable podman-auto-update.service

if [[ $HOSTNAME == "owl" ]]; then
  c pacman -Syu caddy
  c systemctl enable caddy

  f root root 644 /etc/caddy/Caddyfile

  d root root 700 /var/lib/adguard
  d root root 755 /var/lib/adguard/work
  d root root 755 /var/lib/adguard/conf
  f root root 644 /etc/containers/systemd/adguard.container
fi

# Maintenance
C_BOOTS=( first regular )
F_BOOTS=( first regular )
D_BOOTS=( first regular )

