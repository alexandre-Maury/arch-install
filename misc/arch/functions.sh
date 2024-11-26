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
    local log_color
    local log_status
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[0;33m'
    local LIGHT_CYAN='\033[0;96m'
    local RESET='\033[0m'

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

# Fonction pour formater l'affichage de la taille d'une partition en GiB ou MiB
format_space() {
    local space=$1
    local space_in_gib

    # Si la taille est supérieur ou égal à 1 Go (1024 MiB), afficher en GiB
    if (( space >= 1024 )); then
        # Convertion en GiB
        space_in_gib=$(echo "scale=2; $space / 1024" | bc)
        echo "${space_in_gib} GiB"
    else
        # Si la taille est inférieur à 1 GiB, afficher en MiB
        echo "${space} MiB"
    fi
}

# Fonction pour afficher les informations des partitions
show_disk_partitions() {
    
    local status="$1"
    local disk="$2"
    local partitions
    local NAME
    local SIZE
    local FSTYPE
    local LABEL
    local MOUNTPOINT
    local UUID


    log_prompt "INFO" && echo "$status" && echo ""
    echo "Device : /dev/$disk"
    echo "Taille : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
    echo "Type : $(lsblk -n -o TRAN "/dev/$disk")"
    echo -e "\nInformations des partitions :"
    echo "----------------------------------------"
    # En-tête
    printf "%-10s %-10s %-10s %-15s %-15s %s\n" \
        "PARTITION" "TAILLE" "TYPE FS" "LABEL" "POINT MONT." "UUID"
    echo "----------------------------------------"


    # récupération des partition à afficher sur le disque
    while IFS= read -r partition; do
        partitions+=("$partition")
    done < <(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | tr -d '└─├─')

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
    local disk_size
    local mounted_parts
    local swap_parts
    
    # Récupérer les partitions montées (non-swap)
    mounted_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep -v "\[SWAP\]" | grep -v "^$disk " | grep -v " $")
    # Liste des partitions swap
    swap_parts=$(lsblk "/dev/$disk" -o NAME,MOUNTPOINT -n -l | grep "\[SWAP\]")
    
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
        disk_size=$(blockdev --getsz "/dev/$disk")
        # Utilisation de dd avec la taille exacte du disque
        dd if=/dev/zero of="/dev/$disk" bs=512 count=$disk_size status=progress
        sync
        echo ""
        log_prompt "SUCCESS" && echo "Effacement du disque terminé" && echo ""
        
    else
        log_prompt "WARNING" && echo "Opération annulée" && echo ""
        return 1
    fi
}



# Fonction pour effacer une partition spécifique
erase_partition() {
    local partition="$1"
    local part_size
    local mount_point

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
    mount_point=$(lsblk -no MOUNTPOINT "/dev/$partition" 2>/dev/null)
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
        part_size=$(blockdev --getsz "/dev/$partition")
        # Utilisation de dd avec la taille exacte
        dd if=/dev/zero of="/dev/$partition" bs=512 count=$part_size status=progress
        sync
        echo ""
        log_prompt "SUCCESS" && echo "Effacement de la partition terminé avec succès" && echo ""

    else
        log_prompt "WARNING" && echo "Opération annulée" && echo ""
        return 1
    fi
}


