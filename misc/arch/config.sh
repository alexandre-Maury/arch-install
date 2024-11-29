#!/bin/bash

# script config.sh

# https://github.com/Zelrin/arch-btrfs-install-guide 
# https://sharafat.pages.dev/archlinux-install/
# https://chadymorra.github.io/
# https://forest0923.github.io/memo/en/docs/root/archlinux/base-install-manuals/dual-boot-win11-systemd-boot/

# Configuration générale
FILE_SWAP="Off"              # Fichier de mémoire virtuelle
BOOTLOADER="systemd-boot"
MOUNT_POINT="/mnt"
PAYS="France"
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



