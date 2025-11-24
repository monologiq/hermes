#!/bin/bash

set -e

pacman -S --needed --noconfirm \
    plasma-desktop \
    sddm \
    konsole \
    dolphin \
    kate \
    ark \
    spectacle \
    gwenview \
    okular \
    kcalc \
    kwalletmanager \
    kwallet-pam \
    plasma-nm \
    plasma-pa \
    bluedevil \
    powerdevil \
    kscreen \
    plasma-systemmonitor \
    plasma-disks \
    kde-gtk-config \
    breeze-gtk \
    xdg-desktop-portal-kde \
    packagekit-qt6 \
    flatpak \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    wireplumber \
    gst-plugin-pipewire \
    geoclue \
    wl-clipboard

# TODO: use the configuration from the repository
mkdir -p /etc/geoclue/conf.d
cat > /etc/geoclue/conf.d/99-beacondb.conf <<GEOCLUE
[wifi]
enable=true
url=https://api.beacondb.net/v1/geolocate
GEOCLUE

systemctl enable sddm

echo "Reboot to start using Plasma Desktop"
