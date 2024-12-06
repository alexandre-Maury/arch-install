#!/bin/bash

# script config.sh

# Configuration générale
FILE_SWAP="On"  # Fichier de mémoire virtuelle - On | Off
BOOTLOADER="systemd-boot" # systemd-boot | grub
MOUNT_POINT="/mnt"
ZONE="Europe"
PAYS="France"
CITY="Paris"
LANG="fr_FR.UTF-8"
LOCALE="fr_FR"
KEYMAP="fr"
HOSTNAME="archlinux-alexandre"
SSH_PORT=2222  # Remplacez 2222 par le port que vous souhaitez utiliser

# Détection automatique du mode de démarrage
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="LEGACY"
fi

DEFAULT_BOOT_SIZE="512MiB"
DEFAULT_SWAP_SIZE="4GiB"
DEFAULT_ROOT_SIZE="100GiB"
DEFAULT_HOME_SIZE="100%"