preparation_disk() {

    local DEFAULT_BOOT_SIZE="512MiB"
    local DEFAULT_SWAP_SIZE="4GiB"
    local DEFAULT_ROOT_SIZE="100GiB"
    local DEFAULT_HOME_SIZE="100%"

    local DEFAULT_FS_TYPE="btrfs"

    local DEFAULT_BOOT_TYPE="fat32"
    local DEFAULT_ROOT_TYPE="btrfs"
    local DEFAULT_SWAP_TYPE="linux-swap"
    local DEFAULT_HOME_TYPE="ext4"

    local available_types=("boot" "root")
    local selected_partitions=()
    local formatted_partitions=()  
    local disk="$1"  
    local disk_type=$(_detect_disk_type "$disk")
    local partition_number=1
    local start="1MiB"
    local remaining_space
    local disk_size=$(lsblk -d -o SIZE --noheadings "/dev/$disk" | tr -d '[:space:]')
    local disk_size_mib=$(convert_to_mib "$disk_size")
    local used_space=0  

    # Condition pour ajouter la partition swap
    if [[ "${FILE_SWAP}" == "Off" ]]; then
        available_types+=("swap")  # Ajouter la partition swap
    fi

    _detect_disk_type() {
        local disk="$1"
        case "$disk" in
            nvme*)
                echo "nvme"
                ;;
            sd*)
                # Test supplémentaire pour distinguer SSD/HDD
                local rotational=$(cat "/sys/block/$disk/queue/rotational" 2>/dev/null)
                if [[ "$rotational" == "0" ]]; then
                    echo "ssd"
                else
                    echo "hdd"
                fi
                ;;
            *)
                echo "basic"
                ;;
        esac
    }

    # Fonction pour demander à l'utilisateur une taille de partition valide
    _get_partition_size() {
        local default_size=$1
        local custom_size

        while true; do
            read -p "Taille pour cette partition (par défaut: $default_size) : " custom_size
            custom_size=${custom_size:-$default_size}
            
            # Vérification de la validité de la taille (format correct)
            if [[ "$custom_size" =~ ^[0-9]+(MiB|GiB|%)$ ]]; then
                echo "$custom_size"
                break  # Retourne une valeur valide, pas de problème
            else
                log_prompt "WARNING" && echo "Unité de taille invalide, [ MiB | GiB| % ] réessayez." && echo ""
            fi
        done
    }

    # Fonction pour demander à l'utilisateur un type de fichier valide
    _get_fs_type() {
        local default_fs=$1
        local custom_fs

        while true; do
            read -p "Type de système de fichiers pour cette partition (par défaut: $default_fs) : " custom_fs
            custom_fs=${custom_fs:-$default_fs}
            
            # Vérification que le type de système de fichiers est valide
            if [[ "$custom_fs" =~ ^(ext4|btrfs|xfs|vfat)$ ]]; then
                echo "$custom_fs"
                break  # Retourne une valeur valide
            else
                log_prompt "WARNING" && echo "Type de système de fichiers invalide. Choisissez parmi: ext4, btrfs, xfs, f2fs, vfat."
            fi
        done
    }


    _update_available_partitions() {
        # Initialiser la liste des types disponibles
        available_types=()

        # Vérifier les types déjà sélectionnés
        local boot_selected=false
        local root_selected=false
        local home_selected=false
        local swap_selected=false

        for selected in "${selected_partitions[@]}"; do
            case "${selected%%:*}" in
                "boot") boot_selected=true ;;
                "root") root_selected=true ;;
                "home") home_selected=true ;;
                "swap") swap_selected=true ;;
            esac
        done

        # Ajouter les types possibles selon la progression logique
        if ! $boot_selected; then
            available_types+=("boot")
        fi

        if ! $root_selected; then
            available_types+=("root")
        fi

        if $root_selected && ! $home_selected; then
            available_types+=("home")
        fi

        if ! $swap_selected; then
            available_types+=("swap")
        fi
    }

    # Fonction d'affichage du menu
    _display_menu() {

        # Calculer l'espace restant en MiB
        remaining_space=$((disk_size_mib - used_space))
        log_prompt "INFO" && echo "Espace restant sur le disque : $(format_space $remaining_space) "

        echo ""
        # Message d'avertissement concernant la partition racine
        echo "ATTENTION : La partition root (/) sera celle qui accueillera le système."
        echo "Il est important de ne pas modifier son label (root), car cela pourrait perturber l'installation."
        echo "Par contre, le type (btrfs, ext4 ...) ou la taille de cette partition peut être modifiée, en particulier si elle occupe l'espace restant disponible."
        echo
        echo "boot ==> partition efi"
        echo "swap ==> partition swap"
        echo "root ==> partition root"
        echo "home ==> partition home"
        echo
        echo "============================================"
        echo "         Sélection des partitions"
        echo "============================================"
        echo
        echo "Partitions disponibles :"
        echo
        local i=1
        for type in "${available_types[@]}"; do
            echo "  $i) partition : $type"
            ((i++))
        done
        echo
        echo "q : pour quitter"
        echo "============================================"
    }

    # Processus interactif pour la sélection des partitions
    while [[ ${#available_types[@]} -gt 0 ]]; do
        clear
        _display_menu
        
        read -rp "Sélectionnez un type de partition (q pour terminer) : " choice

        if [[ "$choice" =~ ^[qQ]$ ]]; then
            log_prompt "INFO" && echo "Arrêt de la sélection."
            break
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#available_types[@]} )); then
            local partition_type="${available_types[choice-1]}"
            local size
            local fs_type

            case "$partition_type" in
                "boot")
                    # Demander la taille de la partition
                    size=$(_get_partition_size "$DEFAULT_BOOT_SIZE")
                    fs_type=$( _get_fs_type "$DEFAULT_BOOT_TYPE")
                    ;;
                "root")
                    # Demander la taille de la partition
                    size=$(_get_partition_size "$DEFAULT_ROOT_SIZE")
                    fs_type=$( _get_fs_type "$DEFAULT_ROOT_TYPE")
                    ;;
                "swap")
                    # Demander la taille de la partition
                    size=$(_get_partition_size "$DEFAULT_SWAP_SIZE")
                    fs_type="$DEFAULT_SWAP_TYPE"
                    ;;
                "home")
                    # Demander la taille de la partition
                    size=$(_get_partition_size "$DEFAULT_HOME_SIZE")
                    fs_type=$( _get_fs_type "$DEFAULT_HOME_TYPE")
                    ;;
            esac

            selected_partitions+=("$partition_type:$size:$fs_type")

            if [[ "$size" == "100%" ]]; then
                break
            else
                size_in_miB=$(convert_to_mib "$size")
            fi

            used_space=$((used_space + size_in_miB))

            _update_available_partitions

        else
            log_prompt "WARNING" && echo "Choix invalide. Veuillez entrer un numéro valide."
        fi
    done

    # Création des partitions
    echo
    log_prompt "INFO" && echo "Création des partitions sur /dev/$disk..."
    echo

    parted --script "/dev/$disk" mklabel gpt

    local partition_prefix=$([[ "$disk_type" == "nvme" ]] && echo "p" || echo "")

    for partition in "${formatted_partitions[@]}"; do
        IFS=':' read -r name size fs_type <<< "$partition"
        local partition_device="/dev/${disk}${partition_prefix}${partition_number}"

        if [[ "$size" != "100%" ]]; then
            local start_in_mib=$(convert_to_mib "$start")
            local size_in_mib=$(convert_to_mib "$size")
            local end_in_mib=$((start_in_mib + size_in_mib))
            end="${end_in_mib}MiB"
        else
            end="100%"
        fi

        parted --script -a optimal "/dev/$disk" mkpart primary "$start" "$end"

        case "$name" in
            "boot") parted --script "/dev/$disk" set "$partition_number" esp on ;;
            "swap") parted --script "/dev/$disk" set "$partition_number" swap on ;;
        esac

        case "$fs_type" in
            "btrfs") mkfs.btrfs -f -L "$name" "$partition_device" ;;
            "ext4") mkfs.ext4 -L "$name" "$partition_device" ;;
            "xfs") mkfs.xfs -f -L "$name" "$partition_device" ;;
            "fat32") mkfs.vfat -F32 -n "$name" "$partition_device" ;;
            "linux-swap")
                mkswap -L "$name" "$partition_device"
                swapon "$partition_device"
                ;;
        esac

        start="$end"
        ((partition_number++))
    done

    # Résumé des partitions créées
    echo
    echo "Partitions créées avec succès :"
    for partition in "${selected_partitions[@]}"; do
        echo "  - $partition"
    done
    echo "============================================"
}



