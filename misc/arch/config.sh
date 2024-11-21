#!/bin/bash

# https://github.com/Zelrin/arch-btrfs-install-guide 
# https://sharafat.pages.dev/archlinux-install/
# https://chadymorra.github.io/

# Configuration système
SYSTEM_CONFIG() {
    # Détection automatique du mode de démarrage
    if [ -d /sys/firmware/efi ]; then
        MODE="UEFI"
    else
        MODE="BIOS"
    fi

    # Configuration générale
    ENABLE_SWAP="On"              # Activer/désactiver le swap
    FILE_SWAP="Off"               # Swap via fichier ou partition
    MERGE_ROOT_HOME="On"          # Fusionner root et home
    
    # Tailles des partitions
    SIZE_BOOT="512M"
    SIZE_SWAP="4G"    
    SIZE_ROOT="100%"  
    
    # Configuration système de fichiers et bootloader
    FS_TYPE="btrfs"    
    BOOTLOADER="systemd-boot"

    # Options avancées
    COMPRESSION="zstd"
    TIMEZONE="Europe/Paris"
    LOCALE="fr_FR.UTF-8"
    USERNAME="archuser"
}

# Logging et messages
LOG_PROMPT() {
    local type="$1"
    local message="$2"
    local color

    case "$type" in
        "INFO")    color="\e[34m";;    # Bleu
        "SUCCESS") color="\e[32m";;    # Vert
        "ERROR")   color="\e[31m";;    # Rouge
        "WARNING") color="\e[33m";;    # Jaune
        *)        color="\e[0m";;      # Défaut
    esac

    echo -e "${color}[${type}] ${message}\e[0m"
}

# Initialisation
SYSTEM_CONFIG

