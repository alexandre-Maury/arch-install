#!/bin/bash

# script config.sh

ZONE="Europe"
PAYS="France"
CITY="Paris"
LANG="fr_FR.UTF-8"
LOCALE="fr_FR"
KEYMAP="fr"
HOSTNAME="archlinux-alexandre"
SSH_PORT=2222  # Remplacez 2222 par le port que vous souhaitez utiliser

##############################################################################
## Configuration générale                                              
##############################################################################

MOUNT_POINT="/mnt" # Point de montage
FILE_SWAP="Off"  # Choix entre "On" pour fichier swap, "Off" pour partition swap

DEFAULT_FS_TYPE="btrfs" # Choix entre "btrfs" ou "ext4" pour pour le Systeme de fichier

## Toute modification incorrecte peut entraîner des perturbations lors de l'installation        
#######################################################################################                                       
DEFAULT_BOOT_TYPE="fat32"
DEFAULT_BOOT_SIZE="512MiB"

PARTITIONS_CREATE=(
    "boot:${DEFAULT_BOOT_SIZE}:${DEFAULT_BOOT_TYPE}"
)

# Ajouter la partition swap seulement si FILE_SWAP est "Off"
if [[ "${FILE_SWAP}" == "Off" ]]; then
    DEFAULT_SWAP_TYPE="linux-swap"
    DEFAULT_SWAP_SIZE="8GiB"

    PARTITIONS_CREATE+=("swap:${DEFAULT_SWAP_SIZE}:${DEFAULT_SWAP_TYPE}")

fi


# Ajouter la partition home seulement si DEFAULT_FS_TYPE est "ext4"
if [[ "${DEFAULT_FS_TYPE}" == "ext4" ]]; then
    DEFAULT_MNT_SIZE="100GiB"
    DEFAULT_HOME_SIZE="100%"

    PARTITIONS_CREATE+=("root:${DEFAULT_MNT_SIZE}:${DEFAULT_FS_TYPE}")
    PARTITIONS_CREATE+=("home:${DEFAULT_HOME_SIZE}:${DEFAULT_FS_TYPE}")

elif [[ "${DEFAULT_FS_TYPE}" == "btrfs" ]]; then
    DEFAULT_MNT_SIZE="100%"

    PARTITIONS_CREATE+=("root:${DEFAULT_MNT_SIZE}:${DEFAULT_FS_TYPE}")

fi
#######################################################################################

# Détection automatique du mode de démarrage (UEFI ou Legacy)
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
    BOOTLOADER="systemd-boot"  # Utilisation de systemd-boot pour UEFI
else
    MODE="LEGACY"
    BOOTLOADER="grub"  # Utilisation de GRUB pour Legacy BIOS
fi




