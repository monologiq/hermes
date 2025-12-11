#!/usr/bin/env bash

sudo sbctl create-keys
sudo sbctl enroll-keys -m
sudo mkinitcpio -P
sudo sbctl sign /efi/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign /efi/EFI/systemd/systemd-bootx64.efi
sudo sbctl status
sudo sbctl verify
