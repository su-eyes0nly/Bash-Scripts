#!/bin/bash

# Display ASCII Logo
echo"====================================================================="
echo"███████╗██████╗░███████╗███╗░░░███╗░█████╗░███╗░░██╗██╗░░░██╗██╗░░██╗"
echo"██╔════╝██╔══██╗██╔════╝████╗░████║██╔══██╗████╗░██║██║░░░██║╚██╗██╔╝"
echo"█████╗░░██████╔╝█████╗░░██╔████╔██║███████║██╔██╗██║██║░░░██║░╚███╔╝░"
echo"██╔══╝░░██╔══██╗██╔══╝░░██║╚██╔╝██║██╔══██║██║╚████║██║░░░██║░██╔██╗░"
echo"██║░░░░░██║░░██║███████╗██║░╚═╝░██║██║░░██║██║░╚███║╚██████╔╝██╔╝╚██╗"
echo"╚═╝░░░░░╚═╝░░╚═╝╚══════╝╚═╝░░░░░╚═╝╚═╝░░╚═╝╚═╝░░╚══╝░╚═════╝░╚═╝░░╚═╝"
echo"====================================================================="
echo "🚀 Welcome to FREMANux - Your Custom Arch Linux Installer 🚀"
echo "This script will guide you through partitioning, system setup,"
echo "and installing forensic & malware analysis tools."
echo
read -rp "Press Enter to continue..."


# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!"
  exit 1
fi

# Install whiptail to gain interactive menu similar to the official archinstall script
if ! command -v whiptail &>/dev/null; then
  echo "Installing whiptail..."
  pacman -Sy --noconfirm whiptail
fi

# ---------------------------------------------
# 🚀 DISK SETUP (Partitioning & Formatting)
# ---------------------------------------------
DISK=$(whiptail --inputbox "Enter the disk to install Arch (e.g., /dev/sda):" 10 60 "/dev/sda" 3>&1 1>&2 2>&3)
if [ $? -ne 0 ]; then
  echo "Installation canceled!"
  exit 1
fi

whiptail --yesno "Would you like to partition the disk using cfdisk?" 10 60
if [ $? -eq 0 ]; then
  cfdisk "$DISK"
fi

# Confirm partition names
ROOT_PART=$(whiptail --inputbox "Enter root partition (e.g., ${DISK}1):" 10 60 "${DISK}1" 3>&1 1>&2 2>&3)
EFI_PART=$(whiptail --inputbox "Enter EFI partition (leave blank for BIOS systems):" 10 60 "" 3>&1 1>&2 2>&3)

# Format partitions
mkfs.ext4 "$ROOT_PART"
if [ -n "$EFI_PART" ]; then
  mkfs.fat -F32 "$EFI_PART"
fi

# Mount partitions
mount "$ROOT_PART" /mnt
if [ -n "$EFI_PART" ]; then
  mkdir -p /mnt/boot/efi
  mount "$EFI_PART" /mnt/boot/efi
fi

# ---------------------------------------------
# 🚀 BASE SYSTEM INSTALLATION
# ---------------------------------------------
pacstrap /mnt base linux linux-firmware vim nano networkmanager sudo base-devel git

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# ---------------------------------------------
# 🚀 LOCALIZATION & SYSTEM SETTINGS
# ---------------------------------------------
arch-chroot /mnt /bin/bash <<EOF
echo "Configuring system settings..."

# Set timezone
ln -sf /usr/share/zoneinfo/$(whiptail --inputbox "Enter your region/timezone (e.g., America/New_York):" 10 60 "UTC" 3>&1 1>&2 2>&3) /etc/localtime
hwclock --systohc

# Set locale
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Set hostname
HOSTNAME=$(whiptail --inputbox "Enter your desired hostname:" 10 60 "archlinux" 3>&1 1>&2 2>&3)
echo "$HOSTNAME" > /etc/hostname

# Set root password
echo "Setting root password..."
passwd

# Add new user
USERNAME=$(whiptail --inputbox "Enter your new username:" 10 60 "user" 3>&1 1>&2 2>&3)
useradd -m -G wheel -s /bin/bash "$USERNAME"
echo "Set password for user $USERNAME"
passwd "$USERNAME"

# Enable sudo privileges
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Enable networking
systemctl enable NetworkManager
EOF

# ---------------------------------------------
# 🚀 BOOTLOADER INSTALLATION
# ---------------------------------------------
arch-chroot /mnt /bin/bash <<EOF
echo "Installing bootloader..."

if [ -n "$EFI_PART" ]; then
  pacman -S --noconfirm grub efibootmgr
  grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
else
  pacman -S --noconfirm grub
  grub-install --target=i386-pc "$DISK"
fi

grub-mkconfig -o /boot/grub/grub.cfg
EOF

# ---------------------------------------------
# 🚀 INSTALL FORENSIC & MALWARE TOOLS
# ---------------------------------------------
TOOLS=$(whiptail --title "Forensic & Malware Analysis Tools" --checklist \
"Select tools to install:" 20 78 12 \
"autopsy" "Forensic analysis GUI" OFF \
"sleuthkit" "Command-line forensic toolkit" OFF \
"ddrescue" "Data recovery tool" OFF \
"foremost" "File recovery & carving" OFF \
"binwalk" "Firmware analysis" OFF \
"volatility" "Memory analysis framework" OFF \
"wireshark-qt" "Network protocol analyzer" OFF \
"tcpdump" "CLI network traffic sniffer" OFF \
"nmap" "Network scanner" OFF \
"hashdeep" "File integrity checker" OFF \
"yara" "Malware identification" OFF \
"clamav" "Antivirus engine" OFF \
"rkhunter" "Rootkit detection" OFF \
"lynis" "Security auditing tool" OFF \
"chkrootkit" "Rootkit scanner" OFF \
"maldet" "Malware scanner" OFF \
"peepdf" "PDF malware analysis" OFF \
"python-yara" "Python bindings for YARA" OFF \
"ssdeep" "Fuzzy hashing tool" OFF \
"cuckoo" "Malware analysis sandbox" OFF \
"guymager" "Forensic disk imaging (AUR)" OFF 3>&1 1>&2 2>&3)

# Convert whiptail selection to array
TOOLS=($TOOLS)

# Install selected tools
arch-chroot /mnt /bin/bash <<EOF
echo "Installing forensic and malware analysis tools..."
for tool in "${TOOLS[@]}"; do
  case "\$tool" in
    "guymager") yay -S --noconfirm guymager ;;
    *) pacman -S --noconfirm "\$tool" ;;
  esac
done

# Enable ClamAV service if selected
if [[ " ${TOOLS[@]} " =~ " clamav " ]]; then
  systemctl enable clamav-freshclam
  systemctl start clamav-freshclam
fi
EOF

# ---------------------------------------------
# 🚀 CLEANUP & REBOOT
# ---------------------------------------------
whiptail --yesno "Installation complete! Would you like to reboot now?" 10 60
if [ $? -eq 0 ]; then
  umount -R /mnt
  reboot
else
  echo "Setup complete. You may now exit and reboot into FREMANux."
fi
