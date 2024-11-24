#!/bin/bash

# Définir le disque où les partitions sont présentes (changer en fonction du disque)
PARTITION_TABLE="/dev/sda"

# Trouver toutes les partitions NTFS
NTFS_PARTITIONS=$(lsblk -f | grep 'ntfs' | awk '{print $1}')

# Initialiser une variable pour stocker la partition Windows
WINDOWS_PARTITION=""

# Chercher une partition Windows spécifique parmi les partitions NTFS
for PARTITION in $NTFS_PARTITIONS; do
    # Vérifier le label de la partition
    LABEL=$(lsblk -o NAME,LABEL | grep "$PARTITION" | awk '{print $2}')
    
    # Si le label est "Windows" ou "OS", c'est la partition Windows principale
    if [[ "$LABEL" == "Windows" || "$LABEL" == "OS" ]]; then
        WINDOWS_PARTITION="/dev/$PARTITION"
        break
    fi
    
    # Optionnel: Vérifier si la taille de la partition est suffisamment grande pour être la partition Windows
    PARTITION_SIZE=$(lsblk -o NAME,SIZE | grep "$PARTITION" | awk '{print $2}')
    if [[ "$PARTITION_SIZE" =~ [0-9]+G && ${BASH_REMATCH[0]} -gt 20 ]]; then
        WINDOWS_PARTITION="/dev/$PARTITION"
        break
    fi
done

# Vérifier si la partition Windows a été trouvée
if [ -z "$WINDOWS_PARTITION" ]; then
    echo "Aucune partition Windows trouvée."
    exit 1
fi

echo "Partition Windows trouvée : $WINDOWS_PARTITION"

# Définir la taille à libérer pour Arch Linux (en Mo)
SPACE_TO_FREE=50000  # 50 Go (par exemple)

# Étape 1: Vérifier que la partition Windows est montée
echo "Vérification de la partition Windows..."
if mount | grep -q "$WINDOWS_PARTITION"; then
    echo "La partition $WINDOWS_PARTITION est montée. La démontée maintenant..."
    umount $WINDOWS_PARTITION
else
    echo "La partition $WINDOWS_PARTITION n'est pas montée."
fi

# Étape 2: Redimensionner la partition Windows
echo "Redimensionnement de la partition Windows pour libérer de l'espace..."
ntfsresize --size -${SPACE_TO_FREE}M "$WINDOWS_PARTITION"
if [ $? -ne 0 ]; then
    echo "Erreur lors du redimensionnement de la partition Windows. Abandon."
    exit 1
fi
echo "Partition Windows redimensionnée avec succès."

# Étape 3: Vérifier et actualiser la table de partitions avec parted
echo "Actualisation de la table de partitions..."

# Lancer parted pour actualiser la table de partitions
parted $PARTITION_TABLE -- mkpart primary ext4 $(ntfsresize -i "$WINDOWS_PARTITION" | grep 'Free Space' | awk '{print $3}') $(($(ntfsresize -i "$WINDOWS_PARTITION" | grep 'Free Space' | awk '{print $3}') + $SPACE_TO_FREE))

if [ $? -ne 0 ]; then
    echo "Erreur lors de la création de la nouvelle partition."
    exit 1
fi
echo "Nouvelle partition créée dans l'espace non alloué."

# Étape 4: Vérifier que la nouvelle partition est correctement formatée
echo "Création du système de fichiers pour la nouvelle partition..."
NEW_PARTITION=$(lsblk -o NAME,SIZE,TYPE | grep 'part' | awk 'NR==2 {print $1}')
mkfs.ext4 /dev/$NEW_PARTITION

if [ $? -ne 0 ]; then
    echo "Erreur lors de la création du système de fichiers."
    exit 1
fi
echo "Système de fichiers ext4 créé sur la nouvelle partition."

# Étape 5: Créer un point de montage pour Arch Linux et monter la nouvelle partition
echo "Montage de la nouvelle partition..."
mount /dev/$NEW_PARTITION /mnt

echo "Redimensionnement de la partition Windows terminé avec succès et Arch Linux prêt à être installé."

exit 0
