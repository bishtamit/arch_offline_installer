#!/bin/bash
set -euo pipefail
setfont ter-v18b

# ---------------- CONFIG ----------------
LOG_FILE="/tmp/install.log"
CHROOT="/mnt"

set -x

# log() {
#     local level=$1
#     shift
#     local msg="$@"

#     # Print to screen with timestamp + level
#     echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg"

#     # Send to syslog with tag `myscript` and priority based on level
#     case "$level" in
#         INFO)  logger -t myscript -p user.info "$msg" ;;
#         WARN)  logger -t myscript -p user.warning "$msg" ;;
#         ERROR) logger -t myscript -p user.err "$msg" ;;
#         *)     logger -t myscript -p user.notice "$msg" ;;
#     esac
# }

log() {
    local level=$1; shift
    local msg="$*"
    local ts="$(date '+%Y-%m-%d %H:%M:%S')"
    local line

    case "$level" in
        INFO)  line="[$ts] [✔ INFO]  $msg"; echo -e "[$ts] [\e[32m✔ INFO\e[0m]  $msg" ;;
        WARN)  line="[$ts] [⚠ WARN]  $msg"; echo -e "[$ts] [\e[33m⚠ WARN\e[0m]  $msg" ;;
        ERROR) line="[$ts] [✖ ERROR] $msg"; echo -e "[$ts] [\e[31m✖ ERROR\e[0m] $msg" ;;
        *)     line="[$ts] [ℹ LOG]   $msg"; echo -e "[$ts] [ℹ LOG]   $msg" ;;
    esac

    # Save plain version to log file (no colors)
    echo "$line" >> "$LOG_FILE"

}

# ---------------- REDIRECT ALL OUTPUT ----------------
# Everything from here (stdout & stderr) goes both to screen & log file
exec > >(tee -a "$LOG_FILE") 2>&1

log INFO "======================================================================"
log INFO "🚀 Welcome to the Arch Linux Installer v1"

# ------------------ DEVICE SETUP ------------------
device_id=${1:?Usage: $0 <device_id>}
log INFO "💽 Target install disk: ${device_id}"
# if [ -z "$device_id" ]; then
#     log ERROR "error: provide disk to insstall";
#     exit 1
# fi


# log INFO "loading keyboard layout"
# loadkeys us

# log INFO "connecting to internet"
# # iwctl station wlan0 connect ""
# log INFO "connected"


boot_partition=${device_id}p1
swap_partition=${device_id}p2
root_partition=${device_id}p3
home_partition=${device_id}p4

# Cleanup
lsblk $device_id
log INFO "🧹 Cleaning old partitions and mounts..."

# log INFO "removing old mounts if any"

# umount -l -R /mnt/boot/efi 2>/dev/null || true
# umount -l -R  /mnt/home 2>/dev/null || true
# umount -l -R  /mnt/ 2>/dev/null || true
# swapoff "$swap_partition" 2>/dev/null || true
# log INFO "removing old mounts for $device_id if any"


# Unmount all partitions of the device (by device, not just /mnt paths)
# for p in $(lsblk -ln -o NAME "$device_id" | tail -n +2); do
#     dev="/dev/$p"
#     while mount | grep -q "^$dev "; do
#         mp=$(mount | awk -v dev="$dev" '$1 == dev {print $3; exit}')
#         log INFO "Force unmounting $dev from $mp"
#         umount -l -f "$mp" 2>/dev/null || true
#     done
# done

# log INFO "removing old mounts for $device_id if any"

# # Collect all mount points of this device, sort by path depth (deepest first)
# for mp in $(mount | awk -v dev="$device_id" '$1 ~ "^"dev {print $3}' | awk '{print length, $0}' | sort -rn | cut -d' ' -f2-); do
#     log INFO "Force unmounting $mp"
#     umount -l -f "$mp" 2>/dev/null || true
# done


# # Disable swap if active
# for p in $(swapon --show=NAME --noheadings); do
#     if [[ $p == ${device_id}* ]]; then
#         log INFO "Disabling swap on $p"
#         swapoff "$p" 2>/dev/null || true
#     fi
# done

# log INFO "swap unmounted"

swapoff -a || true
mount | grep "$device_id" | awk '{print $3}' | xargs -r -n1 umount -lf || true
sgdisk --zap-all --clear "$device_id"
dd if=/dev/zero of="$device_id" bs=1M count=10 conv=fsync,notrunc oflag=direct
dd if=/dev/zero of="$device_id" bs=1M count=10 seek=$(( $(blockdev --getsz "$device_id") / 2048 - 10 )) conv=fsync,notrunc oflag=direct
# for p in $(lsblk -ln -o NAME "$device_id" | tail -n +2); do
#     umount -f "/dev/$p" 2>/dev/null || true
# done
log INFO "✔ Device cleanup complete"
lsblk

log INFO "📐 Creating GPT disk..."
# ------------------ PARTITIONING ------------------
log INFO "📐 Starting disk partitioning on $device_id..."
parted "$device_id" print

log INFO "📝 Converting disk to GPT..."
parted -s "$device_id" mklabel gpt

log INFO "🟦 Creating 1GB EFI System Partition..."
parted -s "$device_id" mkpart primary fat32 1MiB 1025MiB

