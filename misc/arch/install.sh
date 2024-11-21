#!/bin/bash

# Fonction pour loguer les informations (niveau: INFO, ERROR)
log_prompt() {
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

# Configuration des types de partitions disponibles
PARTITION_TYPES=(
    "boot:fat32:512M"      # Partition de démarrage (EFI ou BIOS)
    "swap:linux-swap:4G"   # Partition de mémoire virtuelle 
    "root:btrfs:100G"      # Partition racine du système
    "home:btrfs:100%"      # Partition pour les fichiers utilisateur
)

##############################################################################
## Récupération des disques disponibles                                                      
##############################################################################
list="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

if [[ -z "${list}" ]]; then
    log_prompt "ERROR" "Aucun disque disponible pour l'installation."
    exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
else
    echo "${list}" && echo ""
fi

# Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
option=""
while [[ -z "$(echo "${list}" | grep "  ${option})")" ]]; do
    log_prompt "INFO" "Choisissez un disque pour l'installation (ex : 1) " && read -p " : " option 
    

    # Vérification si l'utilisateur a entré un numéro (choix dans la liste)
    if [[ -n "$(echo "${list}" | grep "  ${option})")" ]]; then
        # Si l'utilisateur a choisi un numéro valide, récupérer le nom du disque correspondant
        disk="$(echo "${list}" | grep "  ${option})" | awk '{print $2}')"
        break
    else
        # Si l'utilisateur a entré quelque chose qui n'est pas dans la liste, considérer que c'est un nom de disque
        disk="${option}"
        break
    fi
done

echo "vous avez choisi $disk"