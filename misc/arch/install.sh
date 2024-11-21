#!/bin/bash

# Fonction pour loguer les informations (niveau: INFO, ERROR)
log_prompt() {
    local log_level="$1" # INFO - WARNING - ERROR - SUCCESS
    local log_date="$(date +"%Y-%m-%d %H:%M:%S")"

    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    LIGHT_CYAN='\033[0;96m'
    RESET='\033[0m'

    case "${log_level}" in

        "SUCCESS")
            log_color="${GREEN}"
            log_status='SUCCESS'
            ;;
        "WARNING")
            log_color="${YELLOW}"
            log_status='WARNING'
            ;;
        "ERROR")
            log_color="${RED}"
            log_status='ERROR'
            ;;
        "INFO")
            log_color="${LIGHT_CYAN}"
            log_status='INFO'
            ;;
        *)
            log_color="${RESET}" # Au cas où un niveau inconnu est utilisé
            log_status='UNKNOWN'
            ;;
    esac

    echo -ne "${log_color} [ ${log_status} ] "${log_date}" ==> ${RESET}"

}

# Configuration des types de partitions disponibles
PARTITION_TYPES=(
    "boot:fat32:512M"      # Partition de démarrage (EFI ou BIOS)
    "swap:linux-swap:4GiB"   # Partition de mémoire virtuelle 
    "root:btrfs:100G"      # Partition racine du système
    "home:btrfs:100%"      # Partition pour les fichiers utilisateur
)

# Fonction pour demander à l'utilisateur une taille de partition valide
get_partition_size() {
    local default_size=$1
    while true; do
        read -p "Taille pour cette partition (par défaut: $default_size) : " custom_size
        custom_size=${custom_size:-$default_size}
        
        # Vérification de la validité de la taille (format correct)
        if [[ "$custom_size" =~ ^[0-9]+(M|G|T|%)$ ]]; then
            echo "$custom_size"
            return
        else
            echo "Erreur: La taille doit être spécifiée dans le format correct (par exemple 500M, 2G, 100%)."
        fi
    done
}

##############################################################################
## Récupération des disques disponibles                                                      
##############################################################################
list="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

if [[ -z "${list}" ]]; then
    log_prompt "ERROR" && echo "Aucun disque disponible pour l'installation."
    exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
else
    clear
    log_prompt "INFO" && echo "Choisissez un disque pour l'installation (ex : 1) " && echo ""
    echo "${list}" && echo ""
fi

# Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
option=""
while [[ -z "$(echo "${list}" | grep "  ${option})")" ]]; do
    
    log_prompt "INFO" && read -p "Votre Choix : " option 
    
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

clear

##############################################################################
## Sélection des partitions                                                     
##############################################################################
selected_partitions=()
remaining_types=("${PARTITION_TYPES[@]}")

while true; do

    echo "Types de partitions disponibles :"
    for i in "${!PARTITION_TYPES[@]}"; do
        IFS=':' read -r name type size <<< "${PARTITION_TYPES[$i]}"
        printf "%d) %s (type: %s, taille par défaut: %s)\n" $((i+1)) "$name" "$type" "$size"
    done

    echo "0) Terminer la configuration des partitions"
    read -p "Sélectionnez un type de partition (0 pour terminer) : " choice
        
    if [[ "$choice" -eq 0 ]]; then
        if [[ ${#selected_partitions[@]} -eq 0 ]]; then
            echo "Erreur: Vous devez sélectionner au moins une partition."
            continue
        fi
        break
    fi
        
    if [[ "$choice" -lt 1 || "$choice" -gt ${#remaining_types[@]} ]]; then
        echo "Sélection invalide, réessayez."
        continue
    fi
        
    selected_index=$((choice-1))
    partition="${remaining_types[$selected_index]}"
        
    IFS=':' read -r name type default_size <<< "$partition"
        
    # Demander la taille de partition
    custom_size=$(get_partition_size "$default_size")
        
    selected_partitions+=("$name:$type:$custom_size")
    unset 'remaining_types[$selected_index]'
    remaining_types=("${remaining_types[@]}")
done
    
echo "Partitions sélectionnées :"
for partition in "${selected_partitions[@]}"; do
    IFS=':' read -r name type size <<< "$partition"
    echo "$name ($type): $size"
done
    
# Confirmer la création des partitions
read -p "Confirmer la création des partitions (y/n) : " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Annulation de la création des partitions."
    exit 1
fi

echo "$selected_partitions"