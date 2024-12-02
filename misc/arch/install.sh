#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.
source $SCRIPT_DIR/functions_disk.sh  # Charge les fonctions définies dans le fichier fonction_disk.sh.
source $SCRIPT_DIR/functions_install.sh  # Charge les fonctions définies dans le fichier fonction_disk.sh.

# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
  log_prompt "ERROR" && echo "Veuillez exécuter ce script en tant qu'utilisateur root."
  exit 1
fi

##############################################################################
## Valide la connexion internet                                                          
##############################################################################
log_prompt "INFO" && echo "Vérification de la connexion Internet"
$(ping -c 3 archlinux.org &>/dev/null) || (log_prompt "ERROR" && echo "Pas de connexion Internet" && echo "")
log_prompt "SUCCESS" && echo "OK" && echo "" && sleep 3


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

partitions=$(lsblk -n -o NAME "/dev/$disk" | grep -v "^$disk$" | sed -n "s/^[[:graph:]]*${disk}\([0-9]*\)$/${disk}\1/p")


# Vérifie si des partitions existent
if [ -z "$partitions" ]; then

    ##############################################################################
    ## Disque vierge                                                    
    ##############################################################################

    # TODO: Implémenter cette partie plus tard
    # Cette section de code n'est pas terminée, elle nécessite encore du travail.

    echo "Status : Le disque est vierge"
    echo "Device : /dev/$disk"
    echo "Taille : $(lsblk -n -o SIZE "/dev/$disk" | head -1)"
    echo "Type   : $(lsblk -n -o TRAN "/dev/$disk")"
    echo ""

    # Afficher le menu
    while true; do

        log_prompt "INFO" && echo "Que souhaitez-vous faire : " && echo ""

        echo "1) Installation de Arch Linux"
        echo "2) Annuler"
        echo

        log_prompt "INFO" && read -p "Votre Choix (1-2) " choice && echo "" 

        case $choice in
            1)
                log_prompt "INFO" && read -p "Souhaitez-vous procéder au formatage du disque "/dev/$disk" ? (y/n) : " choice && echo ""
                if [[ "$choice" =~ ^[yY]$ ]]; then
                    erase_disk "$disk"                    
                fi
                preparation_disk "$disk"
                show_disk_partitions "Montage des partitions" "$disk"
                mount_partitions "$disk"
                show_disk_partitions "Montage des partitions terminée" "$disk"
                install_base "$disk"
                install_base_chroot "$disk"
                install_base_secu
                activate_service
                
                log_prompt "INFO" && echo "Installation terminée ==> redémarrage du system"

                break
                ;;
            2)
                echo "Opération annulée"
                exit 0
                ;;
            *)
                echo "Choix invalide"
                ;;
        esac
    done



else

    ##############################################################################
    ## Disque partitionné                                                    
    ##############################################################################

    # TODO: Implémenter cette partie plus tard
    # Cette section de code n'est pas terminée, elle nécessite encore du travail.
    # Ex. formatage d'une partition en particulier pour réinstallation du systeme

    echo "$(show_disk_partitions "Le disque n'est pas vierge" "$disk")"
    echo ""

    # Afficher le menu
    while true; do

        log_prompt "INFO" && echo "Que souhaitez-vous faire : " && echo ""

        echo "1) Nettoyage du disque          ==> Suppression des données sur /dev/$disk"
        echo "2) Installation de Arch Linux   ==> Espace total sur le disque /dev/$disk"
        echo "3) Réinstallation de Arch Linux ==> Partition Racine"
        echo "4) Installation en double boot  ==> Windows - Arch Linux"
        echo "5) Annuler"
        echo

        log_prompt "INFO" && read -p "Votre Choix (1-5) " choice && echo "" 

        case $choice in
            1)
                clear
                erase_disk "$disk"
                break
                ;;
            2)
                clear
                preparation_disk "$disk"
                show_disk_partitions "Montage des partitions" "$disk"
                mount_partitions "$disk"
                show_disk_partitions "Montage des partitions terminée" "$disk"
                install_base "$disk"
                install_base_chroot "$disk"
                install_base_secu
                activate_service

                log_prompt "INFO" && echo "arch-chroot - mkinitcpio"
                arch-chroot "${MOUNT_POINT}" mkinitcpio -P
                log_prompt "SUCCESS" && echo "OK" && echo ""
                break
                ;;
            3)
                log_prompt "INFO" && read -p "Entrez le nom de la partition racine à effacer (ex: sda3) : " partition && echo ""
                if [ -b "/dev/$partition" ]; then
                    erase_partition "$partition"
                else
                    echo "Partition invalide !"
                fi

                log_prompt "INFO" && echo "A venir" && echo ""

                break
                ;;
            4)
                log_prompt "INFO" && echo "A venir" && echo ""
                break
                ;;
            5)
                echo "Opération annulée"
                exit 0
                ;;
            *)
                echo "Choix invalide"
                ;;
        esac
    done
fi