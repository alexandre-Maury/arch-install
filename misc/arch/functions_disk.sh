#!/bin/bash

# script functions_disk.sh

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

detect_disk_type() {
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
    local disk_type=$(detect_disk_type "$disk")
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
            if [[ "$custom_fs" =~ ^(ext4|btrfs|xfs|fat32)$ ]]; then
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
        echo
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
            echo "  $i ) partition : $type"
            ((i++))
        done
        echo
        echo "  exit ) : Saisir "q" pour quitter"
        echo
    }

    # Processus interactif pour la sélection des partitions
    while [[ ${#available_types[@]} -gt 0 ]]; do
        clear
        _display_menu
        
        log_prompt "INFO" && read -rp "Sélectionnez un type de partition (q pour terminer) : " choice

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

    if [[ "$MODE" == "UEFI" ]]; then
        log_prompt "INFO" && echo "Création de la table GPT" && echo
        parted --script -a optimal /dev/$disk mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo ""
    else
        log_prompt "INFO" && echo "Création de la table MBR"
        parted --script -a optimal /dev/$disk mklabel msdos || { echo "Erreur lors de la création de la table MBR"; exit 1; }   
        log_prompt "SUCCESS" && echo "OK" && echo               
    fi
    

    local partition_prefix=$([[ "$disk_type" == "nvme" ]] && echo "p" || echo "")

    for partition in "${selected_partitions[@]}"; do
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

        log_prompt "INFO" && echo "Création de la partition $partition_device"
        parted --script -a optimal "/dev/$disk" mkpart primary "$start" "$end" || { echo "Erreur lors de la création de la partition $partition_device"; exit 1; }
        log_prompt "SUCCESS" && echo "OK" && echo

        case "$name" in
            "boot") 
                if [[ "$MODE" == "UEFI" ]]; then
                    log_prompt "INFO" && echo "Activation de la partition boot $partition_device en mode UEFI"
                    parted --script -a optimal "/dev/$disk" set "$partition_number" esp on || { echo "Erreur lors de l'activation de la partition $partition_device"; exit 1; }
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                else
                    log_prompt "INFO" && echo "Activation de la partition boot $partition_device en mode LEGACY"
                    parted --script -a optimal /dev/$disk set "$partition_number" boot on || { echo "Erreur lors de l'activation de la partition $partition_device"; exit 1; }
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                fi
                ;;

            "swap") 
                log_prompt "INFO" && echo "Activation de la partition swap $partition_device"
                parted --script -a optimal "/dev/$disk" set "$partition_number" swap on || { echo "Erreur lors de l'activation de la partition $partition_device"; exit 1; }
                log_prompt "SUCCESS" && echo "OK" && echo ""
                ;;
        esac

        log_prompt "INFO" && echo "Formatage de la partition $partition_device en $fs_type"

        case "$fs_type" in
            "btrfs")
                mkfs.btrfs -f -L "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;
            "ext4")
                mkfs.ext4 -L "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;
            "xfs")
                mkfs.xfs -f -L "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;
            "fat32")
                mkfs.vfat -F32 -n "$name" "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;
            "linux-swap")
                mkswap -L "$name" "$partition_device" && swapon "$partition_device" || {
                    log_prompt "ERROR" && echo "Erreur lors du formatage ou de l'activation de la partition $partition_device en $fs_type"
                    exit 1
                }
                ;;
            *)
                log_prompt "ERROR" && echo "$fs_type : type de fichier non reconnu"
                exit 1
                ;;
        esac

        log_prompt "SUCCESS" && echo "OK" && echo


        start="$end"
        ((partition_number++))
    done

    # Résumé des partitions créées
    echo
    log_prompt "SUCCESS" && echo "Partitions créées avec succès :"
    for partition in "${selected_partitions[@]}"; do
        echo "  - $partition"
    done

}

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


    local create_home=false
    for part in "${partitions[@]}"; do
        local part_label=$(lsblk "/dev/$part" -n -o LABEL)
        if [[ "$part_label" == "home" ]]; then
            create_home=true
            break
        fi
    done

    # Affiche les informations de chaque partition
    for partition in "${partitions[@]}"; do  # itérer sur le tableau des partitions
        if [ -b "/dev/$partition" ]; then
            # Récupérer chaque colonne séparément pour éviter toute confusion
            NAME=$(lsblk "/dev/$partition" -n -o NAME)
            FSTYPE=$(lsblk "/dev/$partition" -n -o FSTYPE)
            LABEL=$(lsblk "/dev/$partition" -n -o LABEL)
            SIZE=$(lsblk "/dev/$partition" -n -o SIZE)

            log_prompt "INFO" && echo "Traitement de la partition : /dev/$NAME (Label: $LABEL, FS: $FSTYPE)"

            case "$LABEL" in
                "boot")      
                    mkdir -p "${MOUNT_POINT}/boot"
                    mount "/dev/$NAME" "${MOUNT_POINT}/boot"
                    ;;

                "root") 
                    # Vérifier si c'est un système de fichiers Btrfs
                    if [[ "$FSTYPE" == "btrfs" ]]; then
                        # Monter temporairement la partition
                        mount "/dev/$NAME" "${MOUNT_POINT}"

                        # Créer les sous-volumes de base
                        btrfs subvolume create "${MOUNT_POINT}/@"
                        btrfs subvolume create "${MOUNT_POINT}/@root"
                        btrfs subvolume create "${MOUNT_POINT}/@srv"
                        btrfs subvolume create "${MOUNT_POINT}/@log"
                        btrfs subvolume create "${MOUNT_POINT}/@cache"
                        btrfs subvolume create "${MOUNT_POINT}/@tmp"
                        btrfs subvolume create "${MOUNT_POINT}/@snapshots"
                        
                        # Créer @home si nécessaire
                        if [ "$create_home" = false ]; then
                            btrfs subvolume create "${MOUNT_POINT}/@home"
                            log_prompt "INFO" && echo "Sous-volume @home créé car aucune partition home n'existe."
                        fi
                        
                        # Démonter la partition temporaire
                        umount "${MOUNT_POINT}"

                        # Remonter les sous-volumes avec des options spécifiques
                        echo "Montage des sous-volumes Btrfs avec options optimisées..."
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@ "/dev/$NAME" "${MOUNT_POINT}"

                        mkdir -p "${MOUNT_POINT}/root"
                        mkdir -p "${MOUNT_POINT}/srv"
                        mkdir -p "${MOUNT_POINT}/var/log"
                        mkdir -p "${MOUNT_POINT}/var/cache/"
                        mkdir -p "${MOUNT_POINT}/tmp"
                        mkdir -p "${MOUNT_POINT}/snapshots"

                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@root "/dev/$NAME" "${MOUNT_POINT}/root"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@tmp "/dev/$NAME" "${MOUNT_POINT}/tmp"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@srv "/dev/$NAME" "${MOUNT_POINT}/srv"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@log "/dev/$NAME" "${MOUNT_POINT}/var/log"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@cache "/dev/$NAME" "${MOUNT_POINT}/var/cache"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@snapshots "/dev/$NAME" "${MOUNT_POINT}/snapshots"
                        
                        # Si @home a été créé (pas de partition home), le monter
                        if [ "$create_home" = false ]; then
                            mkdir -p "${MOUNT_POINT}/home"
                            mount -o defaults,noatime,compress=zstd,commit=120,subvol=@home "/dev/$NAME" "${MOUNT_POINT}/home"
                        fi

                    elif [[ "$FSTYPE" == "ext4" ]]; then
                        # Pour les autres systèmes de fichiers
                        mount "/dev/$NAME" "${MOUNT_POINT}"
                    fi
                    
                    ;;

                "home") 
                    # Vérifier si c'est un système de fichiers Btrfs
                    if [[ "$FSTYPE" == "btrfs" ]]; then
                        mkdir -p "${MOUNT_POINT}/home"
                        btrfs subvolume create "${MOUNT_POINT}/@home"
                        mount -o defaults,noatime,compress=zstd,commit=120,subvol=@home "/dev/$NAME" "${MOUNT_POINT}/home"

                    elif [[ "$FSTYPE" == "ext4" ]]; then
                        mkdir -p "${MOUNT_POINT}/home"  
                        mount "/dev/$NAME" "${MOUNT_POINT}/home"
                    fi
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