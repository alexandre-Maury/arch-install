#!/bin/bash

# script functions.sh

# Détection automatique du mode de démarrage
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="BIOS"
fi

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

# Fonction pour convertir les tailles en MiB
convert_to_mib() {
    local size="$1"
    local numeric_size
    # Si la taille est en GiB, on la convertit en MiB (1GiB = 1024MiB)
    if [[ "$size" =~ ^[0-9]+GiB$ ]]; then
        numeric_size=$(echo "$size" | sed 's/GiB//')
        echo $(($numeric_size * 1024))  # Convertir en MiB
    # Si la taille est en GiB avec "G", convertir aussi en MiB
    elif [[ "$size" =~ ^[0-9]+G$ ]]; then
        numeric_size=$(echo "$size" | sed 's/G//')
        echo $(($numeric_size * 1024))  # Convertir en MiB
    elif [[ "$size" =~ ^[0-9]+MiB$ ]]; then
        # Si la taille est déjà en MiB, on la garde telle quelle
        echo "$size" | sed 's/MiB//'
    elif [[ "$size" =~ ^[0-9]+M$ ]]; then
        # Si la taille est en Mo (en utilisant 'M'), convertir en MiB (1 Mo = 1 MiB dans ce contexte)
        numeric_size=$(echo "$size" | sed 's/M//')
        echo "$numeric_size"
    elif [[ "$size" =~ ^[0-9]+%$ ]]; then
        # Si la taille est un pourcentage, retourner "100%" directement
        echo "$size"
    else
        echo "0"  # Retourne 0 si l'unité est mal définie
    fi
}


# Fonction pour demander à l'utilisateur une taille de partition valide
get_partition_size() {
    local default_size=$1
    while true; do
        read -p "Taille pour cette partition (par défaut: $default_size) : " custom_size
        custom_size=${custom_size:-$default_size}
        
        # Vérification de la validité de la taille (format correct)
        if [[ "$custom_size" =~ ^[0-9]+(MiB|GiB|%)$ ]]; then
            echo "$custom_size"
            return 0  # Retourne une valeur valide, pas de problème
        else
            return 1  # Erreur, invite à réessayer
        fi
    done
}

# Fonction pour formater la taille d'une partition en GiB ou MiB
format_space() {
    local space=$1

    # Si la taille est supérieur ou égal à 1 Go (1024 MiB), afficher en GiB
    if (( space >= 1024 )); then
        # Convertion en GiB
        local space_in_gib=$(echo "scale=2; $space / 1024" | bc)
        echo "${space_in_gib} GiB"
    else
        # Si la taille est inférieur à 1 GiB, afficher en MiB
        echo "${space} MiB"
    fi
}

# Fonction pour afficher les informations des partitions
format_disk() {

    local status="$1"
    local partitions="$2"
    local disk="$3"
    

    log_prompt "INFO" && echo "$status" && echo ""
    echo "Device : /dev/$disk"
    echo "Taille : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
    echo "Type : $(lsblk -n -o TRAN "/dev/$disk")"
    echo -e "\nInformations des partitions :"
    echo "----------------------------------------"

    # Définition des colonnes à afficher
    columns="NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT,UUID"

    # En-tête
    printf "%-10s %-10s %-10s %-15s %-15s %s\n" \
        "PARTITION" "TAILLE" "TYPE FS" "LABEL" "POINT MONT." "UUID"
    echo "----------------------------------------"

    # Affiche les informations de chaque partition
    while read -r partition; do
        if [ -b "/dev/$partition" ]; then
            lsblk "/dev/$partition" -n -o "$columns" | \
            awk '{
                # Stockage des valeurs avec gestion des champs vides
                p1 = ($1 == "" ? "[vide]" : $1)
                p2 = ($2 == "" ? "[vide]" : $2)
                p3 = ($3 == "" ? "[vide]" : $3)
                p4 = ($4 == "" ? "[vide]" : $4)
                p5 = ($5 == "" ? "[vide]" : $5)
                p6 = ($6 == "" ? "[vide]" : $6)
                
                # Affichage formaté
                printf "%-10s %-10s %-10s %-15s %-15s %s\n", 
                    p1, p2, p3, p4, p5, p6
            }'
        fi
    done <<< "$partitions"

    # Résumé
    echo -e "\nRésumé :"
    echo "Nombre de partitions : $(echo "$partitions" | wc -l)"
    echo "Espace total : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
}

# Fonction pour effacer tout le disque
erase_disk() {

    local disk="$1"
    
    # Vérifier si des partitions sont montées
    local mounted_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT | grep -v "^$disk " | grep -v "^$" | grep -v "\[SWAP\]")
    
    if [ -n "$mounted_parts" ]; then
        echo "ATTENTION: Certaines partitions sont montées :"
        echo "$mounted_parts"
        echo -n "Voulez-vous les démonter ? (oui/non) : "
        read -r response
        if [ "$response" = "oui" ]; then
            while read -r part _; do
                umount "/dev/${part##*/}" 2>/dev/null
            done <<< "$mounted_parts"
        else
            echo "Opération annulée"
            return 1
        fi
    fi

    echo "ATTENTION: Vous êtes sur le point d'effacer TOUT le disque /dev/$disk"
    echo "Cette opération est IRRÉVERSIBLE !"
    echo "Toutes les données seront DÉFINITIVEMENT PERDUES !"
    echo -n "Êtes-vous vraiment sûr ? (tapez 'EFFACER TOUT' pour confirmer) : "
    read -r confirm

    if [ "$confirm" = "EFFACER TOUT" ]; then
        echo "Effacement du disque /dev/$disk en cours..."
        # Utilisation de dd pour effacer le disque
        dd if=/dev/zero of="/dev/$disk" bs=4M status=progress
        sync
        echo "Effacement terminé"
    else
        echo "Opération annulée"
        return 1
    fi
}
