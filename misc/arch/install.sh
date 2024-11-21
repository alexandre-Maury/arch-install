#!/bin/bash

# Fonction pour loguer les informations (niveau: INFO, ERROR)
log_prompt() {
    local level=$1
    local message=$2
    echo "[$level] $message"
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
select_disk() {

    local list="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

    if [[ -z "${list}" ]]; then
        log_prompt "ERROR" "Aucun disque disponible pour l'installation."
        exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
    fi

    echo "${list}"  # Affiche la liste des disques disponibles
    log_prompt "INFO" "Choisissez un disque pour l'installation (ex : 1) : "

    # Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
    local option=""
    while true; do
        read -p "Votre Choix : " OPTION  # Demander le choix à l'utilisateur
        echo ""

        # Vérification si l'utilisateur a entré un numéro dans la liste
        if [[ -n "$(echo "${list}" | grep -e "^[[:space:]]*${option}[[:space:]]*\)")" ]]; then
            # Si l'utilisateur a choisi un numéro valide, récupérer le nom du disque correspondant
            local disk="$(echo "${list}" | grep -e "^[[:space:]]*${option}[[:space:]]*\)" | awk '{print $2}')"
            break
        elif [[ -b "$option" ]]; then
            # Si l'utilisateur a entré un nom de disque valide, utiliser ce nom
            local disk="$option"
            break
        else
            log_prompt "ERROR" "Choix invalide, veuillez entrer un numéro valide ou un nom de disque."
        fi
    done

    # # Retourner le disque choisi
    echo "$disk"
}

# Appel de la fonction et récupération du disque choisi
disk=$(select_disk)

# Affichage du disque choisi
# echo "Vous avez choisi le disque : $disk"
