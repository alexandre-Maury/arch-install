#!/usr/bin/bash

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

# WORK IN TEMP DIR
workDirName="${HOME}/buildHypr";
rm -rf $workDirName
mkdir -p $workDirName
cd $workDirName

hyprBuildInstall() {
	cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
	cmake --build ./build --config Release --target $1 -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
	sudo cmake --install ./build
}



##############################################################################
## Information Utilisateur                                              
##############################################################################
log_prompt "INFO" && read -p "Quel est votre nom d'utilisateur : " USER && echo ""

##############################################################################
## Mise à jour du système                                                 
##############################################################################
log_prompt "INFO" && echo "Mise à jour du système " && echo ""
sudo pacman -Syyu --noconfirm
log_prompt "SUCCESS" && echo "Terminée" && echo ""

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
if [[ "$YAY" == "On" ]]; then
    if ! command -v yay &> /dev/null; then
        log_prompt "INFO" && echo "Installation de YAY" && echo ""
        git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
        cd /tmp/yay-bin || exit
        makepkg -si --noconfirm
        cd .. && rm -rf /tmp/yay-bin
        log_prompt "SUCCESS" && echo "Terminée" && echo ""

        # Generate yay database
        yay -Y --gendb

        # Update the system and AUR packages, including development packages
        yay -Syu --devel --noconfirm

        # Save the current development packages
        yay -Y --devel --save

    else
        log_prompt "WARNING" && echo "YAY est déja installé" && echo ""
    fi
fi

if [[ "$PARU" == "On" ]]; then
    if ! command -v paru &> /dev/null; then
            log_prompt "INFO" && echo "Installation de PARU" && echo ""
        git clone https://aur.archlinux.org/paru.git
        cd paru || exit
        makepkg -si --noconfirm
        cd .. && rm -rf paru
        log_prompt "SUCCESS" && echo "Terminée" && echo ""

    else
        log_prompt "WARNING" && echo "PARU est déja installé" && echo ""
    fi
fi

yay -S alacritty waybar-git nautilus rofi-wayland dunst grim slurp --noconfirm

# INSTALL HYPRLAND
# - hyprutils
yay -S cmake gcc make --noconfirm
git clone --recursive https://github.com/hyprwm/hyprutils.git
cd hyprutils && hyprBuildInstall all && cd ..

# - hyprlang
yay -S gcc-libs glibc --noconfirm
git clone --recursive https://github.com/hyprwm/hyprlang.git
cd hyprlang && hyprBuildInstall hyprlang && cd ..

# - hyprcursor
yay -S cairo libzip librsvg tomlplusplus gdb --noconfirm
git clone --recursive https://github.com/hyprwm/hyprutils.git
cd hyprcursor && hyprBuildInstall all && cd ..

# - hyprwayland-scanner
yay -S pugixml --noconfirm
git clone --recursive https://github.com/hyprwm/hyprwayland-scanner.git
cd hyprwayland-scanner
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build
cd ..

# - xdg-desktop-portal-hyprland
yay -S libdrm libpipewire sdbus-cpp wayland qt6-base qt6-wayland xdg-desktop-portal wayland-protocols scdoc --noconfirm
git clone --recursive https://github.com/hyprwm/xdg-desktop-portal-hyprland
cd xdg-desktop-portal-hyprland
cmake -DCMAKE_INSTALL_LIBEXECDIR=/usr/lib -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build
sudo cmake --install build
cd ..

# - aquamarine
yay -S hwdata --noconfirm
git clone --recursive https://github.com/hyprwm/aquamarine.git
cd aquamarine && hyprBuildInstall all && cd ..

# - Hyprland
yay -S gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus xcb-util-errors --noconfirm
git clone --recursive https://github.com/hyprwm/Hyprland
cd Hyprland
make all && sudo make install
cd ..

# - hyprpaper
yay -S pango libjpeg-turbo libglvnd libwebp --noconfirm
git clone --recursive https://github.com/hyprwm/hyprpaper.git
cd hyprpaper && hyprBuildInstall hyprpaper && cd ..

# - hyprlock
yay -S pam --noconfirm
git clone --recursive https://github.com/hyprwm/hyprlock.git
cd hyprlock && hyprBuildInstall hyprlock && cd ..

cd ..
rm -rf $workDirName