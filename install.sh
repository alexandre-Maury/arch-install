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
timedatectl set-ntp true && pacman -Syy

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
log_prompt "INFO" && echo "Bienvenue dans le script d'installation de Arch Linux !" && echo ""

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
else
    # Si l'utilisateur répond N ou n
    log_prompt "WARNING" && echo "Modifier le fichier config.sh."
    log_prompt "ERROR" && echo "Annulation de l'installation."
    exit 0
fi


##############################################################################
## Création des partitions + formatage et montage                                                      
##############################################################################


while true; do

    # Affichage de la table des partitions pour vérification
    parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }

    log_prompt "INFO" && read -p "Voulez-vous nettoyer le disque ${DISK} (Y/n) : " DISKCLEAN && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$DISKCLEAN" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y/y (oui) ou N/n (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$DISKCLEAN" =~ ^[yY]$ ]]; then
    # Effacement du disque
    log_prompt "INFO" && echo "Préparation du disque dur /dev/${DISK}" && echo ""

    # Vérification que le disque existe
    if [[ ! -b "/dev/$DISK" ]]; then
        log_prompt "ERROR" && echo "le disque spécifié (${DISK}) n'existe pas." && echo ""
        exit 1
    fi

    # Liste les partitions du disque
    PARTITIONS=$(lsblk -ln -o NAME "/dev/${DISK}" | grep -E "${DISK}[0-9]+")
    if [[ -z $PARTITIONS ]]; then
        log_prompt "INFO" && echo "Aucune partition trouvée sur ${DISK}." && echo ""
    else
        log_prompt "INFO" && echo "Partitions trouvées sur ${DISK} :" && echo ""
        echo "$PARTITIONS" && echo ""
        
        # Boucle pour supprimer chaque partition
        for PART in $PARTITIONS; do

            PART_PATH="/dev/${PART}"

            # Désactiver le swap si la partition est configurée comme swap
            if swapon --show=NAME | grep -q "${PART_PATH}"; then
                echo "Désactivation du swap sur ${PART_PATH}..."
                swapoff "${PART_PATH}" || { echo "Erreur lors de la désactivation du swap sur ${PART_PATH}"; exit 1; }
            fi

            # Vérifie si la partition est montée
            if mount | grep -q "${PART_PATH}"; then
                echo "Démontage de ${PART_PATH}..."
                umount --force --recursive "${PART_PATH}" || { log_prompt "INFO" && echo "Impossible de démonter ${PART_PATH}."; }
            fi

            PART_NUM=${PART##*[^0-9]}  # Récupère le numéro de la partition
            log_prompt "INFO" && echo "Suppression de la partition ${DISK}${PART_NUM}..." && echo ""
            parted "/dev/${DISK}" --script rm "${PART_NUM}" || { log_prompt "ERROR" && echo "Erreur lors de la suppression de ${DISK}${PART_NUM}"; exit 1; }
        done
    fi

    log_prompt "SUCCESS" && echo "Toutes les partitions ont été supprimées du disque ${DISK}." && echo ""

    wipefs --force --all /dev/${DISK} || { echo "Erreur lors de l'effacement du disque"; exit 1; }
    shred -n "${SHRED_PASS}" -v "/dev/${DISK}" || { echo "Erreur lors de l'effacement sécurisé"; exit 1; }

else
    log_prompt "INFO" && echo "Suite de l'installation" && echo ""
fi


# Détermination du mode (UEFI ou MBR)
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="MBR"
fi

# Réinitialisation de la table de partitions
if [[ "${MODE}" == "UEFI" ]]; then
    parted --script -a optimal /dev/${DISK} mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }
    parted --script -a optimal /dev/${DISK} mkpart primary fat32 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 esp on
else
    parted --script -a optimal /dev/${DISK} mklabel msdos || { echo "Erreur lors de la création de la table MBR"; exit 1; }
    parted --script -a optimal /dev/${DISK} mkpart primary ext4 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 boot on
fi

# Si FILE_SWAP est sur "Off", on crée une partition pour le swap
if [[ "${FILE_SWAP}" == "Off" ]]; then

    parted --script -a optimal /dev/${DISK} mkpart primary linux-swap "${SIZE_BOOT}" "${SIZE_SWAP}" || { echo "Erreur lors de la création de la partition swap"; exit 1; }

    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=3
        PART_HOME=""  # Désactivation de la partition home spécifique
    else
        # Création de partitions séparées pour root et home
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=3
        PART_HOME=4
    fi
else
    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=2
        PART_HOME=""  # Désactivation de la partition home spécifique
    else
        # Création de partitions séparées pour root et home
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=2
        PART_HOME=3
    fi
fi

# Formatage de la partition boot en fonction du mode
if [[ "${MODE}" == "UEFI" ]]; then
    mkfs.vfat -F32 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition boot en FAT32"; exit 1; }
else
    mkfs.ext4 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition boot en ext4"; exit 1; }
fi

# Formatage des partitions en fonction du système de fichiers spécifié
mkfs."${FS_TYPE}" /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en "${FS_TYPE}" "; exit 1; }
[[ -n "${PART_HOME}" ]] && mkfs."${FS_TYPE}" /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home en "${FS_TYPE}" "; exit 1; }

# Montage des partitions
mkdir -p "${MOUNT_POINT}" && mount /dev/${DISK}${PART_ROOT} "${MOUNT_POINT}" || { echo "Erreur lors du montage de la partition root"; exit 1; }
mkdir -p "${MOUNT_POINT}/boot" && mount /dev/${DISK}1 "${MOUNT_POINT}/boot" || { echo "Erreur lors du montage de la partition boot"; exit 1; }

# Si root et home sont séparés, monter home
if [[ -n "${PART_HOME}" ]]; then
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home"; exit 1; }
fi

# Gestion de la swap
if [[ "${FILE_SWAP}" == "Off" ]]; then
    mkswap /dev/${DISK}2 || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    swapon /dev/${DISK}2 || { echo "Erreur lors de l'activation de la partition swap"; exit 1; }
else
    # Création d'un fichier swap si FILE_SWAP="On"
    log_prompt "INFO" && echo "création du fichier swap" && echo ""
    mkdir -p $MOUNT_POINT/swap
    dd if=/dev/zero of="$MOUNT_POINT/swap/swapfile" bs=1G count="${SIZE_SWAP}" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    chmod 600 "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors du changement des permissions du fichier swap"; exit 1; }
    mkswap "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    swapon "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de l'activation du fichier swap"; exit 1; }
fi

# Fin du script
echo "Partitionnement et formatage terminés avec succès !"

# Affichage de la table des partitions pour vérification
parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }

# Fin du script
echo "Script terminé avec succès !"

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