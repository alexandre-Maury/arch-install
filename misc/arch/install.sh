#!/bin/bash

# Source la configuration
source ./config.sh

# Vérification que le script est exécuté en tant que root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Choisir le disque à partitionner
echo "Disques disponibles :"
lsblk -d -o NAME,SIZE,MODEL | grep -v "NAME"

# Demander à l'utilisateur de choisir un disque
read -p "Entrez le nom du disque à partitionner (ex: /dev/sda, /dev/nvme0n1, etc.): " DISK

# Vérification que le disque existe
if [[ ! -b "$DISK" ]]; then
   echo "Erreur: Le disque $DISK n'existe pas."
   exit 1
fi

# Confirmation de l'effacement du disque
echo "Le disque $DISK sera entièrement effacé. Êtes-vous sûr ? (y/n)"
read -p "Confirmer : " confirm
if [[ "$confirm" != "y" ]]; then
    echo "Opération annulée."
    exit 1
fi

# Effacer toutes les partitions existantes
sgdisk --zap-all "$DISK"

# Fonction pour convertir les tailles avec unités (MiB, GiB) en secteurs
convert_to_sectors() {
    local size=$1
    local sectors
    if [[ "$size" =~ ([0-9]+)(MiB|GiB|Gi|MB|GB)$ ]]; then
        local value=${BASH_REMATCH[1]}
        local unit=${BASH_REMATCH[2]}
        
        case $unit in
            "MiB" | "MB")
                # 1 MiB = 2048 secteurs de 512 octets
                sectors=$((value * 2048))
                ;;
            "GiB" | "GB")
                # 1 GiB = 1048576 secteurs de 512 octets
                sectors=$((value * 1048576))
                ;;
            "Gi")
                # 1 Gi = 1048576 secteurs de 512 octets
                sectors=$((value * 1048576))
                ;;
            *)
                echo "Unité non supportée"
                exit 1
                ;;
        esac
    else
        echo "Format incorrect : $size"
        exit 1
    fi
    echo $sectors
}

# Calcul de l'espace restant après chaque partition
START=2048  # Début après le MBR ou la table GPT
TOTAL_SIZE=$(blockdev --getsize64 "$DISK")  # Taille totale du disque
REMAINING_SPACE=$TOTAL_SIZE  # Initialiser l'espace restant

# Créer toutes les partitions dans la boucle
for i in $(seq 1 $NUM_PARTITIONS); do
    # Déterminer la taille de la partition
    PART_SIZE="${PARTITION_SIZES[$i-1]}"

    if [[ "$PART_SIZE" == "100%" ]]; then
        # Si c'est 100%, on prendra tout l'espace restant
        END=$((REMAINING_SPACE / 512))  # Utiliser tout l'espace restant en secteurs de 512 octets
    else
        # Convertir la taille de la partition en secteurs
        PART_SIZE_SECTORS=$(convert_to_sectors "$PART_SIZE")
        END=$((START + PART_SIZE_SECTORS))
    fi

    # Créer la partition (type = 8300 pour Linux)
    sgdisk --new=$i:$START:$END --typecode=$i:8300 "$DISK"

    # Réduire l'espace restant
    START=$((END + 1))  # Déplacer le point de départ pour la partition suivante
    REMAINING_SPACE=$((REMAINING_SPACE - (END - START) * 512))  # Réduire l'espace restant

    # Si c'est la partition swap (repérée par la taille définie dans PARTITION_SIZES), alors créer la swap
    if [[ "$PART_SIZE" =~ ^[0-9]+MiB$ && "$i" == "${NUM_PARTITIONS}" ]]; then
        # C'est la dernière partition définie comme partition swap (ex : 4096MiB)
        echo "Création de la partition swap..."
        # Créer la partition swap (type = 8200 pour swap)
        sgdisk --new=$((NUM_PARTITIONS + 1)):$START:+${PARTITION_SIZES[$NUM_PARTITIONS]} --typecode=$((NUM_PARTITIONS + 1)):8200 "$DISK"
        mkswap "${DISK}p$((NUM_PARTITIONS + 1))"
        swapon "${DISK}p$((NUM_PARTITIONS + 1))"
        break
    fi
done





# Formatage des partitions
echo "Formatage de la partition /boot..."
mkfs.fat -F32 "${DISK}p1"  # La partition /boot

echo "Formatage des partitions restantes en Btrfs..."
mkfs.btrfs "${DISK}p2"  # Partition root

# Montage de la partition root
echo "Montage du système de fichiers..."
mount "${DISK}p2" /mnt

# Création des sous-volumes Btrfs
echo "Création des sous-volumes Btrfs..."
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home

# Montage des sous-volumes
umount /mnt
mount -o noatime,compress=lzo,subvol=@ "${DISK}p2" /mnt
mkdir /mnt/home
mount -o noatime,compress=lzo,subvol=@home "${DISK}p2" /mnt/home

# Montage de la partition /boot
mkdir /mnt/boot
mount "${DISK}p1" /mnt/boot

# Installation de Arch Linux
echo "Installation d'Arch Linux..."
pacstrap /mnt base linux linux-firmware

# Configuration du système
echo "Génération de l'fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot dans le nouveau système
echo "Chroot dans le système..."
arch-chroot /mnt /bin/bash <<EOF
# Configuration du système
echo "Configuration du système..."

# Mise à jour du miroir
pacman -Sy reflector
reflector --country 'France' --sort rate --save /etc/pacman.d/mirrorlist

# Installation du bootloader systemd-boot
bootctl --path=/mnt/boot install

# Configuration du noyau et initramfs
mkinitcpio -P

# Configuration de la locale
echo "en_US.UTF-8 UTF-8" > /mnt/etc/locale.gen
locale-gen

# Configuration de la timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /mnt/etc/localtime

# Création de l'utilisateur
useradd -m -G wheel -s /bin/bash user
echo "user:password" | chpasswd

# Activation du sudo
pacman -S sudo
echo "user ALL=(ALL) ALL" >> /mnt/etc/sudoers.d/user

# Fin de la configuration
EOF

# Sortie du chroot et démontage
echo "Démontage des partitions..."
umount -R /mnt

echo "Installation terminée. Vous pouvez redémarrer le système."
