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

    list=${1}

    if [[ -z "${list}" ]]; then
        log_prompt "ERROR" "Aucun disque disponible pour l'installation."
        exit 1  # Arrête le script ou effectue une autre action en cas d'erreur
    else
        log_prompt "INFO" "Choisissez un disque pour l'installation (ex : 1) : "
        echo "${list}"  # Affiche la liste des disques disponibles
    fi

    # Boucle pour que l'utilisateur puisse choisir un disque ou en entrer un manuellement
    OPTION=""
    while true; do
        read -p "Votre Choix : " OPTION  # Demander le choix à l'utilisateur
        echo ""

        # Vérification si l'utilisateur a entré un numéro dans la liste
        if [[ -n "$(echo "${list}" | grep -e "^[[:space:]]*${OPTION}[[:space:]]*\)")" ]]; then
            # Si l'utilisateur a choisi un numéro valide, récupérer le nom du disque correspondant
            DISK="$(echo "${list}" | grep -e "^[[:space:]]*${OPTION}[[:space:]]*\)" | awk '{print $2}')"
            break
        elif [[ -b "$OPTION" ]]; then
            # Si l'utilisateur a entré un nom de disque valide, utiliser ce nom
            DISK="$OPTION"
            break
        else
            log_prompt "ERROR" "Choix invalide, veuillez entrer un numéro valide ou un nom de disque."
        fi
    done

    # Retourner le disque choisi
    echo "$DISK"
}

# Appel de la fonction et récupération du disque choisi
list_disk="$(lsblk -d -n | grep -v -e "loop" -e "sr" | awk '{print $1, $4}' | nl -s") ")"
echo $list_disk
disk=$(select_disk $list_disk)

# Affichage du disque choisi
echo "Vous avez choisi le disque : $disk"
