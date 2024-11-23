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

clear


##############################################################################
## Sélection & Création des partitions                                                     
##############################################################################
partitions=$(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | tr -d '└─├─') # Récupère les partitions du disque

# Vérifie si des partitions existent
if [ -z "$partitions" ]; then

    ##############################################################################
    ## Disque vierge - Sélection des partitions                                                     
    ##############################################################################

    # TODO: Implémenter cette partie plus tard
    # Cette section de code n'est pas terminée, elle nécessite encore du travail.
    # Ex. formatage des partitions ==> OK (test à effectuer)

    echo "Status : Le disque est vierge"
    echo "Device : /dev/$disk"
    echo "Taille : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
    echo "Type   : $(lsblk -n -o TRAN "/dev/$disk")"

    disk_size=$(lsblk -d -o SIZE --noheadings "/dev/$disk" | tr -d '[:space:]')
    disk_size_mib=$(convert_to_mib "$disk_size")  # Convertir la taille du disque en MiB
    used_space=0  # Initialiser l'espace utilisé
    selected_partitions=()
    remaining_types=("${PARTITION_TYPES[@]}")

    echo ""

    # Boucle pour configurer les partitions
    while true; do
        # Calculer l'espace restant en MiB
        remaining_space=$((disk_size_mib - used_space))
        
        log_prompt "INFO" && echo "Espace restant sur le disque : $(format_space $remaining_space) " && echo ""
        log_prompt "INFO" && echo "Types de partitions disponibles : " && echo ""
        
        # Afficher les types de partitions disponibles
        for i in "${!remaining_types[@]}"; do
            IFS=':' read -r name type size <<< "${remaining_types[$i]}"
            printf "%d) %s (type: %s, taille par défaut: %s)\n" $((i+1)) "$name" "$type" "$size"
        done

        echo "0) Terminer la configuration des partitions" && echo ""

        log_prompt "INFO" && read -p "Sélectionnez un type de partition (0 pour terminer) : " choice && echo ""
        
        # Terminer si l'utilisateur choisit 0
        if [[ "$choice" -eq 0 ]]; then
            if [[ ${#selected_partitions[@]} -eq 0 ]]; then
                log_prompt "ERROR" && echo "Vous devez sélectionner au moins une partition." && echo ""
                continue
            fi
            break
        fi
            
        if [[ "$choice" -lt 1 || "$choice" -gt ${#remaining_types[@]} ]]; then
            log_prompt "WARNING" && echo "Sélection invalide, réessayez." && echo ""
            continue
        fi
            
        selected_index=$((choice-1))
        partition="${remaining_types[$selected_index]}"
            
        IFS=':' read -r name type default_size <<< "$partition"
            
        # Demander la taille de la partition
        while true; do
            custom_size=$(get_partition_size "$default_size")
            if [[ $? -eq 0 ]]; then
                break  # La taille est valide, on sort de la boucle
            else
                log_prompt "WARNING" && echo "Unité de taille invalide, [ MiB | GiB| % ] réessayez." && echo ""
            fi
        done
            
        selected_partitions+=("$name:$type:$custom_size")

        # Si la taille est "100%", on la considère comme prenant tout l'espace restant
        if [[ "$custom_size" == "100%" ]]; then
            # La partition prend tout l'espace restant
            size_in_miB=$remaining_space
            break  # Sortir de la boucle une fois qu'une partition de 100% est ajoutée
        else
            # Convertir la taille de la partition en MiB
            size_in_miB=$(convert_to_mib "$custom_size")
        fi

        used_space=$((used_space + size_in_miB))
        
        # Supprimer le type sélectionné du tableau remaining_types sans créer de "trou"
        remaining_types=("${remaining_types[@]:0:$selected_index}" "${remaining_types[@]:$((selected_index+1))}")

        clear
    done
        
    # Afficher les partitions sélectionnées
    clear
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
    ## Disque vierge - Création des partitions                                                     
    ##############################################################################

    # Créer la table de partition GPT
    parted --script "/dev/$disk" mklabel gpt || { echo "Erreur: Impossible de créer la table de partition"; exit 1; }

    start="1MiB"
    partition_number=1

    # Pour les disques NVMe, ajouter un préfixe "p"
    if [[ "$disk_type" == "nvme" ]]; then
        partition_prefix="p"
    else
        partition_prefix=""
    fi

    for partition in "${selected_partitions[@]}"; do
        IFS=':' read -r name type size <<< "$partition"
        
        if [[ "$size" == "100%" ]]; then
            # La partition doit prendre tout l'espace restant
            end="100%"
        else
            # Convertir la taille en MiB avant de faire des calculs
            start_in_miB=$(convert_to_mib "$start")
            size_in_miB=$(convert_to_mib "$size")
            
            # Calculer la fin de la partition en MiB
            end_in_miB=$(($start_in_miB + $size_in_miB))
            end="${end_in_miB}MiB"
        fi

        # Créer la partition avec parted
        partition_device="/dev/${disk}${partition_prefix}${partition_number}"
        parted --script -a optimal "/dev/$disk" mkpart primary "$type" "$start" "$end" || { echo "Erreur: Impossible de créer la partition $name"; exit 1; }

        # Définir des options supplémentaires selon le type de partition
        case "$name" in
            "boot") parted --script -a optimal "/dev/$disk" set "$partition_number" esp on ;;
            "swap") parted --script -a optimal "/dev/$disk" set "$partition_number" swap on ;;
        esac

        # Formater la partition
        case "$type" in
            "ext4")  mkfs.ext4 -F -L "$name" "$partition_device" ;;
            "ext3")  mkfs.ext3 -F -L "$name" "$partition_device" ;;
            "xfs")   mkfs.xfs -f -L "$name" "$partition_device" ;;
            "btrfs") mkfs.btrfs -f -L "$name" "$partition_device" ;;
            "fat32") mkfs.vfat -F32 -n "$name" "$partition_device" ;;
            "ntfs")  mkfs.ntfs -F -L "$name" "$partition_device" ;;
            "linux-swap")  mkswap -L "$name" "$partition_device" || { echo "Erreur lors de la création de la partition swap"; exit 1; } && swapon "$partition_device" || { echo "Erreur lors de l'activation de la partition swap"; exit 1; } ;;
            *)
                echo "Erreur: Système de fichiers non supporté: $type" >&2
                continue
                ;;
        esac

        # Mise à jour de la position de départ pour la prochaine partition
        start="$end"
        ((partition_number++))
    done

    partitions=$(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | tr -d '└─├─') # Récupère les partitions du disque
    echo "$(format_disk "Le disque est partitionné" "$partitions" "$disk")"

else

    ##############################################################################
    ## Disque partitionné - Affichage des partitions                                                     
    ##############################################################################

    # TODO: Implémenter cette partie plus tard
    # Cette section de code n'est pas terminée, elle nécessite encore du travail.
    # Ex. formatage d'une partition en particulier pour réinstallation du systeme

    echo "$(format_disk "Le disque est partitionné" "$partitions" "$disk")"
    echo ""

    # Afficher le menu
    while true; do

        log_prompt "INFO" && echo "Que souhaitez-vous faire : " && echo ""

        echo "1) Effacer tout le disque /dev/$disk"
        echo "2) Effacer une partition spécifique"
        echo "3) Annuler"
        echo

        log_prompt "INFO" && read -p "Votre Choix (1-3) " choice 

        case $choice in
            1)
                erase_disk "$disk"
                break
                ;;
            2)
                list_partitions "$disk"
                echo -n "Entrez le nom de la partition à effacer (ex: sda1) : "
                read -r partition
                if [ -b "/dev/$partition" ]; then
                    erase_partition "$partition"
                else
                    echo "Partition invalide !"
                fi
                break
                ;;
            3)
                echo "Opération annulée"
                exit 0
                ;;
            *)
                echo "Choix invalide"
                ;;
        esac
    done


fi