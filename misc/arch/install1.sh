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
## Récupération des disques disponible                                                      
##############################################################################
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