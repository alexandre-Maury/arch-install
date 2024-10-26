#!/bin/bash

# script config.sh


# Détection du mode de démarrage (UEFI ou MBR)
if [ -d /sys/firmware/efi ]; then
  MODE="UEFI"
else
  MODE="MBR"
fi

# Comparaison entre Partition Swap et Fichier Swap :
# Critère	    Partition Swap :	                                            Fichier Swap :
# Performance	Généralement plus rapide en raison d'un accès direct.	        Moins rapide, mais souvent suffisant pour la plupart des usages.
# Flexibilité	Taille fixe, nécessite un redimensionnement pour changer.	    Facile à redimensionner en ajoutant ou supprimant des fichiers.
# Simplicité	Nécessite des opérations de partitionnement.	                Plus simple à configurer et à gérer.
# Gestion	    Nécessite des outils de partitionnement pour la création.	    Peut être géré par des commandes simples.

ENABLE_SWAP="On"   # Mettre sur "On" pour activer le swap [création part ou fichier swap] ou "Off" pour le désactiver
FILE_SWAP="Off"   # "On" pour utiliser un fichier swap, "Off" pour une partition swap
MERGE_ROOT_HOME="On"   # "On" pour fusionner root et home dans une seule partition : Taille de la partition 100%, "Off" pour les séparer

SIZE_BOOT="512M"  # Taille de la partition de boot (UEFI | MBR)
SIZE_SWAP="4G"    # Taille de la partition swap ou du fichier swap
SIZE_ROOT="100G"  # Taille de la partition root
SIZE_HOME="100%"  # Taille de la partition home (utilise tout l'espace restant)

FS_TYPE="ext4"    # Système de fichiers : ext4, btrfs, xfs
SHRED_PASS="1"
MOUNT_POINT="/mnt"
BOOTLOADER="systemd-boot" # grub ou systemd-boot

REGION="Europe"
PAYS="France"
CITY="Paris"
LOCALE="fr_FR"

LANG="fr_FR.UTF-8"
HOSTNAME="archlinux-alexandre"
INTERFACE="$(ip link show | awk -F': ' '/^[0-9]+: / && !/lo/ {print $2; exit}')"
KEYMAP="fr"

PASSWDQC_CONF="/etc/security/passwdqc.conf"
MIN_SIMPLE="4" # Valeurs : disabled : Longueur minimale pour un mot de passe simple, c'est-à-dire uniquement des lettres minuscules (ex. : "abcdef").
MIN_2CLASSES="4" # Longueur minimale pour un mot de passe avec deux classes de caractères, par exemple minuscules + majuscules ou minuscules + chiffres (ex. : "Abcdef" ou "abc123").
MIN_3CLASSES="4" # Longueur minimale pour un mot de passe avec trois classes de caractères, comme minuscules + majuscules + chiffres (ex. : "Abc123").
MIN_4CLASSES="4" # Longueur minimale pour un mot de passe avec quatre classes de caractères, incluant minuscules + majuscules + chiffres + caractères spéciaux (ex. : "Abc123!").
MIN_PHRASE="4" # Longueur minimale pour une phrase de passe, qui est généralement une suite de plusieurs mots ou une longue chaîne de caractères (ex. : "monmotdepassecompliqué").

MIN="$MIN_SIMPLE,$MIN_2CLASSES,$MIN_3CLASSES,$MIN_4CLASSES,$MIN_PHRASE"
MAX="72" # Définit la longueur maximale autorisée pour un mot de passe. Dans cet exemple, un mot de passe ne peut pas dépasser 72 caractères.
PASSPHRASE="3" # Définit la longueur minimale pour une phrase de passe en termes de nombre de mots. Ici, une phrase de passe doit comporter au moins 3 mots distincts pour être considérée comme valide.
MATCH="4" # Ce paramètre détermine la longueur minimale des segments de texte qui doivent correspondre entre deux chaînes pour être considérées comme similaires.
SIMILAR="permit" # Valeurs : permit ou deny : Définit la politique en matière de similitude entre le mot de passe et d'autres informations (par exemple, le nom de l'utilisateur).
RANDOM="47"
ENFORCE="everyone" #  Valeurs : none ou users ou everyone : Ce paramètre applique les règles de complexité définies à tous les utilisateurs.
RETRY="3" # Ce paramètre permet à l'utilisateur de réessayer jusqu'à 3 fois pour entrer un mot de passe conforme si le mot de passe initial proposé est refusé.



# Codes de type GPT courants

#     EF00 : Partition de système EFI (ESP - EFI System Partition).
#         Utilisée pour les systèmes basés sur UEFI.

#     8300 : Partition Linux.
#         Utilisée pour des systèmes de fichiers Linux (ext4, btrfs, etc.).

#     8200 : Partition de swap Linux.
#         Utilisée pour l'espace d'échange (swap) du système Linux.

#     0700 : Partition Microsoft Windows (NTFS/exFAT).
#         Utilisée pour les partitions de données NTFS ou exFAT dans Windows.

#     0C01 : Partition Microsoft Windows (FAT32 avec LBA).
#         Utilisée pour les partitions FAT32 avec prise en charge du mode LBA (Logical Block Addressing).

#     2700 : Partition de récupération Windows.
#         Utilisée pour les partitions de récupération (recovery) de Windows.

#     8E00 : Partition LVM (Logical Volume Manager).
#         Utilisée pour les volumes gérés par LVM sous Linux.

#     FD00 : Partition RAID Linux.
#         Utilisée pour les volumes RAID (Redundant Array of Independent Disks) sous Linux.

#     8301 : Partition de démarrage (boot) Linux.
#         Utilisée pour une partition de démarrage dédiée dans certains systèmes Linux.

#     8302 : Partition de "root" (racine) Linux x86-64.
#         Utilisée pour la partition racine dans les systèmes Linux (peut varier selon les distributions).

#     BF00 : Partition Solaris.
#         Utilisée pour le système d'exploitation Solaris.

#     A504 : Partition FreeBSD.
#         Utilisée pour les systèmes de fichiers de FreeBSD.

#     A502 : Partition swap FreeBSD.
#         Utilisée pour l'espace de swap dans FreeBSD.

#     A501 : Partition FreeBSD boot.
#         Utilisée pour la partition de démarrage de FreeBSD.

#     A503 : Partition FreeBSD UFS.
#         Utilisée pour les systèmes de fichiers UFS dans FreeBSD.

#     A801 : Partition OpenBSD.
#         Utilisée pour OpenBSD.

#     A901 : Partition NetBSD.
#         Utilisée pour NetBSD.

#     AF00 : Partition Apple HFS+.
#         Utilisée pour les systèmes de fichiers HFS+ dans macOS.

#     AB00 : Partition Apple Recovery.
#         Utilisée pour les partitions de récupération dans macOS.

# Codes pour d'autres systèmes et types spécifiques

#     0701 : Partition de données Windows Basic.

#     Utilisée pour des partitions de données standards sous Windows.

#     2701 : Partition Windows Reserved.

#     Réservée pour les fonctionnalités spécifiques à Windows.

#     EF02 : Partition BIOS boot.

#     Utilisée pour le démarrage en mode BIOS sur les systèmes utilisant GPT.

#     AF05 : Partition Apple UFS.

#     Utilisée pour les partitions UFS sur les anciens systèmes macOS.

#     EE00 : Partition de protection GPT (GPT protective MBR).

#     Utilisée pour protéger l'intégrité des partitions GPT sur les systèmes qui ne supportent pas GPT.

#     48465300-0000-11AA-AA11-00306543ECAC : Apple HFS/HFS+.