log INFO "🔄 Creating 4GB Swap Partition..."
parted -s "$device_id" mkpart primary linux-swap 1025MiB 5121MiB

log INFO "📂 Creating Root Partition (up to 70% of disk)..."
parted -s "$device_id" mkpart primary ext4 5121MiB 70%

log INFO "🏠 Creating Home Partition (remaining space)..."
parted -s "$device_id" mkpart primary ext4 70% 100%

log INFO "✅ Partitioning complete. Final layout:"
parted "$device_id" print

# ------------------ FORMATTING ------------------
log INFO "🧾 Formatting partitions..."
mkfs.fat -F32 -I "$boot_partition"
mkfs.ext4 -F "$root_partition"
mkfs.ext4 -F "$home_partition"
mkswap -f "$swap_partition"

log INFO "device details;"
parted $device_id print;

# ------------------ MOUNTING ------------------
log INFO "📂 Mounting partitions..."
mount "$root_partition" "$CHROOT" --mkdir
mkdir -p "$CHROOT/boot/efi" && mount "$boot_partition" "$CHROOT/boot/efi"
mkdir -p "$CHROOT/home" && mount "$home_partition" "$CHROOT/home"
swapon "$swap_partition"
lsblk

exit;
# ------------------ BASE INSTALL ------------------
log INFO "📦 Installing base system..."
pacstrap -K -C ./pacman.custom.conf "$CHROOT" base linux linux-headers linux-firmware \
    sudo base-devel grub efibootmgr vim networkmanager sof-firmware

log INFO "📝 Generating fstab..."
genfstab -U "$CHROOT" >> "$CHROOT/etc/fstab"
cat "$CHROOT/etc/fstab"
log INFO "✔ Base installation complete"

# ------------------ SYSTEM CONFIG ------------------
log INFO "doing post installation"
log INFO "🌍 Setting timezone, locale, and hostname..."
arch-chroot "$CHROOT" ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
arch-chroot "$CHROOT" hwclock --systohc
arch-chroot "$CHROOT" sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot "$CHROOT" locale-gen
echo "LANG=en_US.UTF-8" | arch-chroot "$CHROOT" tee /etc/locale.conf
echo "Archie" | arch-chroot "$CHROOT" tee /etc/hostname

# ------------------ USERS ------------------
log INFO "👤 Setting root and user accounts..."
echo "root:rut" | arch-chroot "$CHROOT" chpasswd

# # create user
log INFO 'creating personal user with sudo access'
arch-chroot "$CHROOT" useradd -m -G wheel -s /bin/bash bisht
echo "bisht:rut" | arch-chroot "$CHROOT" chpasswd
arch-chroot "$CHROOT" sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

log INFO "🌐 Enabling NetworkManager..."
arch-chroot "$CHROOT" systemctl enable NetworkManager

# ------------------ BOOTLOADER ------------------
log INFO "⚙️ Installing GRUB bootloader..."
arch-chroot "$CHROOT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
arch-chroot "$CHROOT" grub-mkconfig -o /boot/grub/grub.cfg

# ------------------ DESKTOP ------------------
log INFO "🖥️ Installing desktop environments..."
log INFO "➡ Installing KDE..."
pacstrap -C ./pacman.custom.conf "$CHROOT" plasma kde-applications firefox gdm
arch-chroot "$CHROOT" systemctl enable gdm

# pacstrap -C ./pacman.custom.conf /mnt systemctl enable --now gdm

log INFO "➡ Installing GNOME..."
pacstrap -C ./pacman.custom.conf "$CHROOT" gnome gnome-extra

log INFO "➡ Installing terminal apps..."
pacstrap -C ./pacman.custom.conf "$CHROOT" konsole fastfetch

# ------------------ GPU / VM DRIVERS ------------------
if lspci | grep -qi nvidia; then
    log INFO "🟢 NVIDIA GPU detected → Installing drivers..."
    arch-chroot "$CHROOT" pacman -S --noconfirm nvidia nvidia-utils nvidia-settings
    # Optional: If using Linux headers (needed for DKMS builds)
    # pacman -S --noconfirm linux-headers nvidia-dkms

    # Regenerate initramfs
    arch-chroot "$CHROOT" mkinitcpio -P
    # Enable persistence mode (optional)
    arch-chroot "$CHROOT" nvidia-smi -pm 1 || true

    echo "✅ NVIDIA proprietary drivers installed. Reboot recommended."
elif systemd-detect-virt | grep -qi oracle; then
    log INFO "🟢 VirtualBox detected → Installing guest drivers..."
    arch-chroot "$CHROOT" pacman -S --noconfirm virtualbox-guest-utils xf86-video-vmware
    arch-chroot "$CHROOT" systemctl enable vboxservice.service
    arch-chroot "$CHROOT" systemctl start vboxservice.service
else
    log INFO "⚪ No NVIDIA/VirtualBox detected → Installing Mesa drivers..."
    arch-chroot "$CHROOT" pacman -S --noconfirm mesa
fi

# ------------------ FINISH ------------------
log INFO "✅ Installation complete! You may now reboot."
umount -R "$CHROOT"
swapoff -a
