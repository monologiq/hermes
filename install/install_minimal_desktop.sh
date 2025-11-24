#!/usr/bin/env bash

set -e

pacman -S --needed --noconfirm \
       networkmanager \
       bluez \
       bluez-utils \
       pipewire \
       pipewire-pulse \
       pipewire-alsa \
       pipewire-jack \
       wireplumber \
       gst-plugin-pipewire \
       geoclue \
       wl-clipboard \
       libimobiledevice

curl -sS https://downloads.1password.com/linux/keys/1password.asc | gpg --import
git clone https://aur.archlinux.org/1password.git /tmp/1password
cd /tmp/1password && makepkg -si

git clone https://aur.archlinux.org/1password.git /tmp/apple-fonts
cd /tmp/apple-fonts && makepkg -si


mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi_backend.conf <<NMCONF
[device]
wifi.backend=iwd
NMCONF

systemctl enable NetworkManager

