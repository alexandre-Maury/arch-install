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

# Afficher les types de partitions disponibles
display_partition_types() {
    echo "Types de partitions disponibles :"
    for i in "${!PARTITION_TYPES[@]}"; do
        IFS=':' read -r name type size <<< "${PARTITION_TYPES[$i]}"
        printf "%d) %s (type: %s, taille par défaut: %s)\n" $((i+1)) "$name" "$type" "$size"
    done
}

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

# Récupérer la liste des disques disponibles (exclut les disques "loop" et "sr")
select_disk() {
    LIST="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")" 

    if [[ -z "${LIST}" ]]; then
        log_prompt "ERROR" && echo "Aucun disque disponible pour l'installation."
        exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
    else
        log_prompt "INFO" && echo "Choisissez un disque pour l'installation (ex : 1) : " && echo ""
        echo "${LIST}" && echo ""
    fi

    # Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
    OPTION=""
    while [[ -z "$(echo "${LIST}" | grep "  ${OPTION})")" ]]; do
        log_prompt "INFO" && read -p "Votre Choix : " OPTION && echo ""
        

        # Vérification si l'utilisateur a entré un numéro (choix dans la liste)
        if [[ -n "$(echo "${LIST}" | grep "  ${OPTION})")" ]]; then
            # Si l'utilisateur a choisi un numéro valide, récupérer le nom du disque correspondant
            DISK="$(echo "${LIST}" | grep "  ${OPTION})" | awk '{print $2}')"
            break
        else
            # Si l'utilisateur a entré quelque chose qui n'est pas dans la liste, considérer que c'est un nom de disque
            DISK="${OPTION}"
            break
        fi
    done
}

# Sélectionner et configurer les partitions
select_partitions() {
    local selected_partitions=()
    local remaining_types=("${PARTITION_TYPES[@]}")

    while true; do
        display_partition_types
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
        
        local selected_index=$((choice-1))
        local partition="${remaining_types[$selected_index]}"
        
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
}

# Créer les partitions sur le disque
create_partitions() {
    local disk="$1"
    local partitions=("$@")

    # Vérification de l'espace disponible sur le disque
    local available_space
    available_space=$(lsblk -d -o SIZE --noheadings "$disk" | tr -d '[:space:]')
    echo "Espace total disponible sur $disk : $available_space"

    parted --script "$disk" mklabel gpt || { echo "Erreur: Impossible de créer la table de partition"; exit 1; }

    local start="1MiB"
    local partition_number=1
    for partition in "${partitions[@]:1}"; do
        IFS=':' read -r name type size <<< "$partition"

        # Calcul de la taille de la partition et fin
        local end
        if [[ "$size" == "100%" ]]; then
            end="100%"
        else
            end=$(($(echo "$start" | numfmt --from=iec) + $(echo "$size" | numfmt --from=iec)))
            end=$(numfmt --to=iec "${end}")
        fi

        # Création de la partition
        parted --script "$disk" mkpart primary "$type" "$start" "$end" || { echo "Erreur: Impossible de créer la partition $name"; exit 1; }

        case "$name" in
            "boot") parted --script "$disk" set "$partition_number" esp on ;;
            "swap") parted --script "$disk" set "$partition_number" swap on ;;
        esac

        start="$end"
        ((partition_number++))
    done
}

# Fonction principale
main() {
    # Sélectionner un disque
    local disk
    disk=$(select_disk)
    
    # # Sélectionner et configurer les partitions
    # local selected_partitions
    # selected_partitions=$(select_partitions)
    
    # # Créer les partitions sur le disque choisi
    # create_partitions "$disk" $selected_partitions
}

# Appel de la fonction principale
main
