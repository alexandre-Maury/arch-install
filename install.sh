#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.

##############################################################################
## Valide la connexion internet                                                          
##############################################################################
log_prompt "INFO" && echo "Vérification de la connexion Internet" && echo ""

if ! ping -c1 -w1 1.1.1.1 > /dev/null 2>&1; then
    log_prompt "ERROR" && echo "Pas de connexion Internet"
    exit 1
else
    log_prompt "SUCCESS" && echo "Terminée" && echo ""
fi

##############################################################################
## Mettre à jour l'horloge du système                                                     
##############################################################################
timedatectl set-ntp true

##############################################################################
## Valide les applications pour le bon fonctionnement du script                                                          
##############################################################################
for pkg in "${packages[@]}"; do
    check_and_install "$pkg" # S'assurer que les packages requis sont installés
done

clear 

##############################################################################
## Bienvenu                                                    
##############################################################################
log_prompt "INFO" && echo "Bienvenue dans le script d'installation de Gentoo !" && echo ""

##############################################################################
## Récupération des disques disponible                                                      
##############################################################################

# LIST="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

# echo "${LIST}"
# OPTION=""

# while [[ -z "$(echo "${LIST}" | grep "  ${OPTION})")" ]]; do
#     printf "Choisissez un disque pour la suite de l'installation (ex : 1) : "
#     read -r OPTION
# done

# DISK="$(echo "${LIST}" | grep "  ${OPTION})" | awk '{print $2}')"
# log_prompt "SUCCESS" "Terminée" && echo ""

# Générer la liste des disques physiques sans les disques loop et sr (CD/DVD)
LIST="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

if [[ -z "${LIST}" ]]; then
    log_prompt "ERROR" && echo "Aucun disque disponible pour l'installation."
    exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
else
    log_prompt "INFO" && echo "Choisissez un disque pour l'installation (ex : 1) : " && echo ""
    echo "${LIST}" && echo ""
fi


# Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
OPTION=""
while [[ -z "$(echo "${LIST}" | grep "  ${OPTION})")" ]]; do
    log_prompt "INFO" && read -p "Votre Choix : " OPTION
    echo ""

    # Vérification si l'utilisateur a entré un numéro (choix dans la liste)
    if [[ -n "$(echo "${LIST}" | grep "  ${OPTION})")" ]]; then
        # Si l'utilisateur a choisi un numéro valide, récupérer le nom du disque correspondant
        DISK="$(echo "${LIST}" | grep "  ${OPTION})" | awk '{print $2}')"
        break
    else
        # Si l'utilisateur a entré quelque chose qui n'est pas dans la liste, considérer que c'est un nom de disque
        DISK="${OPTION}"
        break
    fi
done

##############################################################################
## Validation de la configuration                                                       
##############################################################################
clear

echo "[ ${DISK} ]"                   "- Disque"
echo "[ ${MODE} ]"                   "- Mode"
echo "[ ${REGION} ]"                 "- Zone Info - region" 
echo "[ ${CITY} ]"                   "- Zone Info - city" 
echo "[ ${LOCALE} ]"                 "- Locale" 
echo "[ ${HOSTNAME} ]"               "- Nom d'hôte" 
echo "[ ${INTERFACE} ]"              "- Interface" 
echo "[ ${KEYMAP} ]"                 "- Disposition du clavier" 
echo "[ ${USERNAME} ]"               "- Votre utilisateur" 
echo ""

# Demande tant que la réponse n'est pas y/Y ou n/N
while true; do

    log_prompt "INFO" && read -p "Vérifiez que les informations ci-dessus sont correctes (Y/n) : " CONFIGURATION && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$CONFIGURATION" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y/y (oui) ou N/n (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$CONFIGURATION" =~ ^[yY]$ ]]; then
    log_prompt "INFO" && echo "Suite de l'installation" && echo ""
    break
else
    # Si l'utilisateur répond N ou n
    log_prompt "WARNING" && echo "Modifier le fichier config.sh."
    log_prompt "ERROR" && echo "Annulation de l'installation."
    exit 0
fi


##############################################################################
## Création des partitions + formatage et montage                                                      
##############################################################################
bash disk.sh $DISK $MOUNT_POINT

clear
parted /dev/"${DISK}" print
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installation du système de base                                                
##############################################################################
pacstrap -K ${MOUNT_POINT} base linux linux-firmware

##############################################################################
## Chroot dans le nouvelle environnement                                             
##############################################################################
log_prompt "INFO" && echo "Copie de la deuxième partie du script d'installation dans le nouvel environnement" && echo ""

cp functions.sh $MOUNT_POINT
cp config.sh $MOUNT_POINT
cp chroot.sh $MOUNT_POINT

log_prompt "INFO" && echo "Entrée dans le nouvel environnement et exécution de la deuxième partie du script" && echo ""

chroot $MOUNT_POINT /bin/bash -c "./chroot.sh $DISK"

log_prompt "SUCCESS" && echo "Terminée" && echo ""