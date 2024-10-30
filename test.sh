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
if ! command -v yay &> /dev/null; then
    log_prompt "INFO" && echo "Installation de YAY" && echo ""
    git clone https://aur.archlinux.org/yay-bin.git /tmp/yay-bin
    cd /tmp/yay-bin || exit
    makepkg -si --noconfirm
    cd .. && rm -rf /tmp/yay-bin
    log_prompt "SUCCESS" && echo "Terminée" && echo ""

else
    log_prompt "INFO" && echo "YAY est déja installé" && echo ""
fi

# if ! command -v paru &> /dev/null; then
#         log_prompt "INFO" && echo "Installation de PARU" && echo ""
#     git clone https://aur.archlinux.org/paru.git
#     cd paru || exit
#     makepkg -si --noconfirm
#     cd .. && rm -rf paru
#     log_prompt "SUCCESS" && echo "Terminée" && echo ""

# else
#     log_prompt "INFO" && echo "PARU est déja installé" && echo ""
# fi


##############################################################################
## Fonts (a tester)                                              
##############################################################################
# mkdir -p /tmp/nerdfonts && cd /tmp/nerdfonts
# wget https://github.com/ryanoasis/nerd-fonts/releases/download/v2.3.1/CascadiaCode.zip
# unzip '*.zip' -d $HOME/Downloads/nerdfonts/
# rm -rf *.zip
# sudo cp -R $HOME/Downloads/nerdfonts/ ~/.local/share/fonts
# fc-cache -rv  

sudo yay -S --noconfirm --needed \
    ttf-cascadia-code-nerd \ 
    ttf-cascadia-mono-nerd \ 
    ttf-fira-code \ 
    ttf-fira-mono \ 
    ttf-fira-sans \ 
    ttf-firacode-nerd \ 
    ttf-iosevka-nerd \ 
    ttf-iosevkaterm-nerd \ 
    ttf-jetbrains-mono-nerd \ 
    ttf-jetbrains-mono \ 
    ttf-nerd-fonts-symbols \ 
    ttf-nerd-fonts-symbols \ 
    ttf-nerd-fonts-symbols-mono \