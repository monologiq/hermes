#!/usr/bin/env bash

set -euo pipefail

DISK=""
ROOT_NAME="cryptroot"
MOUNT_TARGET=""

if [[ $# -eq 0 ]]; then
  	echo "Error: No options provided"
  	echo "Usage: $0 --disk <disk>"
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

echo "Target disk: $DISK"
echo ""
echo "This will ERASE ALL DATA on $DISK"
echo ""
read -r -p "Continue? (y/n): " confirm
[[ "$confirm" != "y" ]] && { echo "Aborted."; exit 1; }

echo ""
sgdisk --zap-all ${DISK}

# PARTITIONING

# 1. XBOOTLDR partition – 1 GiB
sgdisk -n 1:0:+1GiB \
       -t 1:bc13c2ff-59e6-4262-a352-b275fd6f7172 \
       -c 1:"XBOOTLDR" \
       ${DISK}

# 2. EFI System Partition – 4 GiB
sgdisk -n 2:0:+4GiB \
       -t 2:c12a7328-f81f-11d2-ba4b-00a0c93ec93b \
       -c 2:"EFI" \
       ${DISK}

# 3. LUKS2 root partition – remaining space
sgdisk -n 3:0:0 \
       -t 3:ca7d7ccb-63ed-4c53-861c-1742536059cc \
       -c 3:"ROOT" \
       ${DISK}

sgdisk -p ${DISK}

if [[ $DISK == /dev/nvme* ]]; then
  	DISK="${DISK}p"
fi

# FORMATTING

mkfs.ext4 -L XBOOTLDR "${DISK}1"
mkfs.fat -F32 -n EFI "${DISK}2"
cryptsetup luksFormat --type luks2 "${DISK}3"
cryptsetup open "${DISK}3" "$ROOT_NAME"
mkfs.btrfs -f -L ROOT "/dev/mapper/$ROOT_NAME"

# BTRFS SUBVOLUMES CREATION

mount /dev/mapper/$ROOT_NAME ${MOUNT_TARGET}

btrfs subvolume create ${MOUNT_TARGET}/@root
btrfs subvolume create ${MOUNT_TARGET}/@snapshots
btrfs subvolume create ${MOUNT_TARGET}/@home
btrfs subvolume create ${MOUNT_TARGET}/@var_cache
btrfs subvolume create ${MOUNT_TARGET}/@var_log
btrfs subvolume create ${MOUNT_TARGET}/@var_spool
btrfs subvolume create ${MOUNT_TARGET}/@var_tmp
btrfs subvolume create ${MOUNT_TARGET}/@var_lib_machines
btrfs subvolume create ${MOUNT_TARGET}/@var_lib_portables

btrfs subvolume list ${MOUNT_TARGET}

umount -R ${MOUNT_TARGET}