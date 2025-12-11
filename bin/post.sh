#!/usr/bin/env bash

BASE_DIR=$(pwd)

git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay && makepkg -si && cd $BASE_DIR

yay -S --needed \
    1password \
    1password-cli \
    ttf-dejavu \
    noto-fonts-cjk \
    noto-fonts-emoji \
    firefox \
    wireplumber \
    pipewire-pulse \
    pipewire-alsa \
    pipewire-jack \
    ollama \
    ollama-cuda \
    niri \
    xdg-desktop-portal-gnome
    
