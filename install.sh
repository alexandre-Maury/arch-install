#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.

##############################################################################
## Valide la connexion internet                                                          
##############################################################################
log_prompt "INFO" && echo "Vérification de la connexion Internet" && echo ""
$(ping -c 3 archlinux.org &>/dev/null) || (log_prompt "ERROR" && echo "Pas de connexion Internet" && echo "")
log_prompt "SUCCESS" && echo "Terminée" && echo "" && sleep 3

##############################################################################
## Mettre à jour l'horloge du système                                                     
##############################################################################
clear 
timedatectl set-ntp true
log_prompt "WARNING" && echo "Le statut du service Date/Heure est . . ." && echo ""
timedatectl status && sleep 4

##############################################################################
## Bienvenu                                                    
##############################################################################
log_prompt "INFO" && echo "Bienvenue dans le script d'installation de Arch Linux !" && echo "" 

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
    log_prompt "INFO" && read -p "Votre Choix : " OPTION
    echo ""

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

##############################################################################
## Validation de la configuration                                                       
##############################################################################
clear

echo "[ ${DISK} ]"                   "- Disque"
echo "[ ${MODE} ]"                   "- Mode"
echo "[ ${REGION} ]"                 "- Zone Info - region" 
echo "[ ${CITY} ]"                   "- Zone Info - city" 
echo "[ ${LOCALE} ]"                 "- Locale" 
echo "[ ${HOSTNAME} ]"               "- Nom d'hôte" 
echo "[ ${INTERFACE} ]"              "- Interface" 
echo "[ ${KEYMAP} ]"                 "- Disposition du clavier" 
echo "[ ${USERNAME} ]"               "- Votre utilisateur" 
echo ""

# Demande tant que la réponse n'est pas y/Y ou n/N
while true; do

    log_prompt "INFO" && read -p "Vérifiez que les informations ci-dessus sont correctes (Y/n) : " CONFIGURATION && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$CONFIGURATION" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y/y (oui) ou N/n (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$CONFIGURATION" =~ ^[yY]$ ]]; then
    log_prompt "INFO" && echo "Suite de l'installation" && echo ""
else
    # Si l'utilisateur répond N ou n
    log_prompt "WARNING" && echo "Modifier le fichier config.sh."
    log_prompt "ERROR" && echo "Annulation de l'installation."
    exit 0
fi


##############################################################################
## Création des partitions + formatage et montage                                                      
##############################################################################


