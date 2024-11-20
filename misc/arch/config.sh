#!/bin/bash

if [ -d /sys/firmware/efi ]; then
  MODE="UEFI"
fi

ENABLE_SWAP="On"              # Mettre sur "On" pour activer le swap [création partition ou fichier swap] ou "Off" pour le désactiver
FILE_SWAP="Off"               # "On" pour utiliser un fichier swap, "Off" pour une partition swap
MERGE_ROOT_HOME="On"          # "On" pour fusionner root et home dans une seule partition : Taille de la partition 100%, "Off" pour les séparer
SIZE_BOOT="512M" 
SIZE_SWAP="4G"    
SIZE_ROOT="100G"  
SIZE_HOME="100%"  
FS_TYPE="btrf"    
SHRED_PASS="1"
MOUNT_POINT="/mnt"
BOOTLOADER="systemd-boot"    
