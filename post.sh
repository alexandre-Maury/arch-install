#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.


##############################################################################
## arch-chroot Définir le fuseau horaire + local                                                  
##############################################################################
log_prompt "INFO" && echo "Configuration du fuseau horaire" && echo ""
sudo timedatectl set-ntp true
sudo timedatectl set-timezone ${REGION}/${CITY}
sudo localectl set-locale LANG="${LANG}" LC_TIME="${LANG}"
sudo hwclock --systohc --utc

timedatectl status

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installation de YAY && PARU                                                 
##############################################################################
cd /tmp

git clone https://aur.archlinux.org/yay.git
git clone https://aur.archlinux.org/paru.git

cd /tmp/paru && makepkg -si && paru -Syu
cd /tmp/yay && makepkg -si

##############################################################################
## Install packages                                                
##############################################################################

# Guest tools ==> SPICE support on guest (for UTM)
sudo pacman -S spice-vdagent xf86-video-qxl --noconfirm

# Guest tools ==> for VirtualBox
sudo pacman -S virtualbox-guest-utils --noconfirm

# Guest tools ==> for Fonts
sudo pacman -S noto-fonts ttf-opensans ttf-firacode-nerd --noconfirm
sudo pacman -S noto-fonts-emoji --noconfirm


##############################################################################
## Install Hyprland                                               
##############################################################################
yay -S --noconfirm gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors hyprutils-git aquamarine

cd /tmp && git clone --recursive https://github.com/hyprwm/Hyprland
cd /tmp/Hyprland && make all && sudo make install

##############################################################################
## Clean                                                
##############################################################################

sudo rm -rf /tmp/*