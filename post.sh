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
log_prompt "SUCCESS" && echo "Terminée" && echo ""