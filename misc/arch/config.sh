#!/bin/bash

# Choix du nombre de partitions
NUM_PARTITIONS=4

# Taille des partitions (en Mo), par exemple: 512 pour /boot, 30000 pour / et 4096 pour swap
PARTITION_SIZES=("512MiB" "4096MiB" "30GiB" "100%")

# Choix de la partition de swap ou fichier swap (true/false)
USE_SWAP_PARTITION=true

# Choix du système de fichiers
FILESYSTEM="btrfs"

# Choix du bootloader
BOOTLOADER="systemd-boot"

# Choix du mode de démarrage (uefi ou bios)
BOOT_MODE="uefi"  # Valeurs possibles : "uefi" ou "bios"
