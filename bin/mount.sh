#!/usr/bin/env bash

set -euo pipefail

DISK=""
MOUNT_TARGET=""
ROOT_NAME="cryptroot"

if [[ $# -eq 0 ]]; then
  	echo "Error: No options provided"
  	echo "Usage: $0 --disk <disk> --mount <path>"
  	exit 1
fi

while [[ $# -gt 0 ]]; do
  case $1 in
    --disk)
      DISK="$2"
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

if [[ -z "$MOUNT_TARGET" ]]; then
    echo "Error: --mount is required"
    exit 1
fi

if [[ $DISK == /dev/nvme* ]]; then
    DISK="${DISK}p"
fi

# MOUNTING WITH SUBVOLUMES

if [[ ! -e /dev/mapper/$ROOT_NAME ]]; then
    echo "Opening encrypted partition..."
    cryptsetup open "${DISK}3" cryptroot
fi

BTRFS_OPTS="compress=zstd,noatime"

mount -o subvol=@root,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}

# Mount boot partitions
mount --mkdir "${DISK}1" ${MOUNT_TARGET}/boot
mount --mkdir -o fmask=0137,dmask=0027 "${DISK}2" ${MOUNT_TARGET}/efi

# Mount other subvolumes
mount --mkdir -o subvol=@snapshots,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/.snapshots
mount --mkdir -o subvol=@home,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/home
mount --mkdir -o subvol=@nix,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/nix
mount --mkdir -o subvol=@var_cache,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/cache
mount --mkdir -o subvol=@var_log,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/log
mount --mkdir -o subvol=@var_spool,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/spool
mount --mkdir -o subvol=@var_tmp,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/tmp
mount --mkdir -o subvol=@var_lib_machines,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/lib/machines
mount --mkdir -o subvol=@var_lib_portables,$BTRFS_OPTS /dev/mapper/cryptroot ${MOUNT_TARGET}/var/lib/portables

chattr +C ${MOUNT_TARGET}/nix

findmnt ${MOUNT_TARGET}
