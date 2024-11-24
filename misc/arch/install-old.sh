#!/bin/bash

# # Créer un snapshot de @root et le stocker dans @snapshots
# btrfs subvolume snapshot /mnt/@root /mnt/snapshots/root_snapshot_$(date +%F)

# # Vérifier les sous-volumes et snapshots
# btrfs subvolume list /mnt

# # Créer un snapshot de @home et le stocker dans @snapshots
# btrfs subvolume snapshot /mnt/home /mnt/snapshots/home_snapshot_$(date +%F)

# Gérer les snapshots (rollback, suppression, etc.)

# # Rollback (restaurer un snapshot) : Si tu veux revenir à un état antérieur de @root ou @home, tu peux supprimer le sous-volume actuel et restaurer le snapshot à partir de @snapshots.

# # Supprimer le sous-volume actuel
# btrfs subvolume delete /mnt/@root

# # Restaurer le snapshot à partir de @snapshots
# btrfs subvolume snapshot /mnt/snapshots/root_snapshot_2024-11-24 /mnt/@root

# Variables de partitionnement
EFI_PART="/dev/sda1"
SWAP_PART="/dev/sda2"
ROOT_PART="/dev/sda3"
HOME_PART="/dev/sda4"

# Nom de l'utilisateur pour Arch Linux (ajustez selon votre cas)
USERNAME="archuser"
HOSTNAME="archlinux"

# Monter la partition EFI
echo "Montage de la partition EFI..."
mount $EFI_PART /mnt/boot

# Créer la partition /root en Btrfs et monter
echo "Création du système de fichiers Btrfs sur /dev/sda3..."
mkfs.btrfs $ROOT_PART
mount $ROOT_PART /mnt

# Créer les sous-volumes pour root, home, et les snapshots
echo "Création des sous-volumes Btrfs..."
btrfs subvolume create /mnt/@root
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

# Démonter la partition root
umount /mnt

# Monter les sous-volumes
echo "Montage des sous-volumes..."
mount -o subvol=@root $ROOT_PART /mnt
mkdir /mnt/home
mount -o subvol=@home $ROOT_PART /mnt/home
mkdir /mnt/snapshots
mount -o subvol=@snapshots $ROOT_PART /mnt/snapshots

# Formatage de la partition swap et activation
echo "Formatage et activation de la partition swap..."
mkswap $SWAP_PART
swapon $SWAP_PART

# Installer le système de base
echo "Installation du système Arch Linux..."
pacstrap /mnt base base-devel linux linux-firmware btrfs-progs vim sudo git

# Générer le fstab
echo "Génération du fichier fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot dans le système
echo "Chroot dans le système..."
arch-chroot /mnt /bin/bash <<EOF

# Configuration de la timezone
echo "Configuration de la timezone..."
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Configuration des locales
echo "Configuration des locales..."
sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Configuration du hostname
echo "Configuration du hostname..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain   $HOSTNAME" >> /etc/hosts

# Configuration du mot de passe root
echo "Configuration du mot de passe root..."
passwd

# Créer un utilisateur
echo "Création de l'utilisateur $USERNAME..."
useradd -m -G wheel -s /bin/bash $USERNAME
passwd $USERNAME
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

# Installer et configurer systemd-boot
echo "Installation de systemd-boot..."
bootctl --path=/boot install

# Configuration de systemd-boot
echo "Configuration de systemd-boot..."
mkdir -p /boot/loader/entries
echo "default arch.conf" > /boot/loader/loader.conf
echo "timeout 4" >> /boot/loader/loader.conf

# Créer le fichier de configuration pour Arch Linux
cat > /boot/loader/entries/arch.conf <<EOF2
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value $ROOT_PART) rw
EOF2

# Ajouter l'entrée pour Windows
echo "Ajout de l'entrée Windows à systemd-boot..."
cat > /boot/loader/entries/windows.conf <<EOF2
title   Windows
efi     /EFI/Microsoft/Boot/bootmgfw.efi
EOF2

# Sortie du chroot
exit
EOF

# Démonter et redémarrer
echo "Démontage et redémarrage..."
umount -R /mnt
reboot
