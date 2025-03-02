#!/usr/bin/env bash
set -e

# 1. Disk Partitioning

echo "Available disks:"
lsblk -d -o NAME,SIZE,TYPE | grep 'disk'

read -p "Enter the disk to install to (e.g., /dev/sda or /dev/vda): " DISK

parted --script "$DISK" mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 "${DISK}2"

mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

# 2. Base System Installation

pacstrap /mnt base linux linux-firmware vim

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt bash -c "
    ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
    hwclock --systohc
    echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    echo 'archmalware' > /etc/hostname
    pacman -S --noconfirm grub efibootmgr
    if [ -d /sys/firmware/efi ]; then
        grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    else
        grub-install --target=i386-pc $DISK
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
"

# 3. Tool Installation

arch-chroot /mnt bash -c "
    pacman -S --noconfirm base-devel git wget vim gdb strace ltrace wireshark radare2 sleuthkit foremost volatility networkmanager
    systemctl enable NetworkManager htop
    git clone https://aur.archlinux.org/yay.git /home/yay-installer
    chown -R nobody:nobody /home/yay-installer
    cd /home/yay-installer
    sudo -u nobody makepkg -si --noconfirm
    cd /
    rm -rf /home/yay-installer
    sudo -u nobody yay -S --noconfirm ghidra autopsy
"

# 4. User Configuration

read -p "Enter username for the new user: " USERNAME
read -sp "Enter password for $USERNAME: " PASSWORD

echo
arch-chroot /mnt bash -c "
    useradd -m -G wheel $USERNAME
    echo '$USERNAME:$PASSWORD' | chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
"

echo "Installation complete. You may reboot into FREMANux."
