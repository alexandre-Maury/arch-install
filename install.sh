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
# for pkg in "${packages[@]}"; do
#     check_and_install "$pkg" # S'assurer que les packages requis sont installés
# done

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
# bash disk.sh $DISK $MOUNT_POINT

# Effacement du disque
wipefs --force --all /dev/${DISK} || { echo "Erreur lors de l'effacement du disque"; exit 1; }
shred -n "${SHRED_PASS}" -v "/dev/${DISK}"

# Réinitialisation de la table de partitions GPT
sgdisk -Z /dev/${DISK} || { echo "Erreur lors de la réinitialisation du disque"; exit 1; }
sgdisk -a 2048 -o /dev/${DISK} || { echo "Erreur lors de la configuration GPT"; exit 1; }

# Création des partitions
sgdisk -n 0:0:+"${SIZE_BOOT}" -t 0:EF00 -c 0:"boot" /dev/${DISK} || { echo "Erreur lors de la création de la partition boot"; exit 1; }

# Si FILE_SWAP est sur "Off", on crée une partition pour le swap
if [[ "${FILE_SWAP}" == "Off" ]]; then
    sgdisk -n 0:0:+"${SIZE_SWAP}" -t 0:8200 -c 0:"swap" /dev/${DISK} || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    PART_ROOT=3
    PART_HOME=4
else
    PART_ROOT=2
    PART_HOME=3
fi

# Gestion de la fusion root et home
if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
    # Création d'une seule partition pour root + home
    sgdisk -n 0:0:"${SIZE_HOME}" -t 0:8302 -c 0:"root_home" /dev/${DISK} || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
    PART_HOME=""  # Désactivation de la partition home spécifique
else
    # Création de partitions séparées pour root et home
    sgdisk -n 0:0:+"${SIZE_ROOT}" -t 0:8302 -c 0:"root" /dev/${DISK} || { echo "Erreur lors de la création de la partition root"; exit 1; }
    sgdisk -n 0:0:"${SIZE_HOME}" -t 0:8300 -c 0:"home" /dev/${DISK} || { echo "Erreur lors de la création de la partition home"; exit 1; }
fi

# Formatage de la partition boot en FAT32 (pour UEFI)
mkfs.vfat -F32 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition boot en FAT32"; exit 1; }

# Formatage des partitions en fonction du système de fichiers spécifié
case "${FS_TYPE}" in
    ext4)
        mkfs.ext4 /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en ext4"; exit 1; }
        [[ -n "${PART_HOME}" ]] && mkfs.ext4 /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home en ext4"; exit 1; }
        ;;
    btrfs)
        mkfs.btrfs /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en btrfs"; exit 1; }
        [[ -n "${PART_HOME}" ]] && mkfs.btrfs /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home en btrfs"; exit 1; }
        ;;
    xfs)
        mkfs.xfs /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en xfs"; exit 1; }
        [[ -n "${PART_HOME}" ]] && mkfs.xfs /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home en xfs"; exit 1; }
        ;;
    *)
        echo "Système de fichiers non pris en charge : ${FS_TYPE}"; exit 1
        ;;
esac

# Gestion de la swap
if [[ "${FILE_SWAP}" == "Off" ]]; then
    mkswap /dev/${DISK}2 || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    swapon /dev/${DISK}2 || { echo "Erreur lors de l'activation de la partition swap"; exit 1; }
else
    # Création d'un fichier swap si FILE_SWAP="On"
    dd if=/dev/zero of="${MOUNT_POINT}/swapfile" bs=1M count=$(echo "${SIZE_SWAP}" | sed 's/[^0-9]//g') || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    chmod 600 "${MOUNT_POINT}/swapfile" || { echo "Erreur lors du changement des permissions du fichier swap"; exit 1; }
    mkswap "${MOUNT_POINT}/swapfile" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    swapon "${MOUNT_POINT}/swapfile" || { echo "Erreur lors de l'activation du fichier swap"; exit 1; }
fi

# Montage des partitions
mount /dev/${DISK}${PART_ROOT} "${MOUNT_POINT}" || { echo "Erreur lors du montage de la partition root"; exit 1; }
mkdir -p "${MOUNT_POINT}/boot" && mount /dev/${DISK}1 "${MOUNT_POINT}/boot" || { echo "Erreur lors du montage de la partition boot"; exit 1; }

# Si root et home sont séparés, monter home
if [[ -n "${PART_HOME}" ]]; then
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home"; exit 1; }
fi

# Fin du script
echo "Partitionnement et formatage terminés avec succès !"


clear
# Affichage de la table des partitions pour vérification
sgdisk -p /dev/${DISK} || { echo "Erreur lors de l'affichage des partitions"; exit 1; }
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installation du système de base                                                
##############################################################################
# reflector --country ${PAYS} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
# pacstrap -K ${MOUNT_POINT} base linux linux-firmware

##############################################################################
## Chroot dans le nouvelle environnement                                             
##############################################################################
# log_prompt "INFO" && echo "Copie de la deuxième partie du script d'installation dans le nouvel environnement" && echo ""

# cp functions.sh $MOUNT_POINT
# cp config.sh $MOUNT_POINT
# cp chroot.sh $MOUNT_POINT

# log_prompt "INFO" && echo "Entrée dans le nouvel environnement et exécution de la deuxième partie du script" && echo ""

# chroot $MOUNT_POINT /bin/bash -c "./chroot.sh $DISK"

# log_prompt "SUCCESS" && echo "Terminée" && echo ""