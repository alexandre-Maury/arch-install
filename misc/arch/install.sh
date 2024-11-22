#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.


# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
  log_prompt "ERROR" && echo "Veuillez exécuter ce script en tant qu'utilisateur root."
  exit 1
fi


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

# Vérifier le type de disque (SATA ou NVMe)
if [[ "$disk" =~ ^nvme ]]; then
    partition_prefix="p"   # Format pour NVMe, ex: nvme0n1
fi

clear

##############################################################################
## Sélection des partitions                                                     
##############################################################################

# Vérification si le disque est vide (sans partition)
partitions=$(lsblk $disk -n -o NAME | grep -E "^$disk[0-9]+")

if [[ -z "$partitions" ]]; then
    # Le disque est vide, donc il n'y a pas de partitions
    log_prompt "INFO" && echo "Le disque /dev/$disk est vide, vous pouvez créer de nouvelles partitions."


else
    # Le disque contient des partitions
    log_prompt "INFO" && echo "Le disque /dev/$disk contient les partitions suivantes :"
    echo "$partitions"
fi

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

selected_partitions=()
remaining_types=("${PARTITION_TYPES[@]}")

while true; do
    log_prompt "INFO" && echo "Types de partitions disponibles : " && echo ""
    for i in "${!remaining_types[@]}"; do
        IFS=':' read -r name type size <<< "${remaining_types[$i]}"
        printf "%d) %s (type: %s, taille par défaut: %s)\n" $((i+1)) "$name" "$type" "$size"
    done

    echo "0) Terminer la configuration des partitions" && echo ""

    log_prompt "INFO" && read -p "Sélectionnez un type de partition (0 pour terminer) : " choice && echo ""
    
        
    if [[ "$choice" -eq 0 ]]; then
        if [[ ${#selected_partitions[@]} -eq 0 ]]; then
            log_prompt "ERROR" && echo "Vous devez sélectionner au moins une partition. " && echo ""
            continue
        fi
        break
    fi
        
    if [[ "$choice" -lt 1 || "$choice" -gt ${#remaining_types[@]} ]]; then
        echo "Sélection invalide, réessayez."
        log_prompt "WARNING" && echo "Sélection invalide, réessayez." && echo ""
        continue
    fi
        
    selected_index=$((choice-1))
    partition="${remaining_types[$selected_index]}"
        
    IFS=':' read -r name type default_size <<< "$partition"
        
    # Demander la taille de partition
    while true; do
        custom_size=$(get_partition_size "$default_size")
        if [[ $? -eq 0 ]]; then
            break  # La taille est valide, on sort de la boucle
        else
            echo ""
            log_prompt "WARNING" && echo "Unité de taille invalide, [ MiB | GiB| % ] réessayez." && echo ""
        fi
    done
        
    selected_partitions+=("$name:$type:$custom_size")

    # Supprimer le type sélectionné du tableau remaining_types sans créer de "trou"
    remaining_types=("${remaining_types[@]:0:$selected_index}" "${remaining_types[@]:$((selected_index+1))}")

    clear

done
    
log_prompt "INFO" && echo "Partitions sélectionnées : " && echo ""
for partition in "${selected_partitions[@]}"; do
    IFS=':' read -r name type size <<< "$partition"
    echo "$name ($type): $size"
done

echo ""

# Confirmer la création des partitions
log_prompt "INFO" && read -p "Confirmer la création des partitions (y/n) : " confirm && echo ""
if [[ "$confirm" != "y" ]]; then
    echo "Annulation de la création des partitions."
    exit 1
fi

##############################################################################
## Création des partitions                                                     
##############################################################################

# Vérification de l'espace disponible sur le disque
available_space=$(lsblk -d -o SIZE --noheadings "/dev/$disk" | tr -d '[:space:]')
echo "Espace total disponible sur $disk : $available_space"

parted --script "/dev/$disk" mklabel gpt || { echo "Erreur: Impossible de créer la table de partition"; exit 1; }

start="1MiB"
partition_number=1

for partition in "${selected_partitions[@]:1}"; do
    IFS=':' read -r name type size <<< "$partition"

    # Calcul de la taille de la partition et fin
    if [[ "$size" == "100%" ]]; then
        end="100%"
    else
        end=$(($(echo "$start" | numfmt --from=iec) + $(echo "$size" | numfmt --from=iec)))
        end=$(numfmt --to=iec "${end}")
    fi

    # Création de la partition
    parted --script "/dev/$disk" mkpart primary "$type" "$start" "$end" || { echo "Erreur: Impossible de créer la partition $name"; exit 1; }

    case "$name" in
        "boot") parted --script "/dev/$disk" set "$partition_number" esp on ;;
        "swap") parted --script "/dev/$disk" set "$partition_number" swap on ;;
    esac

    start="$end"
    ((partition_number++))
done