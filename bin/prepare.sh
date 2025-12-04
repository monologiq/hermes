#!/usr/bin/env bash

set -euo pipefail

DISK=""
FULL_NAME=""
MAIN_USER=""
MOUNT_TARGET=""

if [[ $# -eq 0 ]]; then
  	echo "Error: No options provided"
  	echo "Usage: $0 --disk <disk> --full-name <name> --main-user <user> --mount <path>"
  	exit 1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --disk)
      DISK="$2"
      shift 2
      ;;
    --full-name)
      FULL_NAME="$2"
      shift 2
      ;;
    --main-user)
      MAIN_USER="$2"
      shift 2
      ;;
    --mount)
      MOUNT_TARGET="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$DISK" ]]; then
  	echo "Error: --disk is required"
  	exit 1
fi

if [[ -z "$FULL_NAME" ]]; then
  	echo "Error: --full-name is required"
  	exit 1
fi

if [[ -z "$MAIN_USER" ]]; then
  	echo "Error: --main-user is required"
  	exit 1
fi

if [[ -z "$MOUNT_TARGET" ]]; then
  	echo "Error: --mount is required"
  	exit 1
fi

if [[ $DISK == /dev/nvme* ]]; then
    DISK="${DISK}p"
fi

if ! mountpoint -q ${MOUNT_TARGET}; then
    echo "Error: ${MOUNT_TARGET} is not mounted!"
    echo "Run ./mount.sh first"
    exit 1
fi

pacstrap -K ${MOUNT_TARGET} \
    base \
    base-devel \
    linux \
    linux-firmware \
    linux-headers \
    btrfs-progs \
    iptables-nft \
    dhcpcd \
    git \
    rsync \
    man-db \
    man-pages \
    texinfo \
    pacman-contrib \
    systemd-ukify \
    mkinitcpio \
    less

genfstab -U ${MOUNT_TARGET} >> ${MOUNT_TARGET}/etc/fstab

echo "# /dev/mapper/cryptroot LABEL=ROOT" >> ${MOUNT_TARGET}/etc/fstab
echo "tmpfs   /tmp         tmpfs   rw,nodev,nosuid,size=32G          0  0" >> ${MOUNT_TARGET}/etc/fstab


LUKS_UUID=$(blkid -s UUID -o value "${DISK}3")

mkdir -p $MOUNT_TARGET/tmp/install

echo "export FULL_NAME=$FULL_NAME" >> $MOUNT_TARGET/tmp/install/env.sh
echo "export MAIN_USER=$MAIN_USER" >> $MOUNT_TARGET/tmp/install/env.sh
echo "export LUKS_UUID=$LUKS_UUID" >> $MOUNT_TARGET/tmp/install/env.sh
echo "export DISK=$DISK" >> $MOUNT_TARGET/tmp/install/env.sh
echo "export MOUNT_TARGET=$MOUNT_TARGET" >> $MOUNT_TARGET/tmp/install/env.sh
chmod +x $MOUNT_TARGET/tmp/install/env.sh

cp minimal_install.sh $MOUNT_TARGET/tmp/install
chmod +x $MOUNT_TARGET/tmp/minimal_install.sh