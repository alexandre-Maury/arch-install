#!/usr/bin/bash

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

# WORK IN TEMP DIR
workDirName="${HOME}/buildHypr";
rm -rf $workDirName
mkdir -p $workDirName

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

##############################################################################
## Fonts Installation                                            
##############################################################################
mkdir -p ~/.local/share/fonts && cd ~/.local/share/fonts

# Télécharger chaque fichier seulement s'il n'existe pas déjà
for url in "${URL_FONTS[@]}"; do
  file_name=$(basename "$url")
  if [ ! -f "$file_name" ]; then
    log_prompt "INFO" && echo "Téléchargement de $file_name" && echo ""
    curl -fLO "$url"
  else
    log_prompt "WARNING" && echo "$file_name existe déjà, fonts ignoré" && echo ""
  fi
done

##############################################################################
## Installation des utilitaires                                                 
##############################################################################
yay -S alacritty nautilus rofi-wayland dunst grim slurp \
    iw wpa_supplicant bluez bluez-utils blueman seatd \
    alsa-utils alsa-plugins pipewire pipewire-alsa \
    pipewire-pulse pipewire-jack pipewire-zeroconf \
    lib32-pipewire lib32-pipewire-jack wireplumber \
    lxappearance --noconfirm

yay -S cmake gcc make glibc cairo libzip librsvg tomlplusplus gdb pugixml gbm libdrm libpipewire sdbus-cpp wayland wayland-protocols scdoc \
    qt5-wayland qt6-wayland libjpeg-turbo libwebp pango pkgconf libglvnd pam udis-86 libxcb xcb-proto xcb-util xcb-util-keysyms \
    libxfixes libx11 libxcomposite xorg-xinput libxrender pixman libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info \
    cpio xcb-util-errors otf-font-awesome ttf-jetbrains-mono waybar --noconfirm

# https://github.com/Jannomag/Yaru-Colors/tree/master
# yay -S humanity-icon-theme yaru-icon-theme hicolor-icon-theme


##############################################################################
## hyprutils                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprutils" && echo ""

git clone --recursive https://github.com/hyprwm/hyprutils.git $workDirName/hyprutils
cd $workDirName/hyprutils
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..


##############################################################################
## hyprlang                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprlang" && echo ""

git clone --recursive https://github.com/hyprwm/hyprlang.git $workDirName/hyprlang
cd $workDirName/hyprlang
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target hyprlang -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..


##############################################################################
## hyprcursor                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprcursor" && echo ""

git clone --recursive https://github.com/hyprwm/hyprcursor.git $workDirName/hyprcursor
cd $workDirName/hyprcursor
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..

##############################################################################
## hyprwayland-scanner                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprwayland-scanner" && echo ""

git clone --recursive https://github.com/hyprwm/hyprwayland-scanner.git $workDirName/hyprwayland-scanner
cd $workDirName/hyprwayland-scanner
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build
cd ..

##############################################################################
## hyprland-protocols                                          
##############################################################################
log_prompt "INFO" && echo "Installation de hyprland-protocols" && echo ""

git clone --recursive https://github.com/hyprwm/hyprland-protocols.git $workDirName/hyprland-protocols
cd $workDirName/hyprland-protocols
meson setup build
ninja -C build
sudo ninja -C build install

##############################################################################
## xdg-desktop-portal-hyprland                                              
##############################################################################
log_prompt "INFO" && echo "Installation de xdg-desktop-portal-hyprland" && echo ""
# libpipewire-0.3 libspa-0.2 

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
cd $workDirName/aquamarine
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..

##############################################################################
## hyprpaper                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprpaper" && echo ""

git clone --recursive https://github.com/hyprwm/hyprpaper.git $workDirName/hyprpaper
cd $workDirName/hyprpaper
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target hyprpaper -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..


##############################################################################
## hyprlock                                              
##############################################################################
log_prompt "INFO" && echo "Installation de hyprlock" && echo ""

git clone --recursive https://github.com/hyprwm/hyprlock.git $workDirName/hyprlock
cd $workDirName/hyprlock
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target hyprlock -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build
cd ..


##############################################################################
## Hyprland                                              
##############################################################################
log_prompt "INFO" && echo "Installation de Hyprland" && echo ""

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
cp -rf $SCRIPT_DIR/misc/dots/scripts $HOME

cp -rf $SCRIPT_DIR/misc/dots/icons $HOME/.local/share
cp -rf $SCRIPT_DIR/misc/dots/themes $HOME/.local/share

##############################################################################
## Activation des services                                              
##############################################################################
sudo systemctl enable bluetooth 
sudo systemctl enable fstrim
sudo systemctl enable pipewire
sudo systemctl enable pipewire-pulse
sudo systemctl enable wireplumber
sudo systemctl enable seatd


##############################################################################
## clean                                              
##############################################################################
cd ..
rm -rf $workDirName