# # Fonction pour préparer le disque création + formatage des partitions
# preparation_disk() {

#     # Déclaration de la liste de partitions pour une installation compléte du systeme
#     local partition_types=("boot:fat32:512MiB" "racine:btrfs:100GiB" "home:xfs:100%" "racine_home:btrfs:100%")

#     # Condition pour ajouter la partition swap si FILE_SWAP n'est pas "Off"
#     if [[ "${FILE_SWAP}" == "Off" ]]; then
#         partition_types+=("swap:linux-swap:4GiB")  # Ajouter la partition swap
#     fi

#     local disk="$1"
#     local remaining_types=("${partition_types[@]}")
#     local disk_size=$(lsblk -d -o SIZE --noheadings "/dev/$disk" | tr -d '[:space:]')
#     local disk_size_mib=$(convert_to_mib "$disk_size")
#     local used_space=0  
#     local selected_partitions=()
#     local size_in_miB
#     local remaining_space
#     local selected_index
#     local partition
#     local start
#     local end
#     local partition_number
#     local partition_prefix
#     local start_in_miB
#     local size_in_miB
#     local end_in_miB
#     local partition_device
    
#     echo ""

#     # Boucle pour configurer les partitions
#     while true; do
#         # Calculer l'espace restant en MiB
#         remaining_space=$((disk_size_mib - used_space))
        
#         log_prompt "INFO" && echo "Espace restant sur le disque : $(format_space $remaining_space) " && echo ""
#         log_prompt "INFO" && echo "Types de partitions disponibles : " && echo ""