while true; do

    # Affichage de la table des partitions pour vérification
    parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }
    echo ""
    log_prompt "INFO" && read -p "Voulez-vous nettoyer le disque ${DISK} (Y/n) [ Attention pas encore testé ]: " DISKCLEAN && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$DISKCLEAN" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y/y (oui) ou N/n (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$DISKCLEAN" =~ ^[yY]$ ]]; then
    # Effacement du disque
    log_prompt "INFO" && echo "Préparation du disque dur /dev/${DISK}" && echo ""

    # Vérification que le disque existe
    if [[ ! -b "/dev/$DISK" ]]; then
        log_prompt "ERROR" && echo "le disque spécifié (${DISK}) n'existe pas." && echo ""
        exit 1
    fi

    # Liste les partitions du disque
    PARTITIONS=$(lsblk -ln -o NAME "/dev/${DISK}" | grep -E "${DISK}[0-9]+")
    if [[ -z $PARTITIONS ]]; then
        log_prompt "INFO" && echo "Aucune partition trouvée sur ${DISK}." && echo ""
    else
        log_prompt "INFO" && echo "Partitions trouvées sur ${DISK} :" && echo ""
        echo "$PARTITIONS" && echo ""
        
        # Boucle pour supprimer chaque partition
        for PART in $PARTITIONS; do

            PART_PATH="/dev/${PART}"

            # Désactiver le swap si la partition est configurée comme swap
            if swapon --show=NAME | grep -q "${PART_PATH}"; then
                echo "Désactivation du swap sur ${PART_PATH}..."
                swapoff "${PART_PATH}" || { echo "Erreur lors de la désactivation du swap sur ${PART_PATH}"; exit 1; }
            fi

            # Vérifie si la partition est montée
            if mount | grep -q "${PART_PATH}"; then
                echo "Démontage de ${PART_PATH}..."
                umount --force --recursive "${PART_PATH}" || { log_prompt "INFO" && echo "Impossible de démonter ${PART_PATH}."; }
            fi

            PART_NUM=${PART##*[^0-9]}  # Récupère le numéro de la partition
            log_prompt "INFO" && echo "Suppression de la partition ${DISK}${PART_NUM}..." && echo ""
            parted "/dev/${DISK}" --script rm "${PART_NUM}" || { log_prompt "ERROR" && echo "Erreur lors de la suppression de ${DISK}${PART_NUM}"; exit 1; }
        done
    fi

    log_prompt "SUCCESS" && echo "Toutes les partitions ont été supprimées du disque ${DISK}." && echo ""

    wipefs --force --all /dev/${DISK} || { echo "Erreur lors de l'effacement du disque"; exit 1; }
    shred -n "${SHRED_PASS}" -v "/dev/${DISK}" || { echo "Erreur lors de l'effacement sécurisé"; exit 1; }

else
    log_prompt "INFO" && echo "Suite de l'installation" && echo ""
fi


# Détermination du mode (UEFI ou MBR)
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="MBR"
fi

# Réinitialisation de la table de partitions
if [[ "${MODE}" == "UEFI" ]]; then
    log_prompt "INFO" && echo "Création de la table GPT" && echo ""
    parted --script -a optimal /dev/${DISK} mklabel gpt || { echo "Erreur lors de la création de la table GPT"; exit 1; }
    log_prompt "INFO" && echo "Création de la partition EFI" && echo ""
    parted --script -a optimal /dev/${DISK} mkpart primary fat32 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 esp on
else
    log_prompt "INFO" && echo "Création de la table MBR" && echo ""
    parted --script -a optimal /dev/${DISK} mklabel msdos || { echo "Erreur lors de la création de la table MBR"; exit 1; }
    log_prompt "INFO" && echo "Création de la partition BOOT" && echo ""
    parted --script -a optimal /dev/${DISK} mkpart primary ext4 1MiB "${SIZE_BOOT}" || { echo "Erreur lors de la création de la partition boot"; exit 1; }
    parted --script -a optimal /dev/${DISK} set 1 boot on
fi

if  [[ "${ENABLE_SWAP}" == "On" ]] && [[ "${FILE_SWAP}" == "Off" ]]; then
    log_prompt "INFO" && echo "Création de la partition SWAP" && echo ""
    parted --script -a optimal /dev/${DISK} mkpart primary linux-swap "${SIZE_BOOT}" "${SIZE_SWAP}" || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    log_prompt "INFO" && echo "Activation du SWAP" && echo ""
    mkswap /dev/${DISK}2 || { echo "Erreur lors de la création de la partition swap"; exit 1; }
    swapon /dev/${DISK}2 || { echo "Erreur lors de l'activation de la partition swap"; exit 1; }

    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        log_prompt "INFO" && echo "Création de la partition ROOT/HOME" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=3
        PART_HOME=""  # Désactivation de la partition home spécifique
    else
        # Création de partitions séparées pour root et home
        log_prompt "INFO" && echo "Création de la partition ROOT" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_SWAP}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        log_prompt "INFO" && echo "Création de la partition HOME" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=3
        PART_HOME=4
    fi

else # Le swap est désactiver

    # Gestion de la fusion root et home
    if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
        # Création d'une seule partition pour root + home
        log_prompt "INFO" && echo "Création de la partition ROOT/HOME" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "100%" || { echo "Erreur lors de la création de la partition root/home"; exit 1; }
        PART_ROOT=2
        PART_HOME=""  # Désactivation de la partition home spécifique
    else
        # Création de partitions séparées pour root et home
        log_prompt "INFO" && echo "Création de la partition ROOT" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_BOOT}" "${SIZE_ROOT}" || { echo "Erreur lors de la création de la partition root"; exit 1; }
        log_prompt "INFO" && echo "Création de la partition HOME" && echo ""
        parted --script -a optimal /dev/${DISK} mkpart primary "${FS_TYPE}" "${SIZE_ROOT}" "100%" || { echo "Erreur lors de la création de la partition home"; exit 1; }
        PART_ROOT=2
        PART_HOME=3
    fi
fi

# Formatage des partitions en fonction du système de fichiers spécifié
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT/HOME" && echo ""
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT" && echo ""
mkfs."${FS_TYPE}" /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en "${FS_TYPE}" "; exit 1; }
# Montage des partitions
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT/HOME" && echo ""
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT" && echo ""
mkdir -p "${MOUNT_POINT}" && mount /dev/${DISK}${PART_ROOT} "${MOUNT_POINT}" || { echo "Erreur lors du montage de la partition root"; exit 1; }

if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition HOME" && echo ""
    mkfs."${FS_TYPE}" /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home en "${FS_TYPE}" "; exit 1; }
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home"; exit 1; }
fi

# Si root et home sont séparés, monter home
if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Création du point de montage de la partition HOME" && echo ""
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home"; exit 1; }
fi

