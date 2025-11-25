#!/bin/bash

set -e

# Function to list available disks
list_disks() {
    echo "Available disks:"
    lsblk -d -n -o NAME,SIZE,MODEL | grep -E "^(sd|nvme|vd)" | nl -w2 -s') '
}

# Function to get disk path from selection
get_disk_path() {
    local selection=$1
    local disk_name=$(lsblk -d -n -o NAME | grep -E "^(sd|nvme|vd)" | sed -n "${selection}p")
    echo "/dev/${disk_name}"
}

echo ""
list_disks
echo ""
read -p "Select SYSTEM disk (enter number): " system_choice
DISK_SYSTEM=$(get_disk_path "$system_choice")

if [ -z "$DISK_SYSTEM" ] || [ ! -b "$DISK_SYSTEM" ]; then
    echo "Error: Invalid disk selection"
    exit 1
fi

echo "System disk: $DISK_SYSTEM"
echo ""

list_disks
echo ""
read -p "Select HOME disk (enter number, or same as system): " home_choice
DISK_HOME=$(get_disk_path "$home_choice")

if [ -z "$DISK_HOME" ] || [ ! -b "$DISK_HOME" ]; then
    echo "Error: Invalid disk selection"
    exit 1
fi

echo "Home disk: $DISK_HOME"
echo ""

SAME_DISK=false
if [ "$DISK_SYSTEM" == "$DISK_HOME" ]; then
    SAME_DISK=true
fi

if [[ "$DISK_SYSTEM" == *"nvme"* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

if [[ "$DISK_HOME" == *"nvme"* ]]; then
    HOME_PART_SUFFIX="p"
else
    HOME_PART_SUFFIX=""
fi

# Set partition variables
PART_XBOOTLDR="${DISK_SYSTEM}${PART_SUFFIX}1"
PART_EFI="${DISK_SYSTEM}${PART_SUFFIX}2"
PART_ROOT="${DISK_SYSTEM}${PART_SUFFIX}3"

if [ "$SAME_DISK" = false ]; then
    PART_HOME="${DISK_HOME}${HOME_PART_SUFFIX}1"
else
    PART_HOME="${DISK_SYSTEM}${PART_SUFFIX}3"
fi

# Set mount target
read -p "Enter mount target directory [/mnt]: " MOUNT_TARGET
MOUNT_TARGET=${MOUNT_TARGET:-/mnt}

echo ""
echo "Mount target: $MOUNT_TARGET"
echo ""

# Btrfs mount options
BTRFS_OPTS="compress=zstd,noatime"

# Mount root filesystem
echo "Mounting root filesystem..."
mount --mkdir -o subvol=@system,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET"

mount --mkdir -o fmask=0137,dmask=0027 "$PART_EFI" "$MOUNT_TARGET/efi"
mount --mkdir -o fmask=0137,dmask=0027 "$PART_XBOOTLDR" "$MOUNT_TARGET/boot"

mount --mkdir -o subvol=@var-cache,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/cache"
mount --mkdir -o subvol=@var-log,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/log"
mount --mkdir -o subvol=@var-tmp,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/tmp"
mount --mkdir -o subvol=@var-docker,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/lib/docker"
mount --mkdir -o subvol=@var-machines,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/lib/machines"
mount --mkdir -o subvol=@var-portables,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/var/lib/portables"

mount --mkdir -o subvol=@snapshots,$BTRFS_OPTS "$PART_ROOT" "$MOUNT_TARGET/.snapshots"

mount --mkdir -o subvol=@home,$BTRFS_OPTS "$PART_HOME" "$MOUNT_TARGET/home"

echo ""
findmnt -R "$MOUNT_TARGET" -o TARGET,SOURCE,FSTYPE,OPTIONS
echo ""
echo "All partitions mounted successfully!"
echo ""
