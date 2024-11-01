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
## Installation de YAY                                               
##############################################################################
if [[ "$YAY" == "On" ]]; then
    if ! command -v yay &> /dev/null; then
        log_prompt "INFO" && echo "Installation de YAY" && echo ""
        git clone https://aur.archlinux.org/yay-bin.git $workDirName/yay-bin
        cd $workDirName/yay-bin || exit
        makepkg -si --noconfirm && cd .. 
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

##############################################################################
## Installation de PARU                                                 
##############################################################################
if [[ "$PARU" == "On" ]]; then
    if ! command -v paru &> /dev/null; then
        log_prompt "INFO" && echo "Installation de PARU" && echo ""
        git clone https://aur.archlinux.org/paru.git $workDirName/paru
        cd $workDirName/paru || exit
        makepkg -si --noconfirm && cd .. 
        log_prompt "SUCCESS" && echo "Terminée" && echo ""

    else
        log_prompt "WARNING" && echo "PARU est déja installé" && echo ""
    fi
fi

yay -S alacritty waybar-git nautilus rofi-wayland dunst grim slurp --noconfirm


##############################################################################
## hyprutils                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprutils" && echo ""
yay -S cmake gcc make --noconfirm
git clone --recursive https://github.com/hyprwm/hyprutils.git $workDirName/hyprutils
cd $workDirName/hyprutils && hyprBuildInstall all && cd ..


##############################################################################
## hyprlang                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprlang" && echo ""
yay -S gcc-libs glibc --noconfirm
git clone --recursive https://github.com/hyprwm/hyprlang.git $workDirName/hyprlang
cd $workDirName/hyprlang && hyprBuildInstall hyprlang && cd ..


##############################################################################
## hyprcursor                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprcursor" && echo ""
yay -S cairo libzip librsvg tomlplusplus gdb --noconfirm
git clone --recursive https://github.com/hyprwm/hyprutils.git $workDirName/hyprcursor
cd $workDirName/hyprcursor && hyprBuildInstall all && cd ..


##############################################################################
## hyprwayland-scanner                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprwayland-scanner" && echo ""
yay -S pugixml --noconfirm
git clone --recursive https://github.com/hyprwm/hyprwayland-scanner.git $workDirName/hyprwayland-scanner
cd $workDirName/hyprwayland-scanner
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build
cd ..


##############################################################################
## xdg-desktop-portal-hyprland                                              
##############################################################################
log_prompt "INFO" && echo "Installation de xdg-desktop-portal-hyprland" && echo ""
yay -S libdrm libpipewire sdbus-cpp wayland qt6-base qt6-wayland xdg-desktop-portal wayland-protocols scdoc --noconfirm
git clone --recursive https://github.com/hyprwm/xdg-desktop-portal-hyprland $workDirName/xdg-desktop-portal-hyprland
cd $workDirName/xdg-desktop-portal-hyprland
cmake -DCMAKE_INSTALL_LIBEXECDIR=/usr/lib -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build
sudo cmake --install build
cd ..


##############################################################################
## aquamarine                                              
##############################################################################
log_prompt "INFO" && echo "Installation de aquamarine" && echo ""
yay -S hwdata --noconfirm
git clone --recursive https://github.com/hyprwm/aquamarine.git $workDirName/aquamarine
cd $workDirName/aquamarine && hyprBuildInstall all && cd ..

##############################################################################
## hyprpaper                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprpaper" && echo ""
yay -S pango libjpeg-turbo libglvnd libwebp --noconfirm
git clone --recursive https://github.com/hyprwm/hyprpaper.git $workDirName/hyprpaper
cd $workDirName/hyprpaper && hyprBuildInstall hyprpaper && cd ..


##############################################################################
## hyprlock                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprlock" && echo ""
yay -S pam --noconfirm
git clone --recursive https://github.com/hyprwm/hyprlock.git $workDirName/hyprlock
cd $workDirName/hyprlock && hyprBuildInstall hyprlock && cd ..


##############################################################################
## Hyprland                                              
##############################################################################
log_prompt "INFO" && echo "Installation de Hyprland" && echo ""
yay -S gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus xcb-util-errors --noconfirm
git clone --recursive https://github.com/hyprwm/Hyprland $workDirName/Hyprland
cd $workDirName/Hyprland
make all && sudo make install
cd ..

##############################################################################
## Configuration                                              
##############################################################################
cp -rf $SCRIPT_DIR/misc/dots/config/alacritty ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/dunst ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/fastfetch ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/hypr ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/rofi ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/waybar ~/.config
cp -rf $SCRIPT_DIR/misc/dots/config/alacritty ~/.config

cp -rf $SCRIPT_DIR/misc/dots/wallpaper $HOME


##############################################################################
## clean                                              
##############################################################################
cd ..
rm -rf $workDirName