#         echo ""
#         # Message d'avertissement concernant la partition racine
#         echo "ATTENTION : La partition racine (/) sera celle qui accueillera le système."
#         echo "Il est important de ne pas modifier son label (racine), car cela pourrait perturber l'installation."
#         echo "Par contre, le type (btrfs, ext4 ...) ou la taille de cette partition peut être modifiée, en particulier si elle occupe l'espace restant disponible."
#         echo ""
#         echo "boot        ==> partition efi."
#         echo "swap        ==> partition swap."
#         echo "racine      ==> partition root :  partition home séparée."
#         echo "racine_home ==> partition root :  partition pour root et home."
#         echo ""

#         # Afficher les types de partitions disponibles
#         for i in "${!remaining_types[@]}"; do
#             IFS=':' read -r name type size <<< "${remaining_types[$i]}"
#             printf "%d) %s (type: %s, taille par défaut: %s)\n" $((i+1)) "$name" "$type" "$size"
#         done

#         echo "0) Terminer la configuration des partitions" && echo ""

#         log_prompt "INFO" && read -p "Sélectionnez un type de partition (0 pour terminer) : " choice && echo ""
        
#         # Terminer si l'utilisateur choisit 0
#         if [[ "$choice" -eq 0 ]]; then
#             if [[ ${#selected_partitions[@]} -eq 0 ]]; then
#                 log_prompt "ERROR" && echo "Vous devez sélectionner au moins une partition." && echo ""
#                 continue
#             fi
#             break
#         fi
            
#         if [[ "$choice" -lt 1 || "$choice" -gt ${#remaining_types[@]} ]]; then
#             log_prompt "WARNING" && echo "Sélection invalide, réessayez." && echo ""
#             continue
#         fi
            
#         selected_index=$((choice-1))
#         partition="${remaining_types[$selected_index]}"
            
#         IFS=':' read -r name type default_size <<< "$partition"
            
#         # Demander la taille de la partition
#         while true; do
#             local custom_size=$(get_partition_size "$default_size")
#             if [[ $? -eq 0 ]]; then
#                 break  # La taille est valide, on sort de la boucle
#             else
#                 log_prompt "WARNING" && echo "Unité de taille invalide, [ MiB | GiB| % ] réessayez." && echo ""
#             fi
#         done
            
#         selected_partitions+=("$name:$type:$custom_size")

#         # Si la taille est "100%", on la considère comme prenant tout l'espace restant
#         if [[ "$custom_size" == "100%" ]]; then
#             # La partition prend tout l'espace restant
#             size_in_miB=$remaining_space
#             break  # Sortir de la boucle une fois qu'une partition de 100% est ajoutée
#         else
#             # Convertir la taille de la partition en MiB
#             size_in_miB=$(convert_to_mib "$custom_size")
#         fi

#         used_space=$((used_space + size_in_miB))
        
#         # Supprimer le type sélectionné du tableau remaining_types sans créer de "trou"
#         remaining_types=("${remaining_types[@]:0:$selected_index}" "${remaining_types[@]:$((selected_index+1))}")

#         clear
#     done
        
#     # Afficher les partitions sélectionnées
#     clear
#     log_prompt "INFO" && echo "Partitions sélectionnées : " && echo ""
#     for partition in "${selected_partitions[@]}"; do
#         IFS=':' read -r name type size <<< "$partition"
#         echo "$name ($type): $size"
#     done

#     echo ""

#     # Confirmer la création des partitions
#     log_prompt "INFO" && read -p "Confirmer la création des partitions (y/n) : " confirm && echo ""
#     if [[ "$confirm" != "y" ]]; then
#         echo "Annulation de la création des partitions."
#         exit 1
#     fi                                                  

#     # Créer la table de partition GPT
#     parted --script "/dev/$disk" mklabel gpt || { echo "Erreur: Impossible de créer la table de partition"; exit 1; }

#     start="1MiB"
#     partition_number=1

#     # Pour les disques NVMe, ajouter un préfixe "p"
#     if [[ "$disk_type" == "nvme" ]]; then
#         partition_prefix="p"
#     else
#         partition_prefix=""
#     fi

#     for partition in "${selected_partitions[@]}"; do
#         IFS=':' read -r name type size <<< "$partition"
        
#         if [[ "$size" == "100%" ]]; then
#             # La partition doit prendre tout l'espace restant
#             end="100%"
#         else
#             # Convertir la taille en MiB avant de faire des calculs
#             start_in_miB=$(convert_to_mib "$start")
#             size_in_miB=$(convert_to_mib "$size")
            
#             # Calculer la fin de la partition en MiB
#             end_in_miB=$(($start_in_miB + $size_in_miB))
#             end="${end_in_miB}MiB"
#         fi

