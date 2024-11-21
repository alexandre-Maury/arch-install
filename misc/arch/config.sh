#!/bin/bash

# https://github.com/Zelrin/arch-btrfs-install-guide 
# https://sharafat.pages.dev/archlinux-install/
# https://chadymorra.github.io/

# Détection automatique du mode de démarrage
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="BIOS"
fi

# Configuration générale
FILE_SWAP="Off"              # Fichier de mémoire virtuelle

# Déclaration de la liste de partitions
PARTITION_TYPES=("boot:fat32:512MiB" "root:btrfs:100GiB" "home:btrfs:100%")

# Condition pour ajouter la partition swap si FILE_SWAP n'est pas "Off"
if [[ "${FILE_SWAP}" != "Off" ]]; then
    PARTITION_TYPES+=("swap:linux-swap:4GiB")  # Ajouter la partition swap
fi
    

BOOTLOADER="systemd-boot"

# Options avancées
COMPRESSION="zstd"
TIMEZONE="Europe/Paris"
LOCALE="fr_FR.UTF-8"
USERNAME="archuser"

