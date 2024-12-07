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

# Configuration générale

MOUNT_POINT="/mnt"
FILE_SWAP="Off"  # Fichier de mémoire virtuelle - On | Off

DEFAULT_BOOT_SIZE="512MiB"
DEFAULT_SWAP_SIZE="4GiB"
DEFAULT_MNT_SIZE="100%"

DEFAULT_BOOT_TYPE="fat32"
DEFAULT_MNT_TYPE="btrfs"
DEFAULT_SWAP_TYPE="linux-swap"

# Détection automatique du mode de démarrage (UEFI ou Legacy)
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
    BOOTLOADER="systemd-boot"  # Utilisation de systemd-boot pour UEFI
else
    MODE="LEGACY"
    BOOTLOADER="grub"  # Utilisation de GRUB pour Legacy BIOS
fi




