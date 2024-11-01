#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.


# Vérifier les privilèges root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant qu'utilisateur root."
  exit 1
fi

##############################################################################
## Valide la connexion internet                                                          
##############################################################################
log_prompt "INFO" && echo "Vérification de la connexion Internet" && echo ""
$(ping -c 3 archlinux.org &>/dev/null) || (log_prompt "ERROR" && echo "Pas de connexion Internet" && echo "")
log_prompt "SUCCESS" && echo "Terminée" && echo "" && sleep 3

##############################################################################
## Bienvenue                                                    
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

# Affichage des informations
# Affichage des informations
echo "=============================================="
echo "Informations de configuration"
echo "=============================================="
echo ""

echo "Mode d'installation : $MODE"

if [[ "${MODE}" == "UEFI" ]]; then
    echo "Taille de la partition EFI : $SIZE_BOOT"
else
    echo "Taille de la partition de boot : $SIZE_BOOT"
fi

if [[ "${ENABLE_SWAP}" == "On" ]]; then
    if [[ "${FILE_SWAP}" == "On" ]]; then
        echo "Taille du fichier swap : $SIZE_SWAP"
    else
        echo "Taille de la partition swap : $SIZE_SWAP"
    fi
fi

# Afficher des informations sur la fusion root/home
if [[ "${MERGE_ROOT_HOME}" == "On" ]]; then
    echo "Taille de la partition root : $SIZE_ROOT"
else
    echo "Taille de la partition root : $SIZE_ROOT"
    echo "Taille de la partition home : $SIZE_HOME"
fi

if [[ "${MODE}" == "UEFI" ]]; then
    echo "Bootloader : $BOOTLOADER"
elif [[ "${MODE}" == "MBR" ]] && [[ "${BOOTLOADER}" == "systemd-boot" ]]; then
    log_prompt "WARNING" && echo "systemd-boot ne peut être utilisé qu'en mode UEFI."
else
    echo "Bootloader : $BOOTLOADER"
fi

echo "Pays : $PAYS"
echo "Region : $REGION"
echo "City : $CITY"
echo "Locale : $LOCALE"
echo "Langue : $LANG"
echo "Hostname : $HOSTNAME"
echo "Interface : $INTERFACE"
echo "Keymap : $KEYMAP"
echo "Locale : $LOCALE"
echo "GPU : $GPU_VENDOR"
echo ""
echo "=============================================="
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
    log_prompt "WARNING" && echo "Annulation de l'installation, modifier le fichier config/config.sh."
    exit 0
fi

