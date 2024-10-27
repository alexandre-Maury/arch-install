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
timedatectl set-ntp true
timedatectl set-timezone ${REGION}/${CITY}
localectl set-locale LANG="${LANG}" LC_TIME="${LANG}"
hwclock --systohc --utc

timedatectl status

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installation de YAY && PARU                                                 
##############################################################################
cd /tmp

git clone https://aur.archlinux.org/yay.git
git clone https://aur.archlinux.org/paru.git

cd /tmp/paru && makepkg -si
cd /tmp/yay && makepkg -si

paru -Syu