#!/bin/bash
# set -x
set -euo pipefail
setfont ter-v32b

# ---------------- CONFIG ----------------
LOG_FILE="/tmp/install.log"
CHROOT="/mnt"


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
    # set +x
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
    # set -x

}

# ---------------- REDIRECT ALL OUTPUT ----------------
# Everything from here (stdout & stderr) goes both to screen & log file
exec > >(tee -a "$LOG_FILE") 2>&1

log INFO "======================================================================"
log INFO "🚀 Welcome to the Arch Linux Installer v1"

# ------------------ DEVICE SETUP ------------------
device_id=${1:?Usage: $0 <device_id>}
#device_id=/dev/nvme0n1
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

# Load config
CONFIG_FILE="./config.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "Config file not found!"
    exit 1;
fi


REQUIRED_VARS=("BOOTPART" "SWAPPART" "ROOTPART" "HOMEPART")

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        log ERROR "❌ Error: $var is not set in $CONFIG_FILE"
        exit 1
    fi
done

# Assign partitions
boot_partition=$BOOTPART
swap_partition=$SWAPPART
root_partition=$ROOTPART
home_partition=$HOMEPART

# ------------------ DEBUG PRINT ------------------
log INFO "Boot partition: $boot_partition"
log INFO "Swap partition: $swap_partition"
log INFO "Root partition: $root_partition"
log INFO "Home partition: $home_partition"


# Cleanup
lsblk $device_id

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

# exit;
# ------------------ BASE INSTALL ------------------
log INFO "📦 Installing base system..."
pacstrap -K -C ./pacman.custom.conf "$CHROOT"  base base-devel linux linux-lts linux-headers linux-lts-headers linux-firmware iptables-nft mkinitcpio amd-ucode grub efibootmgr sudo networkmanager sof-firmware iptables-nft noto-fonts os-prober

# install sound and bluetooth
pacstrap -C ./pacman.custom.conf "$CHROOT" bluez bluez-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire pavucontrol gnome-bluetooth pipewire-audio


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
echo "root:mypassowrd" | arch-chroot "$CHROOT" chpasswd

# # create user
log INFO 'creating personal user with sudo access'
arch-chroot "$CHROOT" useradd -m -G wheel -s /bin/bash bisht
echo "bisht:mypassowrd" | arch-chroot "$CHROOT" chpasswd
# arch-chroot "$CHROOT" sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
arch-chroot "$CHROOT" sed -i -E 's/^# %wheel ALL=\(ALL(:ALL)?\) ALL/%wheel ALL=\(ALL\1\) ALL/' /etc/sudoers

log INFO "🌐 Enabling BlueTooth & NetworkManager..."
arch-chroot "$CHROOT" systemctl enable NetworkManager
arch-chroot "$CHROOT" systemctl is-enabled NetworkManager

arch-chroot "$CHROOT" systemctl enable bluetooth.service
arch-chroot "$CHROOT" systemctl is-enabled bluetooth.service


# ------------------ BOOTLOADER ------------------
log INFO "⚙️ Installing GRUB bootloader..."
# arch-chroot "$CHROOT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB   --no-nvram
arch-chroot "$CHROOT" grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB

arch-chroot "$CHROOT" grub-mkconfig -o /boot/grub/grub.cfg

# ------------------ DESKTOP ------------------
log INFO "🖥️ Installing desktop environments..."
#log INFO "➡ Installing KDE..."
#pacstrap -C ./pacman.custom.conf "$CHROOT" plasma kde-applications firefox gdm
#arch-chroot "$CHROOT" systemctl enable gdm.service

# pacstrap -C ./pacman.custom.conf /mnt systemctl enable --now gdm

log INFO "➡ Installing GNOME..."
pacstrap -C ./pacman.custom.conf "$CHROOT" gnome gnome-extra gdm xorg-server pipewire-jack noto-fonts firefox
arch-chroot "$CHROOT" systemctl enable gdm.service
arch-chroot "$CHROOT" systemctl is-enabled gdm.service

log INFO "➡ Installing terminal apps..."
pacstrap -C ./pacman.custom.conf "$CHROOT" gcc make cmake git vim wget curl perl go rust rsync fastfetch btop terminus-font less konsole qt6-multimedia-ffmpeg pipewire-jack zip konsole fastfetch

# ------------------ GPU / VM DRIVERS ------------------

if lspci 2>/dev/null | grep -i -E "NVIDIA|Nvidia|nvidia" >/dev/null; then
    log INFO "🟢 NVIDIA GPU detected → Installing DKMS drivers..."
    pacstrap -C ./pacman.custom.conf "$CHROOT" \
        nvidia-dkms nvidia-utils nvidia-settings nvidia-prime mkinitcpio
    arch-chroot "$CHROOT" mkinitcpio -P
    arch-chroot "$CHROOT" systemctl enable nvidia-persistenced.service

    # Optional: If using Linux headers (needed for DKMS builds)
    # pacman -S --noconfirm linux-headers nvidia-dkms

    # Rebuild initramfs so modules are included
    arch-chroot "$CHROOT" mkinitcpio -P
    # Enable persistence mode (optional)
    # arch-chroot "$CHROOT" nvidia-smi -pm 1 || true
        # Check if nvidia-utils installed correctly
    if ! arch-chroot "$CHROOT" pacman -Q nvidia-utils >/dev/null 2>&1; then
        log ERROR "❌ nvidia-utils package missing — proprietary drivers not installed!"
    fi

    # Verify nvidia-smi binary exists
    if ! arch-chroot "$CHROOT" test -x /usr/bin/nvidia-smi; then
        log ERROR "❌ nvidia-smi not found — driver install failed!"
    else
        log INFO "✅ NVIDIA proprietary drivers installed (nvidia-smi available)"
    fi


    echo "✅ NVIDIA proprietary drivers installed. Reboot recommended."
