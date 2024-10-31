#!/usr/bin/env bash

# script functions.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
LIGHT_CYAN='\033[0;96m'
RESET='\033[0m'

# Vérifie et installe un package si absent

check_and_install() {
    local package="$1"
    local install_command=""

    # Déterminer le gestionnaire de paquets disponible
    if command -v pacman &> /dev/null; then
        install_command="pacman -Sy --noconfirm $package"
    else
        echo "Aucun gestionnaire de paquets compatible trouvé."
        return 1
    fi

    # Réessayer l'installation tant que le package n'est pas disponible
    until command -v "$package" &> /dev/null; do
        log_prompt "INFO" && echo "Installation de $package..."
        eval "$install_command"

        if command -v "$package" &> /dev/null; then
            log_prompt "SUCCESS" && echo "$package a été installé avec succès."
        else
            log_prompt "ERROR" && echo "L'installation de $package a échoué. Nouvelle tentative..."
        fi
    done
}

log_prompt() {
    local log_level="$1" # INFO - WARNING - ERROR - SUCCESS
    local log_date="$(date +"%Y-%m-%d %H:%M:%S")"

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

# Fonction pour valider le nom du disque
validate_disk() {
    local disk=$1
    if [[ ! $disk =~ $VALID_DISK_PATTERN ]]; then
        log_prompt "ERROR" && echo "Nom de disque invalide : ${disk}" && echo ""
        return 1
    fi
    if [[ ! -b "/dev/$disk" ]]; then
        log_prompt "ERROR" && echo "Le disque spécifié (/dev/${disk}) n'existe pas" && echo ""
        return 1
    fi
    return 0
}

# Fonction pour démonter une partition
unmount_partition() {
    local part_path=$1
    
    # Vérifier si c'est une partition swap
    if swapon --show=NAME | grep -q "${part_path}"; then
        log_prompt "INFO" && echo "Désactivation du swap sur ${part_path}..." && echo ""
        if ! swapoff "${part_path}"; then
            log_prompt "ERROR" && echo "Échec de la désactivation du swap sur ${part_path}" && echo ""
            return 1
        fi
    fi
    
    # Vérifier si la partition est montée
    if mount | grep -q "${part_path}"; then
        log_prompt "INFO" && echo "Démontage de ${part_path}..." && echo ""
        if ! umount --force --recursive "${part_path}"; then
            log_prompt "ERROR" && echo "Impossible de démonter ${part_path}" && echo ""
            return 1
        fi
    fi
    return 0
}

# Fonction principale pour nettoyer le disque
clean_disk() {
    local disk=$1

    # Afficher la table des partitions actuelle
    log_prompt "INFO" && echo "Table des partitions actuelle pour /dev/${disk}:" && echo ""
    parted "/dev/${disk}" print || return 1
    
    # Obtenir la liste des partitions
    local partitions
    partitions=$(lsblk -ln -o NAME "/dev/${disk}" | grep -E "${disk}[0-9]+")
    
    if [[ -n $partitions ]]; then
        log_prompt "INFO" && echo "Suppression des partitions existantes..." && echo ""
        
        # Traiter chaque partition
        while read -r part; do
            local part_path="/dev/${part}"
            unmount_partition "${part_path}" || return 1
            
            local part_num=${part##*[^0-9]}
            log_prompt "INFO" && echo "Suppression de la partition ${disk}${part_num}..." && echo ""
            if ! parted "/dev/${disk}" --script rm "${part_num}"; then
                log_prompt "ERROR" && echo "Échec de la suppression de ${disk}${part_num}" && echo ""
                return 1
            fi
        done <<< "$partitions"
    else
        log_prompt "INFO" && echo "Aucune partition trouvée sur ${disk}" && echo ""
    fi
    
    # Effacement sécurisé du disque
    log_prompt "INFO" "Effacement des signatures du disque..." && echo ""
    if ! wipefs --force --all "/dev/${disk}"; then
        log_prompt "ERROR" && echo "Échec de l'effacement des signatures du disque" && echo ""
        return 1
    fi
    
    log_prompt "INFO" "Début de l'effacement sécurisé (${SHRED_PASS} passes)..." && echo ""
    if ! shred -n "${SHRED_PASS}" -v "/dev/${disk}"; then
        log_prompt "ERROR" && echo "Échec de l'effacement sécurisé" && echo ""
        return 1
    fi
    
    log_prompt "SUCCESS" && echo "Nettoyage du disque ${disk} terminé avec succès" && echo ""
    return 0
}