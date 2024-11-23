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
    local partitions=($2)  # Transformation en tableau
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
    for partition in "${partitions[@]}"; do  # itérer sur le tableau des partitions
        if [ -b "/dev/$partition" ]; then
            # Récupérer chaque colonne séparément pour éviter toute confusion
            NAME=$(lsblk "/dev/$partition" -n -o NAME)
            SIZE=$(lsblk "/dev/$partition" -n -o SIZE)
            FSTYPE=$(lsblk "/dev/$partition" -n -o FSTYPE)
            LABEL=$(lsblk "/dev/$partition" -n -o LABEL)
            MOUNTPOINT=$(lsblk "/dev/$partition" -n -o MOUNTPOINT)
            UUID=$(lsblk "/dev/$partition" -n -o UUID)

            # Gestion des valeurs vides
            NAME=${NAME:-"[vide]"}
            SIZE=${SIZE:-"[vide]"}
            FSTYPE=${FSTYPE:-"[vide]"}
            LABEL=${LABEL:-"[vide]"}
            MOUNTPOINT=${MOUNTPOINT:-"[vide]"}
            UUID=${UUID:-"[vide]"}

            # Affichage formaté
            printf "%-10s %-10s %-10s %-15s %-15s %s\n" "$NAME" "$SIZE" "$FSTYPE" "$LABEL" "$MOUNTPOINT" "$UUID"
        fi
    done

    # Résumé
    echo -e "\nRésumé :"
    echo "Nombre de partitions : $(echo "${partitions[@]}" | wc -w)"  # Utilisation de `wc -w` pour compter les éléments du tableau
    echo "Espace total : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
}


# Fonction pour effacer tout le disque
erase_disk() {
    local disk="$1"
    
    # Récupérer les partitions montées (non-swap)
    local mounted_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep -v "\[SWAP\]" | grep -v "^$disk " | grep -v " $")
    # Liste des partitions swap
    local swap_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep "\[SWAP\]")
    
    # Gérer les partitions montées (non-swap)
    if [ -n "$mounted_parts" ]; then
        log_prompt "INFO" && echo "ATTENTION: Certaines partitions sont montées :" && echo ""
        echo "$mounted_parts"
        echo ""
        log_prompt "INFO" && read -p "Voulez-vous les démonter ? (y/n) : " response && echo ""

        if [[ "$response" =~ ^[yY]$ ]]; then
            while read -r part mountpoint; do
                log_prompt "INFO" && echo "Démontage de /dev/$part" && echo ""
                umount "/dev/$part" 
                if [ $? -ne 0 ]; then
                    log_prompt "ERROR" && echo "Démontage de /dev/$part impossible" && echo ""
                fi
            done <<< "$mounted_parts"
        else
            log_prompt "WARNING" && echo "Opération annulée" && echo ""
            return 1
        fi
    fi
    
    # Gérer les partitions swap séparément
    if [ -n "$swap_parts" ]; then
        log_prompt "INFO" && echo "ATTENTION: Certaines partitions swap sont activées :" && echo ""
        echo "$swap_parts"
        echo ""
        log_prompt "INFO" && read -p "Voulez-vous les démonter ? (y/n) : " response && echo ""

        if [[ "$response" =~ ^[yY]$ ]]; then
            while read -r part _; do
                log_prompt "INFO" && echo "Démontage de /dev/$part" && echo ""
                swapoff "/dev/$part"
                if [ $? -ne 0 ]; then
                    log_prompt "ERROR" && echo "Démontage de /dev/$part impossible" && echo ""
                fi
            done <<< "$swap_parts"
        else
            log_prompt "WARNING" && echo "Opération annulée" && echo ""
            return 1
        fi
    fi
    
    echo "ATTENTION: Vous êtes sur le point d'effacer TOUT le disque /dev/$disk"
    echo "Cette opération est IRRÉVERSIBLE !"
    echo "Toutes les données seront DÉFINITIVEMENT PERDUES !"
    echo ""
    log_prompt "INFO" && read -p "Êtes-vous vraiment sûr ? (y/n) : " response && echo ""

    if [[ "$response" =~ ^[yY]$ ]]; then
        log_prompt "INFO" && echo "Effacement du disque /dev/$disk en cours ..." && echo ""

        # Obtenir la taille exacte du disque en blocs
        local disk_size=$(blockdev --getsz "/dev/$disk")
        # Utilisation de dd avec la taille exacte du disque
        dd if=/dev/zero of="/dev/$disk" bs=512 count=$disk_size status=progress
        sync

        log_prompt "SUCCESS" && echo "Effacement du disque terminé" && echo ""
        
    else
        log_prompt "WARNING" && echo "Opération annulée" && echo ""
        return 1
    fi
}



# Fonction pour effacer une partition spécifique
erase_partition() {
    local partition="$1"

    # Vérifier si la partition existe
    if [ ! -e "/dev/$partition" ]; then
        log_prompt "ERROR" && echo "La partition /dev/$partition n'existe pas." && echo ""
        return 1
    fi

    # Vérifier si c'est une partition swap
    if grep -q "/dev/$partition" /proc/swaps; then
        log_prompt "ERROR" && echo "L'effacement des partitions swap n'est pas autorisé." && echo ""
        return 1
    fi

    # Vérifier si c'est une partition boot
    local mount_point=$(lsblk -no MOUNTPOINT "/dev/$partition" 2>/dev/null)
    if [[ "$mount_point" == "/boot" || "$mount_point" == "/boot/efi" ]]; then
        log_prompt "ERROR" && echo "L'effacement des partitions boot n'est pas autorisé." && echo ""
        return 1
    fi

    # Vérifier si la partition est montée
    if mountpoint -q "/dev/$partition" 2>/dev/null || grep -q "^/dev/$partition" /proc/mounts; then
        log_prompt "INFO" && echo "La partition /dev/$partition est montée !" && echo ""

        log_prompt "INFO" && read -p "Voulez-vous la démonter ? (y/n) : " response && echo ""

        if [[ "$response" =~ ^[yY]$ ]]; then
            log_prompt "INFO" && echo "Démontage de la partition..." && echo ""
            umount "/dev/$partition" || {
                log_prompt "ERROR" && echo "Erreur lors du démontage !" && echo ""
                return 1
            }
        else
            log_prompt "WARNING" && echo "Opération annulée" && echo ""
            return 1
        fi
    fi

    echo "Vous êtes sur le point d'effacer la partition /dev/$partition"
    echo "Cette opération est IRRÉVERSIBLE !"
    echo "Toutes les données seront DÉFINITIVEMENT PERDUES !"
    echo ""
    log_prompt "INFO" && read -p "Êtes-vous vraiment sûr ? (y/n) : " response && echo ""

    if [[ "$response" =~ ^[yY]$ ]]; then

        log_prompt "INFO" && echo "Effacement de la partition /dev/$partition en cours ..." && echo ""
        
        # Obtenir la taille exacte de la partition en blocs
        local part_size=$(blockdev --getsz "/dev/$partition")
        # Utilisation de dd avec la taille exacte
        dd if=/dev/zero of="/dev/$partition" bs=512 count=$part_size status=progress
        sync

        log_prompt "SUCCESS" && echo "Effacement de la partition terminé avec succès" && echo ""

    else
        log_prompt "WARNING" && echo "Opération annulée" && echo ""
        return 1
    fi
}

