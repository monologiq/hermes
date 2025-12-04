#!/usr/bin/env bash

set -euo pipefail

echo "Choose a password for root:"
passwd

useradd -m -U \
  -G wheel,audio,i2c,video,input,network \
  -c "$FULL_NAME" \
  -s /bin/zsh $MAIN_USER

echo "Choose a password for $MAIN_USER:"
passwd "$MAIN_USER"

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
locale-gen
systemctl enable systemd-timesyncd.service

pacman -Sy --noconfirm --needed \
    base \
    base-devel \
    linux \
    linux-firmware \
    linux-headers \
    btrfs-progs \
    iptables-nft \
    intel-ucode \
    pacman-contrib \
    man-db \
    man-pages \
    texinfo \
    dhcpcd \
    git \
    rsync \
    i2c-tools \
    lm_sensors \
    openrgb \
    zsh \
    zsh-completions \
    bash-completion \
    zram-generator \
    systemd-ukify \
    mkinitcpio \
    terminus-font \
    tpm2-tss \
    sbctl \
    fwupd \
    openssh \
    acpid \
    avahi

systemctl enable \
  acpid \
  avahi-daemon \
  sshd \
  fwupd \
  dhcpcd \
  systemd-resolved


# Boot

LUKS_UUID=$(blkid -s UUID -o value "${DISK_SYSTEM}p3")

mkdir -p /efi/EFI/Linux
bootctl --esp-path=/efi --boot-path=/boot install

pacman -S --noconfirm \
    nvidia-open-dkms \
    nvidia-settings \
    nvidia-utils \
    libva-nvidia-driver \
    intel-media-driver \
    libva-utils \
    vpl-gpu-rt \
    libvdpau-va-gl \
    vulkan-icd-loader \
    vulkan-intel \
    nvidia-prime \
    vulkan-tools \
    vdpauinfo \
    lib32-vulkan-intel \
    lib32-nvidia-utils \
    lib32-vulkan-icd-loader \
    bluez \
    bluez-utils \
    ddcutil \
    iwd

systemctl enable \
  iwd \
  bluetooth

bootctl status
bootctl list

echo ""
echo "Installation finished."
echo ""
echo "Unmount and reboot:"
echo "umount -R /mnt && systemctl --firmware reboot"
echo ""
echo "After reboot:"
echo "Clear Secure Boot keys and set it up to Windows."