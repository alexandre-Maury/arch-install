#!/bin/bash

# Effacement du disque
wipefs --force --all /dev/${DISK} || { echo "Erreur lors de l'effacement du disque"; exit 1; }
shred -n "${SHRED_PASS}" -v "/dev/${DISK}" || { echo "Erreur lors de l'effacement sécurisé"; exit 1; }

# Détermination du mode (UEFI ou MBR)
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="MBR"
fi

# Réinitialisation de la table de partitions
if [[ "${MODE}" == "UEFI" ]]; then
    parted --script -a optimal /dev/${DISK} mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }
else
    parted --script -a optimal /dev/${DISK} mklabel msdos || { echo "Erreur lors de la création de la table MBR"; exit 1; }
fi

# Création des partitions avec parted
if [[ "${MODE}" == "UEFI" ]]; then
    # Partition de boot pour UEFI (FAT32)
    parted --script -a optimal /dev/${DISK} mkpart primary fat32 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 boot on
else
    # Partition de boot pour MBR (ext4)
    parted --script -a optimal /dev/${DISK} mkpart primary ext4 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 boot on
fi

# Si FILE_SWAP est sur "Off", on crée une partition pour le swap
if [[ "${FILE_SWAP}" == "Off" ]]; then
    parted --script -a optimal /dev/${DISK} mkpart primary linux-swap "${SIZE_BOOT}" "${SIZE_SWAP}" || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    PART_ROOT=3
    PART_HOME=4
else
    PART_ROOT=2
    PART_HOME=3
fi

# Gestion de la fusion root et home
if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
    # Création d'une seule partition pour root + home
    parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
    PART_HOME=""  # Désactivation de la partition home spécifique
else
    # Création de partitions séparées pour root et home
    parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
    parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
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

# Affichage de la table des partitions pour vérification
parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }

# Fin du script
echo "Script terminé avec succès !"
