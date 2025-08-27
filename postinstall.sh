log() {
    local level=$1
    shift
    local msg="$@"

    # Print to screen with timestamp + level
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg"

    # Send to syslog with tag `myscript` and priority based on level
    case "$level" in
        INFO)  logger -t myscript -p user.info "$msg" ;;
        WARN)  logger -t myscript -p user.warning "$msg" ;;
        ERROR) logger -t myscript -p user.err "$msg" ;;
        *)     logger -t myscript -p user.notice "$msg" ;;
    esac
}


log INFO "RUNNING POST INSTALL STEPS"

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
# arch-chroot /mnt bash -c ""
arch-chroot /mnt locale-gen
arch-chroot /mnt bash -c 'echo "LANG=en_US.UTF-8" > /etc/locale.conf'
arch-chroot /mnt bash -c 'echo "Archie" > /etc/hostname'
log INFO 'chnaging passwrod'
echo "root:rut" | arch-chroot /mnt chpasswd

# # create user
arch-chroot /mnt useradd -m -G wheel -s /bin/bash bisht
echo "bisht:rut" | arch-chroot /mnt chpasswd

arch-chroot /mnt sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

arch-chroot /mnt systemctl enable NetworkManager
arch-chroot /mnt grub-install $device_id
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

log INFO "Post install done"