# Formatage de la partition boot en fonction du mode
if [[ "${MODE}" == "UEFI" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition EFI" && echo ""
    mkfs.vfat -F32 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition efi en FAT32"; exit 1; }

    log_prompt "INFO" && echo "Création du point de montage de la partition EFI" && echo ""
    mkdir -p "${MOUNT_POINT}/efi" && mount /dev/${DISK}1 "${MOUNT_POINT}/efi" || { echo "Erreur lors du montage de la partition boot"; exit 1; }
else
    log_prompt "INFO" && echo "Formatage de la partition BOOT" && echo ""
    mkfs.ext4 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition boot en ext4"; exit 1; }

    log_prompt "INFO" && echo "Création du point de montage de la partition BOOT" && echo ""
    mkdir -p "${MOUNT_POINT}/boot" && mount /dev/${DISK}1 "${MOUNT_POINT}/boot" || { echo "Erreur lors du montage de la partition boot"; exit 1; }
fi

# Gestion de la swap
if [[ "${ENABLE_SWAP}" == "On" ]] && [[ "${FILE_SWAP}" == "On" ]]; then
    # Création d'un fichier swap si FILE_SWAP="On"
    log_prompt "INFO" && echo "création du dossier $MOUNT_POINT/swap" && echo ""
    mkdir -p $MOUNT_POINT/swap
    

    log_prompt "INFO" && echo "création du fichier $MOUNT_POINT/swap/swapfile" && echo ""
    dd if=/dev/zero of="$MOUNT_POINT/swap/swapfile" bs=1G count="${SIZE_SWAP}" || { echo "Erreur lors de la création du fichier swap"; exit 1; }

    log_prompt "INFO" && echo "Permission + activation du fichier $MOUNT_POINT/swap/swapfile" && echo ""
    chmod 600 "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors du changement des permissions du fichier swap"; exit 1; }
    mkswap "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de la création du fichier swap"; exit 1; }
    swapon "$MOUNT_POINT/swap/swapfile" || { echo "Erreur lors de l'activation du fichier swap"; exit 1; }
fi

log_prompt "SUCCESS" && echo "Partitionnement et formatage terminés avec succès !" && echo ""

# Affichage de la table des partitions pour vérification
parted /dev/${DISK} print || { echo "Erreur lors de l'affichage des partitions"; exit 1; }

##############################################################################
## Installation du système de base                                                
##############################################################################
reflector --country ${PAYS} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
pacstrap -K ${MOUNT_POINT} base base-devel linux linux-headers linux-firmware dkms

##############################################################################
## arch-chroot Generating the fstab                                                 
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Génération du fstab" && echo ""
genfstab -U -p ${MOUNT_POINT} >> ${MOUNT_POINT}/etc/fstab
cat ${MOUNT_POINT}/etc/fstab
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Définir le fuseau horaire                                                  
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Configuration du fuseau horaire" && echo ""
arch-chroot ${MOUNT_POINT} ln -sf /usr/share/zoneinfo/${REGION}/${CITY} /etc/localtime
arch-chroot ${MOUNT_POINT} hwclock --systohc --utc
arch-chroot ${MOUNT_POINT} date
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Configuration de la langue + clavier                                                    
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Configuration des locales" && echo ""
arch-chroot ${MOUNT_POINT} echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
arch-chroot ${MOUNT_POINT} echo "${LOCALE}" > /etc/locale.gen
arch-chroot ${MOUNT_POINT} echo "LANG=$LANG" > /etc/locale.conf
arch-chroot ${MOUNT_POINT} locale-gen
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Configuration du réseau                                             
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Génération du hostname" && echo ""
echo "${HOSTNAME}" > ${MOUNT_POINT}/etc/hostname
echo "127.0.0.1 localhost" >> ${MOUNT_POINT}/etc/hosts
echo "::1 localhost" >> ${MOUNT_POINT}/etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> ${MOUNT_POINT}/etc/hosts
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Install packages                                                
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Installation des paquages de bases" && echo ""
arch-chroot ${MOUNT_POINT} pacman -Syu --noconfirm
arch-chroot ${MOUNT_POINT} pacman -S git openssh networkmanager dhcpcd man-db man-pages pambase --noconfirm
arch-chroot ${MOUNT_POINT} pacman -S sudo bash-completion sshpass --noconfirm


arch-chroot ${MOUNT_POINT} systemctl enable dhcpcd.service
arch-chroot ${MOUNT_POINT} systemctl enable sshd.service
arch-chroot ${MOUNT_POINT} systemctl enable NetworkManager.service
arch-chroot ${MOUNT_POINT} systemctl enable systemd-homed

##############################################################################
## Installation des pilotes CPU et GPU                                          
##############################################################################

# Détection du type de processeur
proc_type=$(lscpu | awk '/Vendor ID:/ {print $3}')

