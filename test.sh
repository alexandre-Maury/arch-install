#!/bin/bash

# script install.sh

# https://github.com/Senshi111/debian-hyprland-hyprdots
# https://github.com/nawfalmrouyan/hyprland
# https://forum.linuxos.ovh/d/200-installer-et-configurer-hyprland-avec-waybar

# run_command "mkdir -p /home/$SUDO_USER/.config/hypr/ && cp -r /home/$SUDO_USER/simple-hyprland/configs/hypr/hyprland.conf /home/$SUDO_USER/.config/hypr/" "Copy hyprland config (Must)" "yes" "no" 
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/dunst /home/$SUDO_USER/.config/" "Copy dunst config" "yes" "no"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/waybar /home/$SUDO_USER/.config/" "Copy Waybar config" "yes" "no"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/tofi /home/$SUDO_USER/.config/" "Copy Tofi config(s)" "yes" "no"
# run_command "mkdir -p /home/$SUDO_USER/.config/assets/backgrounds && cp -r /home/$SUDO_USER/simple-hyprland/assets/backgrounds /home/$SUDO_USER/.config/assets/" "Copy sample wallpapers to assets directory (Recommended)" "yes" "no"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/hypr/hyprlock.conf /home/$SUDO_USER/.config/hypr/" "Copy Hyprlock config" "yes" "no"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/wlogout /home/$SUDO_USER/.config/ && cp -r /home/$SUDO_USER/simple-hyprland/assets/wlogout /home/$SUDO_USER/.config/assets/" "Copy Wlogout config and assets" "yes" "no"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/hypr/hypridle.conf /home/$SUDO_USER/.config/hypr/" "Copy Hypridle config" "yes" "no"
# run_command "tar -xvf /home/$SUDO_USER/simple-hyprland/assets/themes/Catppuccin-Mocha.tar.xz -C /usr/share/themes/" "Install Catppuccin Mocha GTK theme" "yes" 
# run_command "tar -xvf /home/$SUDO_USER/simple-hyprland/assets/icons/Tela-circle-dracula.tar.xz -C /usr/share/icons/" "Install Tela Circle Dracula icon theme" "yes"
# run_command "cp -r /home/$SUDO_USER/simple-hyprland/configs/kitty /home/$SUDO_USER/.config/" "Copy Catppuccin theme configuration for Kitty terminal" "yes" "no"

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

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

fc-cache -rv  

log_prompt "INFO" && echo "installation des dépendances système (librairies, protocoles, utilitaires)" && echo ""

yay -S gcc gdb wlroots \
    vim git tar wget bash-completion iw wpa_supplicant \
    bluez bluez-utils blueman alsa-utils alsa-plugins seatd \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack pipewire-zeroconf \
    kitty alacritty lib32-pipewire lib32-pipewire-jack wireplumber --noconfirm

yay -S libxcb xcb-proto xcb-util xcb-util-keysyms \
    libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols \
    cairo pango libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff \
    libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner \
    xcb-util-errors hyprutils hyprpaper hyprlock hypridle qt5-wayland \
    qt6-wayland xdg-desktop-portal-hyprland polkit-kde-agent \
    waybar swaync rofi-wayland udiskie hyprnome aquamarine wofi alacritty kitty dolphin --noconfirm

log_prompt "INFO" && echo "Clonage du dépôt Hyprland" && echo ""
git clone --recursive https://github.com/hyprwm/Hyprland.git ~/Hyprland
cd ~/Hyprland || exit

log_prompt "INFO" && echo "Compilation et installation de Hyprland" && echo ""
meson setup build
ninja -C build
sudo ninja -C build install

log_prompt "INFO" && echo "Nettoyage des fichiers temporaires" && echo ""
cd .. && rm -rf ~/Hyprland

log_prompt "INFO" && echo "Création des dossiers de configuration" && echo ""

mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/dunst
mkdir -p ~/.config/hyprpaper/background

log_prompt "INFO" && echo "Copie de l'image d'arrière plan" && echo ""
cp -rf $SCRIPT_DIR/misc/background/bg.jpg ~/.config/hyprpaper/background

log_prompt "INFO" && echo "Configuration hyprpaper" && echo ""
cp -rf $SCRIPT_DIR/misc/dots/hyprpaper/hyprpaper.conf ~/.config/hyprpaper

log_prompt "INFO" && echo "Configuration hyprland" && echo ""
cp -rf $SCRIPT_DIR/misc/dots/hyprland/hyprland.conf ~/.config/hypr

log_prompt "INFO" && echo "Configuration waybar" && echo ""
cp -rf $SCRIPT_DIR/misc/dots/waybar/config ~/.config/waybar
cp -rf $SCRIPT_DIR/misc/dots/waybar/style.css ~/.config/waybar

sudo systemctl enable bluetooth 
sudo systemctl enable fstrim
sudo systemctl enable pipewire
sudo systemctl enable pipewire-pulse
sudo systemctl enable wireplumber
sudo systemctl enable seatd

log_prompt "SUCCESS" && echo "Installation Terminée" && echo ""