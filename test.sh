#!/bin/bash

# script install.sh

# https://github.com/Senshi111/debian-hyprland-hyprdots
# https://github.com/nawfalmrouyan/hyprland

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


log_prompt "INFO" && echo "installation des dépendances" && echo ""
sudo yay -S --needed --noconfirm \
  base-devel \
  cmake \
  meson \
  ninja \
  wayland \
  wlroots \
  xdg-desktop-portal-hyprland \
  aquamarine \
  hyprwayland-scanner \
  hyprcursor \
  hyprlang \
  xorg-server-devel \
  swaybg \
  kitty \
  alacritty \
  polkit-kde-agent \
  dunst \
  rofi \
  qt5-wayland \
  qt6-wayland

log_prompt "INFO" && echo "Clonage du dépôt Hyprland" && echo ""
git clone --recursive https://github.com/hyprwm/Hyprland.git ~/Hyprland
cd ~/Hyprland || exit

log_prompt "INFO" && echo "Compilation et installation de Hyprland" && echo ""
meson setup build
ninja -C build
sudo ninja -C build install


log_prompt "INFO" && echo "Nettoyage des fichiers temporaires" && echo ""
cd .. && rm -rf ~/Hyprland