if echo "$proc_type" | grep -q "GenuineIntel"; then
    log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
    proc_ucode="intel-ucode.img"

elif echo "$proc_type" | grep -q "AuthenticAMD"; then
    log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
    proc_ucode="amd-ucode.img"

else
    log_prompt "WARNING" && echo "arch-chroot - Processeur non reconnu" && echo ""
    read -p "Quel microcode installer (Intel/AMD/ignorer) ? " proctype && echo ""
    
    case "$proctype" in
        Intel|intel)
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel" && echo ""
            arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
            proc_ucode="intel-ucode.img"
            ;;
        AMD|amd)
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD" && echo ""
            arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
            proc_ucode="amd-ucode.img"
            ;;
        ignore|Ignore)
            log_prompt "WARNING" && echo "arch-chroot - L'utilisateur a choisi de ne pas installer de microcode" && echo ""
            ;;
        *)
            log_prompt "ERROR" && echo "Option invalide. Aucun microcode installé." && echo ""
            ;;
    esac
fi

# Détection et installation des pilotes graphiques
if lspci | grep -E "NVIDIA|GeForce"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes NVIDIA" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S nvidia-dkms nvidia-utils opencl-nvidia \
    libglvnd lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings \
    --noconfirm 

elif lspci | grep -E "Radeon"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes AMD Radeon" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-amdgpu --noconfirm 

elif lspci | grep -E "Integrated Graphics Controller"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes Intel pour GPU intégré" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S libva-intel-driver libvdpau-va-gl \
    lib32-vulkan-intel vulkan-intel libva-utils intel-gpu-tools --noconfirm 
else
    log_prompt "WARNING" && echo "arch-chroot - Aucun GPU reconnu, aucun pilote installé." && echo ""
fi


##############################################################################
## arch-chroot Installing grub and creating configuration                                               
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Installation de grub" && echo ""

arch-chroot ${MOUNT_POINT} pacman -S grub os-prober --noconfirm

if [[ "$MODE" == "UEFI" ]]; then
    arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
    arch-chroot ${MOUNT_POINT} grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB

elif [[ "$MODE" == "BIOS" ]]; then
    arch-chroot ${MOUNT_POINT} grub-install --target=i386-pc --no-floppy /dev/"${DISK}"

else
	log_prompt "ERROR" && echo "Une erreur est survenue $MODE non reconnu"
	exit 1
fi

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Générer la configuration de GRUB                                           
##############################################################################
log_prompt "INFO" && echo "arch-chroot - configuration de grub" && echo ""


cat <<EOF | arch-chroot "$MOUNT_POINT" bash
if [[ -n "$proc_ucode" ]]; then
    echo "initrd /boot/$proc_ucode" >> /boot/grub/grub.cfg
fi
EOF

arch-chroot ${MOUNT_POINT} grub-mkconfig -o /boot/grub/grub.cfg


##############################################################################
## arch-chroot Création d'un nouvel initramfs                                             
##############################################################################
arch-chroot ${MOUNT_POINT} mkinitcpio -p linux

##############################################################################
## arch-chroot Création d'un mot de passe root                                             
##############################################################################
# Demande tant que la réponse n'est pas y/Y ou n/N
while true; do
    log_prompt "INFO" && read -p "Souhaitez-vous changer le mot de passe root (Y/n) : " PASSROOT && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$PASSROOT" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)."
        echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$PASSROOT" =~ ^[yY]$ ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration du compte root" && echo ""
    
    # Demande de changer le mot de passe root, boucle jusqu'à réussite
    while ! arch-chroot ${MOUNT_POINT} passwd "root" ; do
        sleep 1
    done
    
    log_prompt "SUCCESS" && echo "Mot de passe root configuré avec succès."
    
# Si l'utilisateur répond N ou n
else
    log_prompt "WARNING" && echo "Attention, le mot de passe root d'origine est conservé." && echo ""
fi


##############################################################################
## arch-chroot Création d'un utilisateur + mot de passe                                            
##############################################################################
arch-chroot ${MOUNT_POINT} sed -i 's/# %wheel/%wheel/g' /etc/sudoers
arch-chroot ${MOUNT_POINT} sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

log_prompt "INFO" && read -p "Saisir le nom d'utilisateur souhaité :" sudo_user 
arch-chroot ${MOUNT_POINT} useradd -m -G wheel "$sudo_user"

log_prompt "INFO" && echo "arch-chroot - Configuration du mot de passe pour l'utilisateur $sudo_user" && echo ""
while ! arch-chroot ${MOUNT_POINT} passwd "$sudo_user"; do
    sleep 1
done


##############################################################################
## Fin du script                                          
##############################################################################
log_prompt "SUCCESS" && echo "Installation Terminée ==> shutdown -h" && echo ""