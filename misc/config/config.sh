#!/bin/bash

# script config.sh

##############################################################################
## Config arch chroot-install                                                
##############################################################################


if [ -d /sys/firmware/efi ]; then
  MODE="UEFI"
else
  MODE="MBR"
fi

ENABLE_SWAP="On"              # Mettre sur "On" pour activer le swap [création part ou fichier swap] ou "Off" pour le désactiver
FILE_SWAP="Off"               # "On" pour utiliser un fichier swap, "Off" pour une partition swap
MERGE_ROOT_HOME="On"          # "On" pour fusionner root et home dans une seule partition : Taille de la partition 100%, "Off" pour les séparer
SIZE_BOOT="512M" 
SIZE_SWAP="4G"    
SIZE_ROOT="100G"  
SIZE_HOME="100%"  
FS_TYPE="ext4"    
SHRED_PASS="1"
MOUNT_POINT="/mnt"
BOOTLOADER="systemd-boot"    # grub ou systemd-boot : systemd-boot ne peut être utilisé qu'en mode UEFI.
REGION="Europe"
PAYS="France"
CITY="Paris"
LOCALE="fr_FR"
LANG="fr_FR.UTF-8"
HOSTNAME="archlinux-alexandre"
INTERFACE="$(ip link show | awk -F': ' '/^[0-9]+: / && !/lo/ {print $2; exit}')"
MAC_ADDRESS=$(ip link | awk '/ether/ {print $2; exit}')
DNS_SERVERS="1.1.1.1 9.9.9.9"
FALLBACK_DNS="8.8.8.8"
KEYMAP="fr"
GPU_VENDOR=$(lspci | grep -i "VGA\|3D" | awk '{print tolower($0)}')
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
SSH_PORT=2222  # Remplacez 2222 par le port que vous souhaitez utiliser
SSH_CONFIG_FILE="/etc/ssh/sshd_config"


##############################################################################
## Config arch post-install                                                   
##############################################################################

# https://github.com/ryanoasis/nerd-fonts/tree/300890327ae50ed08a0c2ba89e8bfd67425dd3b8
URL_FONTS=(
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/FiraCodeNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/FiraCodeNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/FiraCodeNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L/Regular/MesloLGLNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L/Regular/MesloLGLNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L/Regular/MesloLGLNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L-DZ/Regular/MesloLGLDZNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L-DZ/Regular/MesloLGLDZNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/L-DZ/Regular/MesloLGLDZNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M/Regular/MesloLGMNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M/Regular/MesloLGMNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M/Regular/MesloLGMNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M-DZ/Regular/MesloLGMDZNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M-DZ/Regular/MesloLGMDZNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/M-DZ/Regular/MesloLGMDZNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S-DZ/Regular/MesloLGSDZNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S-DZ/Regular/MesloLGSDZNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S-DZ/Regular/MesloLGSDZNerdFontPropo-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S/Regular/MesloLGSNerdFont-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S/Regular/MesloLGSNerdFontMono-Regular.ttf"
  "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Meslo/S/Regular/MesloLGSNerdFontPropo-Regular.ttf"
)

YAY="On"
PARU="Off"