#!/bin/bash

# Disk Partitioning Script using parted
# WARNING: This will DESTROY all data on the specified disks!

set -e  # Exit on error

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

# Display partition layout
if [ "$SAME_DISK" = true ]; then
    echo "Single disk configuration: $DISK_SYSTEM"
    echo ""
    echo "  Partition 1: 1GB    XBOOTLDR (vfat)  -> /boot"
    echo "  Partition 2: 1GB    EFI (vfat)       -> /efi"
    echo "  Partition 3: 8GB    RECOVERY         -> (unformatted)"
    echo "  Partition 4: 100%   ROOT (btrfs)     -> / (with @system-1 subvolume)"
    echo "  Partition 5: 100%   HOME (btrfs)     -> /home (with @home subvolume)"
else
    echo "Dual disk configuration:"
    echo ""
    echo "  $DISK_SYSTEM (System):"
    echo "    Partition 1: 1GB    XBOOTLDR (vfat)  -> /boot"
    echo "    Partition 2: 1GB    EFI (vfat)       -> /efi"
    echo "    Partition 3: 8GB    RECOVERY         -> (unformatted)"
    echo "    Partition 4: 100%   ROOT (btrfs)     -> /"
    echo ""
    echo "  $DISK_HOME (Home):"
    echo "    Partition 1: 100%   HOME (btrfs)     -> /home"
fi

echo ""
echo "WARNING: ALL DATA WILL BE ERASED ON:"
if [ "$SAME_DISK" = true ]; then
    echo "  - $DISK_SYSTEM"
else
    echo "  - $DISK_SYSTEM"
    echo "  - $DISK_HOME"
fi
echo ""
read -p "Type 'YES' to continue: " confirmation

if [ "$confirmation" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Partitioning $DISK_SYSTEM..."

parted -s "$DISK_SYSTEM" mklabel gpt

# Partition 1: 1GB xbootldr /boot (vfat)
parted -s "$DISK_SYSTEM" mkpart primary fat32 1MiB 1025MiB
parted -s "$DISK_SYSTEM" set 1 boot on
parted -s "$DISK_SYSTEM" name 1 'XBOOTLDR'

# Partition 2: 1GB EFI System /efi (vfat)
parted -s "$DISK_SYSTEM" mkpart primary fat32 1025MiB 2049MiB
parted -s "$DISK_SYSTEM" set 2 esp on
parted -s "$DISK_SYSTEM" name 2 'EFI'

# Partition 3: 8GB Recovery
parted -s "$DISK_SYSTEM" mkpart primary 2049MiB 10241MiB
parted -s "$DISK_SYSTEM" name 3 'RECOVERY'

# Partition 4: Remaining space for / (btrfs)
parted -s "$DISK_SYSTEM" mkpart primary btrfs 10241MiB 100%
parted -s "$DISK_SYSTEM" name 4 'ROOT'

echo "Partition table for $DISK_SYSTEM:"
parted "$DISK_SYSTEM" print

if [ "$SAME_DISK" = false ]; then
    echo ""
    echo "Partitioning $DISK_HOME..."
    
    parted -s "$DISK_HOME" mklabel gpt

    # Partition 1: 100% for /home (btrfs)
    parted -s "$DISK_HOME" mkpart primary btrfs 1MiB 100%
    parted -s "$DISK_HOME" name 1 'HOME'

    echo "Partition table for $DISK_HOME:"
    parted "$DISK_HOME" print
fi


echo ""
echo "Formatting partitions..."

if [[ "$DISK_SYSTEM" == *"nvme"* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

mkfs.vfat -F32 -n XBOOTLDR "${DISK_SYSTEM}${PART_SUFFIX}1"
mkfs.vfat -F32 -n EFI "${DISK_SYSTEM}${PART_SUFFIX}2"
mkfs.btrfs -f -L ROOT "${DISK_SYSTEM}${PART_SUFFIX}4"

if [ "$SAME_DISK" = false ]; then
    if [[ "$DISK_HOME" == *"nvme"* ]]; then
        HOME_PART_SUFFIX="p"
    else
        HOME_PART_SUFFIX=""
    fi
    mkfs.btrfs -f -L HOME "${DISK_HOME}${HOME_PART_SUFFIX}1"
fi

echo ""
echo "Creating btrfs subvolumes..."

MOUNT_POINT=$(mktemp -d)
mount "${DISK_SYSTEM}${PART_SUFFIX}4" "$MOUNT_POINT"

btrfs subvolume create "$MOUNT_POINT/@snapshots"
btrfs subvolume create "$MOUNT_POINT/@system-1"
btrfs subvolume create "$MOUNT_POINT/@var-cache"
btrfs subvolume create "$MOUNT_POINT/@var-docker"
btrfs subvolume create "$MOUNT_POINT/@var-log"
btrfs subvolume create "$MOUNT_POINT/@var-machines"
btrfs subvolume create "$MOUNT_POINT/@var-portables"
btrfs subvolume create "$MOUNT_POINT/@var-tmp"

umount "$MOUNT_POINT"

if [ "$SAME_DISK" = false ]; then
    mount "${DISK_HOME}${HOME_PART_SUFFIX}1" "$MOUNT_POINT"
else
    mount "${DISK_SYSTEM}${PART_SUFFIX}4" "$MOUNT_POINT"
fi

btrfs subvolume create "$MOUNT_POINT/@home"

# Unmount and cleanup
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

echo ""
echo "Partitioning and formatting complete!"
echo ""
