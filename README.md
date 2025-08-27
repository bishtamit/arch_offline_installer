These installer will install arch linux along with linux-lts kernel and gnome DE with gdm DM. There is option to automatically detect the display drivers and install.

There are two installers ./install.sh and ./install_on_pc.sh

1. **install.sh** (USE IN VIRTUALBOX)
    
    This installer assumes your whole disk is for linux install and will remove the all data on that disk
2. **install_on_pc.sh** (USE WHEN INSTALLING ON ACTUAL MACHINE)
  
    This installer will take parition info from config.conf file, there you must provide /boot, /, /home & SWAP partition details. Partition can be done using parted or cfdisk before hand



---


yay -S calamares calamares-settings-arch --noconfirm --answerclean All --answerdiff None --answeredit None --mflags="--skippgpcheck" --gitflags="--depth=1"