##############################################################################
## Création des partitions + formatage et montage                                                      
##############################################################################
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
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT/HOME ==> /dev/${DISK}${PART_ROOT}" && echo ""
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Formatage de la partition ROOT ==> /dev/${DISK}${PART_ROOT}" && echo ""
mkfs."${FS_TYPE}" /dev/${DISK}${PART_ROOT} || { echo "Erreur lors du formatage de la partition root en "${FS_TYPE}" "; exit 1; }
# Montage des partitions
[[ "${MERGE_ROOT_HOME}" == "On" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT/HOME ==> /dev/${DISK}${PART_ROOT}" && echo ""
[[ "${MERGE_ROOT_HOME}" == "Off" ]] && log_prompt "INFO" && echo "Création du point de montage de la partition ROOT ==> /dev/${DISK}${PART_ROOT}" && echo ""
mkdir -p "${MOUNT_POINT}" && mount /dev/${DISK}${PART_ROOT} "${MOUNT_POINT}" || { echo "Erreur lors du montage de la partition root"; exit 1; }

if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition HOME ==> /dev/${DISK}${PART_HOME}" && echo ""
    mkfs."${FS_TYPE}" /dev/${DISK}${PART_HOME} || { echo "Erreur lors du formatage de la partition home ==> /dev/${DISK}${PART_HOME} en "${FS_TYPE}" "; exit 1; }
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home ==> /dev/${DISK}${PART_HOME}"; exit 1; }
fi

# Si root et home sont séparés, monter home
if [[ -n "${PART_HOME}" ]]; then
    log_prompt "INFO" && echo "Création du point de montage de la partition HOME ==> /dev/${DISK}${PART_HOME}" && echo ""
    mkdir -p "${MOUNT_POINT}/home" && mount /dev/${DISK}${PART_HOME} "${MOUNT_POINT}/home" || { echo "Erreur lors du montage de la partition home ==> /dev/${DISK}${PART_HOME}"; exit 1; }
fi

# Formatage de la partition boot en fonction du mode
if [[ "${MODE}" == "UEFI" ]]; then
    log_prompt "INFO" && echo "Formatage de la partition EFI" && echo ""
    mkfs.vfat -F32 /dev/${DISK}1 || { echo "Erreur lors du formatage de la partition efi en FAT32"; exit 1; }

    log_prompt "INFO" && echo "Création du point de montage de la partition EFI" && echo ""
    mkdir -p "${MOUNT_POINT}/boot" && mount /dev/${DISK}1 "${MOUNT_POINT}/boot" || { echo "Erreur lors du montage de la partition boot"; exit 1; }
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
## Configuration du system                                                    
##############################################################################
nc=$(grep -c ^processor /proc/cpuinfo)  # Compte le nombre de cœurs de processeur
log_prompt "INFO" && echo "Vous avez " $nc " coeurs." && echo ""
log_prompt "INFO" && echo "Changement des makeflags pour " $nc " coeurs." && echo ""

TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')  # Récupère la mémoire totale
if [[  $TOTALMEM -gt 8000000 ]]; then  # Vérifie si la mémoire totale est supérieure à 8 Go
    sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les makeflags dans makepkg.conf
    log_prompt "INFO" && echo "Changement des paramètres de compression pour " $nc " coeurs." && echo ""
    sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les paramètres de compression
fi

##############################################################################
## arch-chroot Définir le fuseau horaire + local                                                  
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Configuration des locales" && echo ""
echo "KEYMAP=${KEYMAP}" > ${MOUNT_POINT}/etc/vconsole.conf
sed -i "/^#$LOCALE/s/^#//g" ${MOUNT_POINT}/etc/locale.gen
arch-chroot ${MOUNT_POINT} locale-gen

# log_prompt "INFO" && echo "arch-chroot - Configuration du fuseau horaire" && echo ""
# timedatectl set-ntp true
# timedatectl set-timezone ${REGION}/${CITY}
# localectl set-locale LANG="${LANG}" LC_TIME="${LANG}"
# hwclock --systohc --utc

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Modification pacman.cof                                                  
##############################################################################
sed -i 's/^#Para/Para/' ${MOUNT_POINT}/etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' ${MOUNT_POINT}/etc/pacman.conf

arch-chroot ${MOUNT_POINT} pacman -Sy --noconfirm

##############################################################################
## arch-chroot Configuration du réseau                                             
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Génération du hostname" && echo ""
echo "${HOSTNAME}" > ${MOUNT_POINT}/etc/hostname
echo "127.0.0.1 localhost" >> ${MOUNT_POINT}/etc/hosts
echo "::1 localhost" >> ${MOUNT_POINT}/etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> ${MOUNT_POINT}/etc/hosts

mkdir -p ${MOUNT_POINT}/etc/systemd/network

log_prompt "INFO" && echo "Configuration de /etc/systemd/network/20-wired.network" && echo ""
cat <<EOF | sudo tee ${MOUNT_POINT}/etc/systemd/network/20-wired.network > /dev/null
[Match]
Name=${INTERFACE}
MACAddress=${MAC_ADDRESS}

[Network]
DHCP=yes

[DHCPv4]
RouteMetric=10
UseDNS=false
EOF

log_prompt "INFO" && echo "Configuration de /etc/resolv.conf pour utiliser systemd-resolved" && echo ""
ln -sf /run/systemd/resolve/stub-resolv.conf ${MOUNT_POINT}/etc/resolv.conf

log_prompt "INFO" && echo "Écrire la configuration DNS dans /etc/systemd/resolved.conf" && echo ""
tee ${MOUNT_POINT}/etc/systemd/resolved.conf > /dev/null <<EOF
[Resolve]
DNS=${DNS_SERVERS}
FallbackDNS=${FALLBACK_DNS} 
EOF

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Install packages                                                
##############################################################################
log_prompt "INFO" && echo "arch-chroot - Installation des paquages de bases" && echo ""
arch-chroot ${MOUNT_POINT} pacman -Syu --noconfirm
arch-chroot ${MOUNT_POINT} pacman -S man-db man-pages nano cmake meson ninja gcc sudo pambase sshpass xdg-user-dirs git curl tar wget --noconfirm



##############################################################################
## Installation des pilotes CPU et GPU                                          
##############################################################################

# Détection du type de processeur
if lscpu | awk '{print $3}' | grep -E "GenuineIntel"; then
    log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
    proc_ucode="intel-ucode.img"

elif lscpu | awk '{print $3}' | grep -E "AuthenticAMD"; then
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

# Détection du GPU

log_prompt "INFO" && echo "GPU détecté : $GPU_VENDOR" && echo ""

# Choix des modules et options en fonction du GPU
if [[ "$GPU_VENDOR" == *"nvidia"* ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU NVIDIA" && echo ""
    MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
    KERNEL_OPTION="nvidia_drm.modeset=1"

    arch-chroot "${MOUNT_POINT}" pacman -S nvidia mesa --noconfirm
    # xf86-video-nouveau
    modprobe $MODULES

    sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
    [ ! -d "${MOUNT_POINT}/etc/pacman.d/hooks" ] && mkdir -p ${MOUNT_POINT}/etc/pacman.d/hooks
    echo "[Trigger]" > ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Operation=Install" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Operation=Upgrade" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Operation=Remove" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Type=Package" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Target=nvidia" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "[Action]" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Depends=mkinitcpio" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "When=PostTransaction" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    echo "Exec=/usr/bin/mkinitcpio -P" >> ${MOUNT_POINT}/etc/pacman.d/hooks/nvidia.hook
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

elif [[ "$GPU_VENDOR" == *"amd"* || "$GPU_VENDOR" == *"radeon"* ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU AMD/Radeon" && echo ""
    MODULES="amdgpu"
    KERNEL_OPTION="amdgpu.dc=1"

    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-amdgpu xf86-video-ati mesa --noconfirm 
    modprobe $MODULES

    sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

elif [[ "$GPU_VENDOR" == *"intel"* ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU Intel" && echo ""
    MODULES="i915"
    KERNEL_OPTION="i915.enable_psr=1"

    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-intel mesa --noconfirm 
    modprobe $MODULES

    sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

elif [[ "$GPU_VENDOR" == *"virtualbox"* ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration pour VirtualBox" && echo ""
    MODULES="vboxvideo"
    KERNEL_OPTION="video=virtualbox"

    arch-chroot "${MOUNT_POINT}" pacman -S virtualbox-guest-utils mesa --noconfirm 
    modprobe $MODULES

    sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

elif [[ "$GPU_VENDOR" == *"vmware"* ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration pour VMware" && echo ""
    MODULES="vmwgfx"
    KERNEL_OPTION="video=vmwgfx"

    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-vmware mesa --noconfirm 
    modprobe $MODULES

    sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

else
    log_prompt "WARNING" && echo "arch-chroot - Aucun GPU reconnu, aucun pilote installé." && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-vesa mesa --noconfirm
fi

##############################################################################
## arch-chroot Installation du bootloader (GRUB ou systemd-boot) en mode UEFI ou BIOS                                               
##############################################################################
if [[ "${BOOTLOADER}" == "grub" ]]; then
    log_prompt "INFO" && echo "arch-chroot - Installation de GRUB" && echo ""
    arch-chroot ${MOUNT_POINT} pacman -S grub os-prober --noconfirm

    if [[ "$MODE" == "UEFI" ]]; then
        arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
        arch-chroot ${MOUNT_POINT} grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

    elif [[ "$MODE" == "BIOS" ]]; then
        arch-chroot ${MOUNT_POINT} grub-install --target=i386-pc --no-floppy /dev/"${DISK}"
    else
        log_prompt "ERROR" && echo "Une erreur est survenue : $MODE non reconnu." && exit 1
    fi

    log_prompt "INFO" && echo "arch-chroot - configuration de grub" && echo ""

    if [[ -n "${KERNEL_OPTION}" ]]; then
        sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/&$KERNEL_OPTION /" /etc/default/grub
    fi

    arch-chroot ${MOUNT_POINT} grub-mkconfig -o /boot/grub/grub.cfg

    if [[ -n "${proc_ucode}" ]]; then
        echo "initrd /boot/$proc_ucode" >> ${MOUNT_POINT}/boot/grub/grub.cfg
    fi

elif [[ "${BOOTLOADER}" == "systemd-boot" ]]; then

    if [[ "$MODE" == "UEFI" ]]; then
        log_prompt "INFO" && echo "arch-chroot - Installation de systemd-boot" && echo ""

        arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
        arch-chroot ${MOUNT_POINT} bootctl --path=/boot install

        log_prompt "INFO" && echo "arch-chroot - Configuration de systemd-boot : arch.conf" && echo ""
        echo "title   Arch Linux" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        echo "linux   /vmlinuz-linux" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        echo "initrd  /${proc_ucode}" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        echo "initrd  /initramfs-linux.img" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        # echo "options root=/dev/${DISK}${PART_ROOT} rw" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf

        if [[ -n "${KERNEL_OPTION}" ]]; then
            echo "options root=/dev/${DISK}${PART_ROOT} rw $KERNEL_OPTION" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        else
            echo "options root=/dev/${DISK}${PART_ROOT} rw" >> ${MOUNT_POINT}/boot/loader/entries/arch.conf
        fi

        log_prompt "INFO" && echo "arch-chroot - Configuration de systemd-boot : loader.conf" && echo ""
        echo "default arch.conf" >> ${MOUNT_POINT}/boot/loader/loader.conf
        echo "timeout 4" >> ${MOUNT_POINT}/boot/loader/loader.conf
        echo "console-mode max" >> ${MOUNT_POINT}/boot/loader/loader.conf
        echo "editor no" >> ${MOUNT_POINT}/boot/loader/loader.conf
    else
        log_prompt "ERROR" && echo "systemd-boot ne peut être utilisé qu'en mode UEFI." && exit 1
    fi

else
    
    log_prompt "ERROR" && echo "Bootloader non reconnu" && exit 1
fi

log_prompt "SUCCESS" && echo "Installation terminée." && echo ""



##############################################################################
## arch-chroot Création d'un nouvel initramfs                                             
##############################################################################
log_prompt "INFO" && echo "arch-chroot - mkinitcpio"
arch-chroot ${MOUNT_POINT} mkinitcpio -p linux

##############################################################################
## Configuration de PAM                                  
##############################################################################
log_prompt "INFO" && echo "Configuration de passwdqc.conf" && echo ""

# Sauvegarde de l'ancien fichier passwdqc.conf
if [ -f "${MOUNT_POINT}$PASSWDQC_CONF" ]; then
    cp "${MOUNT_POINT}$PASSWDQC_CONF" "${MOUNT_POINT}$PASSWDQC_CONF.bak"
    log_prompt "INFO" && echo "Sauvegarde du fichier existant passwdqc.conf en $PASSWDQC_CONF.bak" && echo ""
fi

# Génération du nouveau contenu de passwdqc.conf
cat <<EOF > "${MOUNT_POINT}$PASSWDQC_CONF"
min=$MIN
max=$MAX
passphrase=$PASSPHRASE
match=$MATCH
similar=$SIMILAR
enforce=$ENFORCE
retry=$RETRY
EOF

# Vérification du succès
if [ $? -eq 0 ]; then
    log_prompt "SUCCESS" && echo "Fichier passwdqc.conf mis à jour avec succès." && echo ""
else
    log_prompt "WARNING" && echo "Erreur lors de la mise à jour du fichier passwdqc.conf." && echo ""
fi

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
        log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$PASSROOT" =~ ^[yY]$ ]]; then
    log_prompt "INFO" && echo "arch-chroot - Configuration du compte root" && echo ""

    # Demande de changer le mot de passe root
    while true; do
        read -p "Veuillez entrer le nouveau mot de passe pour root : " -s NEW_PASS && echo ""
        read -p "Confirmez le mot de passe : " -s CONFIRM_PASS && echo ""

        # Vérifie si les mots de passe correspondent
        if [[ "$NEW_PASS" == "$CONFIRM_PASS" ]]; then
            echo -e "$NEW_PASS\n$NEW_PASS" | arch-chroot ${MOUNT_POINT} passwd "root"
            echo ""
            log_prompt "SUCCESS" && echo "Mot de passe root configuré avec succès." && echo ""
            break
        else
            log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
        fi
    done

# Si l'utilisateur répond N ou n
else
    log_prompt "WARNING" && echo "Attention, le mot de passe root d'origine est conservé." && echo ""
fi


##############################################################################
## arch-chroot Création d'un utilisateur + mot de passe                                            
##############################################################################
arch-chroot ${MOUNT_POINT} sed -i 's/# %wheel/%wheel/g' /etc/sudoers
arch-chroot ${MOUNT_POINT} sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

# Demande tant que la réponse n'est pas y/Y ou n/N
while true; do
    log_prompt "INFO" && read -p "Souhaitez-vous créer un utilisateur (Y/n) : " USER && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$USER" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)." && echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$USER" =~ ^[yY]$ ]]; then

    log_prompt "INFO" && read -p "Saisir le nom d'utilisateur souhaité : " sudo_user && echo ""
    arch-chroot ${MOUNT_POINT} useradd -m -G wheel,audio,video,optical,storage,power,input "$sudo_user"

    # Demande de changer le mot de passe $USER
    while true; do
        read -p "Veuillez entrer le nouveau mot de passe pour $sudo_user : " -s NEW_PASS && echo ""
        read -p "Confirmez le mot de passe : " -s CONFIRM_PASS && echo ""

        # Vérifie si les mots de passe correspondent
        if [[ "$NEW_PASS" == "$CONFIRM_PASS" ]]; then
            echo -e "$NEW_PASS\n$NEW_PASS" | arch-chroot ${MOUNT_POINT} passwd $sudo_user
            echo ""
            log_prompt "SUCCESS" && echo "Mot de passe $sudo_user configuré avec succès." && echo ""
            break
        else
            log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
        fi
    done
fi

##############################################################################
## Modifier le fichier de configuration pour renforcer la sécurité                                     
##############################################################################
sed -i "s/#Port 22/Port $SSH_PORT/" "${MOUNT_POINT}$SSH_CONFIG_FILE"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' "${MOUNT_POINT}$SSH_CONFIG_FILE"

##############################################################################
## Activation des services                                        
##############################################################################
arch-chroot ${MOUNT_POINT} systemctl enable sshd
arch-chroot ${MOUNT_POINT} systemctl enable systemd-homed
arch-chroot ${MOUNT_POINT} systemctl enable systemd-networkd 
arch-chroot ${MOUNT_POINT} systemctl enable systemd-resolved 

umount -R ${MOUNT_POINT}

##############################################################################
## Fin du script                                          
##############################################################################
log_prompt "SUCCESS" && echo "Installation Terminée ==> reboot" && echo ""