elif lspci | grep -qi amd; then
    log INFO "🟢 AMD GPU detected → Installing drivers..."
    pacstrap -C ./pacman.custom.conf "$CHROOT" mesa mesa-utils vulkan-radeon lib32-vulkan-radeon

#    arch-chroot "$CHROOT" pacman -S --noconfirm nvidia nvidia-utils nvidia-settings mkinitcpio nvidia-prime
#    # Optional: If using Linux headers (needed for DKMS builds)
#    # pacman -S --noconfirm linux-headers nvidia-dkms
#
#    # Regenerate initramfs
#    arch-chroot "$CHROOT" mkinitcpio -P
#    # Enable persistence mode (optional)
#    arch-chroot "$CHROOT" nvidia-smi -pm 1 || true

    echo "✅ AMD GPU drivers installed. Reboot recommended."

elif systemd-detect-virt | grep -qi oracle; then
    log INFO "🟢 VirtualBox detected → Installing guest drivers..."
    pacstrap -C ./pacman.custom.conf "$CHROOT" virtualbox-guest-utils
    arch-chroot "$CHROOT" systemctl enable vboxservice.service
    arch-chroot "$CHROOT" systemctl is-enabled vboxservice.service

else
    log INFO "⚪ No NVIDIA/VirtualBox detected → Installing Mesa drivers..."
    pacstrap -C ./pacman.custom.conf "$CHROOT" open-vm-tools mesa mesa-utils xf86-input-vmmouse iptables-nft
    arch-chroot "$CHROOT" systemctl enable vmtoolsd.service
    arch-chroot "$CHROOT" systemctl enable vmware-vmblock-fuse.service
fi

# ------------------ NVIDIA PERSISTENCE MODE ------------------
if lspci | grep -qi NVIDIA; then
    log INFO "⚙️ Enabling NVIDIA Persistence Mode on boot..."

    arch-chroot "$CHROOT" bash -c 'cat > /etc/systemd/system/nvidia-persistenced.service <<EOF
[Unit]
Description=NVIDIA Persistence Daemon
After=multi-user.target

[Service]
Type=forking
ExecStart=/usr/bin/nvidia-persistenced --user root
ExecStopPost=/bin/rm -rf /var/run/nvidia-persistenced
Restart=always

[Install]
WantedBy=multi-user.target
EOF'

    # Enable the service
    arch-chroot "$CHROOT" systemctl enable nvidia-persistenced.service
fi

# audio tune up
#arch-chroot "$CHROOT" bash -c 'mkdir -p /etc/pipewire/client.conf.d'
#arch-chroot "$CHROOT" bash -c 'cat > /etc/pipewire/client.conf.d/50-alsa.conf <<EOF
#context.properties = {
#    default.clock.rate        = 48000
#    default.clock.quantum     = 1024
#    default.clock.min-quantum = 512
#    default.clock.max-quantum = 2048
#}
#EOF'
#arch-chroot "$CHROOT" bash -c 'mkdir -p /etc/pipewire/pipewire.conf.d'
#arch-chroot "$CHROOT" bash -c 'cat > /etc/pipewire/pipewire.conf.d/99-custom.conf <<EOF
#default.clock.rate        = 48000
#default.clock.quantum     = 1024
#default.clock.min-quantum = 512
#default.clock.max-quantum = 2048
#EOF'
#

arch-chroot "$CHROOT" systemctl enable rtkit-daemon.service
arch-chroot "$CHROOT" systemctl is-enabled rtkit-daemon.service

#arch-chroot "$CHROOT" loginctl enable-linger bisht
arch-chroot "$CHROOT" bash -c 'mkdir -p /var/lib/systemd/linger && touch /var/lib/systemd/linger/bisht'
#
#arch-chroot "$CHROOT" sudo -u bisht systemctl --user enable pipewire.service pipewire-pulse.service wireplumber.service
#arch-chroot "$CHROOT" sudo -u bisht systemctl --user is-enabled pipewire.service pipewire-pulse.service wireplumber.service

#arch-chroot "$CHROOT" bash -c '
#mkdir -p /home/bisht/.config/systemd/user/default.target.wants
#ln -s /usr/lib/systemd/user/pipewire.service /home/bisht/.config/systemd/user/default.target.wants/pipewire.service
#ln -s /usr/lib/systemd/user/pipewire-pulse.service /home/bisht/.config/systemd/user/default.target.wants/pipewire-pulse.service
#ln -s /usr/lib/systemd/user/wireplumber.service /home/bisht/.config/systemd/user/default.target.wants/wireplumber.service
#chown -R bisht:bisht /home/bisht/.config/systemd
#'


arch-chroot "$CHROOT" bash -c 'mkdir -p /home/bisht/.config/systemd/user/default.target.wants && ln -sf /usr/lib/systemd/user/{pipewire.service,pipewire-pulse.service,wireplumber.service} /home/bisht/.config/systemd/user/default.target.wants/ && chown -R bisht:bisht /home/bisht/.config/systemd'


arch-chroot "$CHROOT" mkinitcpio -P

# ------------------ FINISH ------------------
arch-chroot "$CHROOT" efibootmgr -v
log INFO "✅ Installation complete! You may now reboot."
umount -R "$CHROOT"
#swapoff -a
