#!/bin/bash

# script config.sh

# https://github.com/Zelrin/arch-btrfs-install-guide 
# https://sharafat.pages.dev/archlinux-install/
# https://chadymorra.github.io/
# https://forest0923.github.io/memo/en/docs/root/archlinux/base-install-manuals/dual-boot-win11-systemd-boot/

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



