#!/bin/bash

# script install.sh : 
# Script test
# https://github.com/Zelrin/arch-btrfs-install-guide 
# https://sharafat.pages.dev/archlinux-install/
# https://chadymorra.github.io/

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.


# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
  log_prompt "ERROR" && echo "Veuillez exécuter ce script en tant qu'utilisateur root."
  exit 1
fi


##############################################################################
## Récupération des disques disponible                                                      
##############################################################################
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
    log_prompt "INFO" && read -p "Votre Choix : " OPTION && echo ""
    

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
## Création des partitions + formatage et montage                                                      
##############################################################################
if [[ "${MODE}" == "UEFI" ]]; then
    log_prompt "INFO" && echo "Création de la table GPT" && echo ""
    parted --script -a optimal /dev/${DISK} mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""

    log_prompt "INFO" && echo "Création de la partition EFI"
    parted --script -a optimal /dev/${DISK} mkpart primary fat32 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 esp on
    log_prompt "SUCCESS" && echo "OK" && echo ""
fi

if  [[ "${ENABLE_SWAP}" == "On" ]] && [[ "${FILE_SWAP}" == "Off" ]]; then
    log_prompt "INFO" && echo "Création de la partition SWAP"
    parted --script -a optimal /dev/${DISK} mkpart primary linux-swap "${SIZE_BOOT}" "${SIZE_SWAP}" || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""

    log_prompt "INFO" && echo "Activation du SWAP"
    mkswap /dev/${DISK}2 || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    swapon /dev/${DISK}2 || { echo "Erreur lors de l'activation de la partition swap"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""

    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        log_prompt "INFO" && echo "Création de la partition ROOT/HOME"
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=3
        PART_HOME=""  # Désactivation de la partition home spécifique
        log_prompt "SUCCESS" && echo "OK" && echo ""
    else
        log_prompt "INFO" && echo "Création de la partition ROOT"
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo ""

        log_prompt "INFO" && echo "Création de la partition HOME"
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=3
        PART_HOME=4
        log_prompt "SUCCESS" && echo "OK" && echo ""
    fi

else # Le swap est désactiver

    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        log_prompt "INFO" && echo "Création de la partition ROOT/HOME"
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=2
        PART_HOME=""  # Désactivation de la partition home spécifique
        log_prompt "SUCCESS" && echo "OK" && echo ""
    else
        # Création de partitions séparées pour root et home
        log_prompt "INFO" && echo "Création de la partition ROOT" 
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo ""
        
        log_prompt "INFO" && echo "Création de la partition HOME"
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=2
        PART_HOME=3
        log_prompt "SUCCESS" && echo "OK" && echo ""
    fi
fi

# Formatage des partitions en fonction du système de fichiers spécifié
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT/HOME ==> /dev/${DISK}${PART_ROOT}" 
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT ==> /dev/${DISK}${PART_ROOT}" 
mkfs."${FS_TYPE}" /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en "${FS_TYPE}" "; exit 1; }
log_prompt "SUCCESS" && echo "OK" && echo ""

# Montage des partitions
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT/HOME ==> /dev/${DISK}${PART_ROOT}" 
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT ==> /dev/${DISK}${PART_ROOT}" 
mkdir -p "${MOUNT_POINT}" && mount /dev/${DISK}${PART_ROOT} "${MOUNT_POINT}" || { echo "Erreur lors du montage de la partition root"; exit 1; }
log_prompt "SUCCESS" && echo "OK" && echo ""

if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition HOME ==> /dev/${DISK}${PART_HOME}" 
    mkfs."${FS_TYPE}" /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home ==> /dev/${DISK}${PART_HOME} en "${FS_TYPE}" "; exit 1; }
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home ==> /dev/${DISK}${PART_HOME}"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""
fi

# Si root et home sont séparés, monter home
if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Création du point de montage de la partition HOME ==> /dev/${DISK}${PART_HOME}" 
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home ==> /dev/${DISK}${PART_HOME}"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""
fi

# Formatage de la partition boot en fonction du mode
if [[ "${MODE}" == "UEFI" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition EFI" 
    mkfs.vfat -F32 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition efi en FAT32"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""

    log_prompt "INFO" && echo "Création du point de montage de la partition EFI" 
    mkdir -p "${MOUNT_POINT}/boot" && mount /dev/${DISK}1 "${MOUNT_POINT}/boot" || { echo "Erreur lors du montage de la partition boot"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""
fi

# Gestion de la swap
if [[ "${ENABLE_SWAP}" == "On" ]] && [[ "${FILE_SWAP}" == "On" ]]; then
    # Création d'un fichier swap si FILE_SWAP="On"
    log_prompt "INFO" && echo "création du dossier $MOUNT_POINT/swap" 
    mkdir -p $MOUNT_POINT/swap
    log_prompt "SUCCESS" && echo "OK" && echo ""

    log_prompt "INFO" && echo "création du fichier $MOUNT_POINT/swap/swapfile" 
    dd if=/dev/zero of="$MOUNT_POINT/swap/swapfile" bs=1G count="${SIZE_SWAP}" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""

    log_prompt "INFO" && echo "Permission + activation du fichier $MOUNT_POINT/swap/swapfile" 
    chmod 600 "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors du changement des permissions du fichier swap"; exit 1; }
    mkswap "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    swapon "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de l'activation du fichier swap"; exit 1; }
    log_prompt "SUCCESS" && echo "OK" && echo ""
fi

# Affichage de la table des partitions pour vérification
parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }





# # Formatage des partitions
# echo "Formatage de la partition /boot..."
# mkfs.fat -F32 "${DISK}p1"  # La partition /boot

# echo "Formatage des partitions restantes en Btrfs..."
# mkfs.btrfs "${DISK}p2"  # Partition root

# # Montage de la partition root
# echo "Montage du système de fichiers..."
# mount "${DISK}p2" /mnt

# # Création des sous-volumes Btrfs
# echo "Création des sous-volumes Btrfs..."
# btrfs subvolume create /mnt/@
# btrfs subvolume create /mnt/@home

# # Montage des sous-volumes
# umount /mnt
# mount -o noatime,compress=lzo,subvol=@ "${DISK}p2" /mnt
# mkdir /mnt/home
# mount -o noatime,compress=lzo,subvol=@home "${DISK}p2" /mnt/home

# # Montage de la partition /boot
# mkdir /mnt/boot
# mount "${DISK}p1" /mnt/boot

# # Installation de Arch Linux
# echo "Installation d'Arch Linux..."
# pacstrap /mnt base linux linux-firmware

# # Configuration du système
# echo "Génération de l'fstab..."
# genfstab -U /mnt >> /mnt/etc/fstab

# # Chroot dans le nouveau système
# echo "Chroot dans le système..."
# arch-chroot /mnt /bin/bash <<EOF
# # Configuration du système
# echo "Configuration du système..."

# # Mise à jour du miroir
# pacman -Sy reflector
# reflector --country 'France' --sort rate --save /etc/pacman.d/mirrorlist

# # Installation du bootloader systemd-boot
# bootctl --path=/mnt/boot install

# # Configuration du noyau et initramfs
# mkinitcpio -P

# # Configuration de la locale
# echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
# locale-gen

# # Configuration de la timezone
# ln -sf /usr/share/zoneinfo/Europe/Paris /mnt/etc/localtime

# # Création de l'utilisateur
# useradd -m -G wheel -s /bin/bash user
# echo "user:password" | chpasswd

# # Activation du sudo
# pacman -S sudo
# echo "user ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/user

# # Fin de la configuration
# EOF

# # Sortie du chroot et démontage
# echo "Démontage des partitions..."
# umount -R /mnt

# echo "Installation terminée. Vous pouvez redémarrer le système."
