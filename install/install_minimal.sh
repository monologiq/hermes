#!/bin/bash

set -e

MOUNT_TARGET="/mnt"

read -p "Enter main username: " MAIN_USER
if [ -z "$MAIN_USER" ]; then
    echo "Error: Username cannot be empty"
    exit 1
fi

read -p "Enter your full name: " FULL_NAME
if [ -z "$FULL_NAME" ]; then
    echo "Error: Full name cannot be empty"
    exit 1
fi

pacstrap $MOUNT_TARGET \
	 base \
	 base-devel \
	 linux \
	 linux-firmware \
	 linux-headers \
	 btrfs-progs \
	 terminus-font\
	 vim \
	 efibootmgr \
	 nvidia-open-dkms \
	 nvidia-settings \
	 nvidia-utils \
	 libva-nvidia-driver \
	 libva-utils \
	 intel-ucode \
	 intel-media-driver \
	 vpl-gpu-rt \
	 vulkan-icd-loader \
	 vulkan-intel \
	 nvidia-prime \
	 vulkan-tools \
	 vdpauinfo \
	 acpid \
	 avahi \
	 iwd \
	 dhcpcd \
	 openssh \
	 sbctl \
	 fwupd \
	 i2c-tools \
	 lm_sensors \
	 bash-completion \
	 zsh \
	 zsh-completions \
	 git

echo "Enabling multilib repository..."
sed -i "/\[multilib\]/,/Include/"'s/^#//' $MOUNT_TARGET/etc/pacman.conf || \
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> $MOUNT_TARGET/etc/pacman.conf

echo "Installing 32-bit libraries..."
arch-chroot $MOUNT_TARGET pacman -Sy --noconfirm lib32-vulkan-intel lib32-nvidia-utils lib32-vulkan-icd-loader

echo "Generating fstab..."
genfstab -U $MOUNT_TARGET > $MOUNT_TARGET/etc/fstab
echo "tmpfs   /tmp         tmpfs   rw,nodev,nosuid,size=16G          0  0" >> $MOUNT_TARGET/etc/fstab

arch-chroot $MOUNT_TARGET /bin/bash <<CHROOT

set -e

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
echo "ru_RU.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "hermes" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1 localhost
127.0.1.1 hermes
HOSTS

cat > /etc/vconsole.conf <<VCONF
KEYMAP=us
FONT=ter-v28b
VCONF

cat > /etc/environment <<ENVCONF
ANV_DEBUG=video-decode,video-encode
VDPAU_DRIVER=va_gl
ENVCONF

bootctl --esp-path=/efi --boot-path=/boot install

sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)/' /etc/mkinitcpio.conf

mkdir -p /etc/cmdline.d

ROOT_UUID=\$(blkid -s UUID -o value /dev/disk/by-label/ROOT)
cat > /etc/cmdline.d/system.conf <<CMD
root=UUID=\$ROOT_UUID rw rootflags=subvol=@system-1
CMD

cat > /etc/cmdline.d/security.conf <<CMDSEC
lsm=landlock,lockdown,yama,integrity,apparmor,bpf audit=1 audit_backlog_limit=8192
CMDSEC

cat > /etc/mkinitcpio.d/linux.preset <<PRESET
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options="--splash=/usr/share/systemd/bootctl/splash-arch.bmp"

#fallback_uki="/efi/EFI/Linux/arch-linux-fallback.efi"
#fallback_options="-S autodetect"
PRESET

mkdir -p /efi/EFI/Linux
mkinitcpio -p linux

useradd -m -U -G wheel,audio,i2c,video,input,network -c "$FULL_NAME" -s /bin/bash $MAIN_USER
mkdir -p /home/$MAIN_USER/.ssh
chmod 700 /home/$MAIN_USER/.ssh
curl -s https://github.com/monologiq.keys > /home/$MAIN_USER/.ssh/authorized_keys
chmod 600 /home/$MAIN_USER/.ssh/authorized_keys
chown -R $MAIN_USER:$MAIN_USER /home/$MAIN_USER/.ssh

sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

systemctl enable sshd
systemctl enable acpid
systemctl enable avahi-daemon

CHROOT

echo "Next steps:"
echo "  1. Set root password: arch-chroot $MOUNT_TARGET passwd"
echo "  2. Set user password: arch-chroot $MOUNT_TARGET passwd $MAIN_USER"
echo "  3. Exit and reboot: exit && umount -R $MOUNT_TARGET && reboot"
