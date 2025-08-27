# Base install
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb base base-devel linux linux-lts linux-headers linux-lts-headers linux-firmware iptables-nft mkinitcpio amd-ucode

# required boot utils
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb grub efibootmgr sudo networkmanager sof-firmware iptables-nft noto-fonts os-prober
systemctl enable NetworkManager

# sound and bluetooth
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb bluez bluez-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber gst-plugin-pipewire pavucontrol gnome-bluetooth pipewire-audio
sudo systemctl enable --now bluetooth.service

# desktop environment
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb gnome gnome-extra gdm xorg-server pipewire-jack noto-fonts firefox
sudo systemctl enable gdm.service --now

sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb plasma pipewire-jack  kde-applications plasma-desktop noto-fonts iptables-nft pyside6 qt6-multimedia-ffmpeg cronie  tesseract-data-eng firefox

# graphic drivers
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb nvidia nvidia-utils nvidia-settings mkinitcpio nvidia-prime nvidia-dkms
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb mesa mesa-utils vulkan-radeon lib32-vulkan-radeon
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb mesa virtualbox-guest-utils

sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb open-vm-tools mesa mesa-utils xf86-input-vmmouse iptables-nft
sudo systemctl enable --now vmtoolsd.service
sudo systemctl enable --now vmware-vmblock-fuse.service

# addtional applications
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb gcc make cmake git vim wget curl perl go rust rsync fastfetch btop terminus-font less konsole qt6-multimedia-ffmpeg pipewire-jack zip


# for archiso
sudo pacman -Syyw --cachedir /block/repo --dbpath /block/blankdb alsa-utils amd-ucode arch-install-scripts archinstall b43-fwcutter base bcachefs-tools bind bolt brltty broadcom-wl btrfs-progs clonezilla cloud-init cryptsetup darkhttpd ddrescue dhcpcd diffutils dmidecode dmraid dnsmasq dosfstools e2fsprogs edk2-shell efibootmgr espeakup ethtool exfatprogs f2fs-tools fatresize foot-terminfo fsarchiver gpart gpm gptfdisk grml-zsh-config grub hdparm hyperv intel-ucode irssi iw iwd jfsutils kitty-terminfo ldns less lftp libfido2 libusb-compat linux linux-atm linux-firmware linux-firmware-marvell livecd-sounds lsscsi lvm2 lynx man-db man-pages mc mdadm memtest86+ memtest86+-efi mkinitcpio mkinitcpio-archiso mkinitcpio-nfs-utils mmc-utils modemmanager mtools nano nbd ndisc6 nfs-utils nilfs-utils nmap ntfs-3g nvme-cli open-iscsi open-vm-tools openconnect openpgp-card-tools openssh openvpn partclone parted partimage pcsclite ppp pptpclient pv qemu-guest-agent refind reflector rsync rxvt-unicode-terminfo screen sdparm sequoia-sq sg3_utils smartmontools sof-firmware squashfs-tools sudo syslinux systemd-resolvconf tcpdump terminus-font testdisk tmux tpm2-tools tpm2-tss udftools usb_modeswitch usbmuxd usbutils vim virtualbox-guest-utils-nox vpnc wireless-regdb wireless_tools wpa_supplicant wvdial xdg-utils xfsprogs xl2tpd zsh iptables-nft
