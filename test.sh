#!/usr/bin/env bash

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.

log_prompt "INFO" && echo "Vous avez choisi $BOOTLOADER comme bootloader" && echo ""

if [[ "${BOOTLOADER}" == "grub" ]]; then
    log_prompt "INFO" && echo "arch-chroot - Installation de GRUB" && echo ""
    arch-chroot ${MOUNT_POINT} pacman -S grub os-prober --noconfirm

    if [[ "$MODE" == "UEFI" ]]; then
        arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
        arch-chroot ${MOUNT_POINT} grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
    elif [[ "$MODE" == "BIOS" ]]; then
        arch-chroot ${MOUNT_POINT} grub-install --target=i386-pc --no-floppy /dev/"${DISK}"
    else
        log_prompt "ERROR" && echo "Une erreur est survenue : $MODE non reconnu." && exit 1
    fi

    log_prompt "INFO" && echo "arch-chroot - configuration de grub" && echo ""

cat <<EOF | arch-chroot "$MOUNT_POINT" bash
if [[ -n "$proc_ucode" ]]; then
    echo "initrd /boot/$proc_ucode" >> /boot/grub/grub.cfg
fi
EOF

arch-chroot ${MOUNT_POINT} grub-mkconfig -o /boot/grub/grub.cfg

elif [[ "${BOOTLOADER}" == "systemd-boot" ]]; then
    if [[ "$MODE" == "UEFI" ]]; then
        log_prompt "INFO" && echo "arch-chroot - Installation de systemd-boot" && echo ""
        arch-chroot ${MOUNT_POINT} bootctl install

        # Création de l'entrée de démarrage pour Arch Linux
        cat <<EOF | arch-chroot ${MOUNT_POINT} tee /boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux
initrd  /${proc_ucode}
initrd  /initramfs-linux.img
options root=PARTUUID=$(blkid -s PARTUUID -o value /dev/"${DISK}${PART_ROOT}") rw
EOF

        # Configuration de systemd-boot
        cat <<EOF | arch-chroot ${MOUNT_POINT} tee /boot/loader/loader.conf
default arch
timeout 3
EOF
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
    log_prompt "INFO" && echo "Fichier passwdqc.conf mis à jour avec succès." && echo ""
    cat "$PASSWDQC_CONF"
    log_prompt "SUCCESS" && echo "Terminée" && echo ""

else
    log_prompt "ERROR" && echo "Erreur lors de la mise à jour du fichier passwdqc.conf." && echo ""
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

    log_prompt "INFO" && read -p "Saisir le nom d'utilisateur souhaité :" sudo_user && echo ""
    arch-chroot ${MOUNT_POINT} useradd -m -G wheel,audio,video,optical,storage,power "$sudo_user"

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
## Fin du script                                          
##############################################################################
log_prompt "SUCCESS" && echo "Installation Terminée ==> shutdown -h" && echo ""