#         # Créer la partition avec parted
#         partition_device="/dev/${disk}${partition_prefix}${partition_number}"
#         parted --script -a optimal "/dev/$disk" mkpart primary "$type" "$start" "$end" || { echo "Erreur: Impossible de créer la partition $name"; exit 1; }

#         # Définir des options supplémentaires selon le type de partition
#         case "$name" in
#             "boot") parted --script -a optimal "/dev/$disk" set "$partition_number" esp on ;;
#             "swap") parted --script -a optimal "/dev/$disk" set "$partition_number" swap on ;;
#         esac

#         # Formater la partition
#         case "$type" in
#             "ext4")  mkfs.ext4 -F -L "$name" "$partition_device" ;;
#             "xfs")   mkfs.xfs -f -L "$name" "$partition_device" ;;
#             "btrfs") mkfs.btrfs -f -L "$name" "$partition_device" ;;
#             "fat32") mkfs.vfat -F32 -n "$name" "$partition_device" ;;
#             "linux-swap")  mkswap -L "$name" "$partition_device" || { echo "Erreur lors de la création de la partition swap"; exit 1; } && swapon "$partition_device" || { echo "Erreur lors de l'activation de la partition swap"; exit 1; } ;;
#             *)
#                 echo "Erreur: Système de fichiers non supporté: $type" >&2
#                 continue
#                 ;;
#         esac

#         # Mise à jour de la position de départ pour la prochaine partition
#         start="$end"
#         ((partition_number++))
#     done

# }

# Fonction pour monter les partitions en fonction du system de fichier
mount_partitions() {

    local disk="$1"
    local partitions
    local NAME
    local SIZE
    local FSTYPE
    local LABEL
    local MOUNTPOINT
    local UUID

    mkdir -p "${MOUNT_POINT}"

    # récupération des partition à afficher sur le disque
    while IFS= read -r partition; do
        partitions+=("$partition")
    done < <(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | tr -d '└─├─')

    # Affiche les informations de chaque partition
    for partition in "${partitions[@]}"; do  # itérer sur le tableau des partitions
        if [ -b "/dev/$partition" ]; then
            # Récupérer chaque colonne séparément pour éviter toute confusion
            NAME=$(lsblk "/dev/$partition" -n -o NAME)
            FSTYPE=$(lsblk "/dev/$partition" -n -o FSTYPE)
            LABEL=$(lsblk "/dev/$partition" -n -o LABEL)

            case "$LABEL" in
                "boot")      
                    mkdir -p "${MOUNT_POINT}/boot"
                    mount "/dev/$NAME" "${MOUNT_POINT}/boot"
                    ;;

                "racine") 
                    mount "/dev/$NAME" "${MOUNT_POINT}" 

                    if [[ "$FSTYPE" == "btrfs" ]]; then
                        # Créer le sous-volume pour la racine ("/")
                        btrfs subvolume create ${MOUNT_POINT}/@
                    fi
                    
                    ;;

                "racine_home") 
                    mount "/dev/$NAME" "${MOUNT_POINT}" 

                    if [[ "$FSTYPE" == "btrfs" ]]; then
                        # Créer le sous-volume pour la racine ("/")
                        btrfs subvolume create ${MOUNT_POINT}/@
                    fi

                    ;;

                "home") 
                    mkdir -p "${MOUNT_POINT}/home"  
                    mount "/dev/$NAME" "${MOUNT_POINT}/home"
                    ;;

                "swap")  
                    log_prompt "INFO" && echo "Partition swap déja monté"
                    ;;

                *)
                    echo "Erreur: Label non reconnu: $LABEL"
                    continue
                    ;;
            esac
        fi
    done

}

# Fonction pour gérer le swap (activation, désactivation, création, etc.)
manage_swap() {
    
    if [[ "${ENABLE_SWAP}" == "On" ]] && [[ "${FILE_SWAP}" == "On" ]]; then
        # Création d'un fichier swap si FILE_SWAP="On"
        log_prompt "INFO" && echo "création du dossier $MOUNT_POINT/swap" 
        mkdir -p $MOUNT_POINT/swap
        log_prompt "SUCCESS" && echo "OK" && echo ""

        log_prompt "INFO" && echo "création du fichier $MOUNT_POINT/swap/swapfile" 
        dd if=/dev/zero of="$MOUNT_POINT/swap/swapfile" bs=1G count="${SIZE_SWAP}" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo ""

        log_prompt "INFO" && echo "Permission + activation du fichier $MOUNT_POINT/swap/swapfile" 
        chmod 600 "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors du changement des permissions du fichier swap"; exit 1; }
        mkswap "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
        swapon "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de l'activation du fichier swap"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo ""
    fi
}