#!/usr/bin/env bash

# script chroot.sh

set -e  # Quitte immédiatement en cas d'erreur.

source functions.sh
source config.sh  

##############################################################################
## Arguments                                                     
##############################################################################
# MODE="${1}"
DISK="${1}"

chmod +x *.sh # Rendre les scripts exécutables.



##############################################################################
## Définir le fuseau horaire                                                  
##############################################################################
log_prompt "INFO" && echo "Configuration du fuseau horaire" && echo ""
ln -sf /usr/share/zoneinfo/${REGION}/${CITY} /etc/localtime
hwclock --systohc
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Configuration de la langue + clavier                                                    
##############################################################################
log_prompt "INFO" && echo "Configuration des langues" && echo ""
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "LANG=${LOCALE}" >> /etc/locale.gen
locale-gen
echo "LANG=$LANG" > /etc/locale.conf
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Configuration du réseau                                             
##############################################################################
log_prompt "INFO" && echo "Génération du hostname" && echo ""
echo "${HOSTNAME}" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1 localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Generating the fstab                                                 
##############################################################################
log_prompt "INFO" && echo "Génération du fstab" && echo ""
genfstab -U / >> /etc/fstab
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installing grub and creating configuration                                               
##############################################################################
log_prompt "INFO" && echo "Installation et configuration de grub" && echo ""

if [[ "$MODE" == "UEFI" ]]; then
    echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
    emerge --quiet sys-boot/grub
    grub-install --target=x86_64-efi --efi-directory=/efi
	grub-mkconfig -o /boot/grub/grub.cfg

elif [[ "$MODE" == "BIOS" ]]; then
    echo 'GRUB_PLATFORMS="pc"' >> /etc/portage/make.conf
    emerge --quiet sys-boot/grub
	grub-install /dev/"${DISK}"
	grub-mkconfig -o /boot/grub/grub.cfg

else
	log_prompt "ERROR" && echo "Une erreur est survenue $MODE non reconnu"
	exit 1
fi

GRUB_CONFIG="/etc/default/grub"
sed -i 's/^#\?GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="init=\/lib\/systemd\/systemd"/' "$GRUB_CONFIG"

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Générer la configuration de GRUB                                           
##############################################################################
# Vérifier si le fichier grub.cfg existe
if [ -f /boot/grub/grub.cfg ]; then
    log_prompt "SUCCESS" && echo "La configuration de GRUB est déjà présente." && echo ""
else
    log_prompt "INFO" && echo "La configuration de GRUB est absente. Régénération..." && echo ""
    grub-mkconfig -o /boot/grub/grub.cfg

    if [ $? -eq 0 ]; then
        log_prompt "SUCCESS" && echo "Terminée" && echo ""
    else
        log_prompt "ERROR" && echo "Problème lors de la configuration de Grub"
        exit 1
    fi
fi


##############################################################################
## Enable networking                                                
##############################################################################
log_prompt "INFO" && echo "Activation du réseau" && echo ""
echo '[Match]' >> /etc/systemd/network/50-dhcp.network
echo "Name=${INTERFACE}" >> /etc/systemd/network/50-dhcp.network
echo '[Network]' >> /etc/systemd/network/50-dhcp.network
echo 'DHCP=yes' >> /etc/systemd/network/50-dhcp.network
systemctl enable systemd-networkd.service
systemctl enable systemd-resolved.service
log_prompt "SUCCESS" && echo "Terminée"


##############################################################################
## Install packages                                                
##############################################################################


##############################################################################
## Configuration de PAM                                  
##############################################################################
log_prompt "INFO" && echo "Configuration de passwdqc.conf" && echo ""

# Sauvegarde de l'ancien fichier passwdqc.conf
if [ -f "$PASSWDQC_CONF" ]; then
    cp "$PASSWDQC_CONF" "$PASSWDQC_CONF.bak"
    log_prompt "INFO" && echo "Sauvegarde du fichier existant passwdqc.conf en $PASSWDQC_CONF.bak" && echo ""
fi

# Génération du nouveau contenu de passwdqc.conf
cat <<EOF > "$PASSWDQC_CONF"
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
## Set root and password                                               
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
    log_prompt "INFO" && echo "Configuration du compte root" && echo ""
    
    # Demande de changer le mot de passe root, boucle jusqu'à réussite
    while ! passwd ; do
        sleep 1
    done
    
    log_prompt "SUCCESS" && echo "Mot de passe root configuré avec succès."
    
# Si l'utilisateur répond N ou n
else
    log_prompt "WARNING" && echo "Attention, le mot de passe root d'origine est conservé." && echo ""
fi

##############################################################################
## Set user and password                                               
##############################################################################

# Demande tant que la réponse n'est pas y/Y ou n/N
while true; do
    log_prompt "INFO" && read -p "Souhaitez-vous créer un compte utilisateur (Y/n) : " PASSUSER && echo ""
    
    # Vérifie la validité de l'entrée
    if [[ "$PASSUSER" =~ ^[yYnN]$ ]]; then
        break
    else
        log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)."
        echo ""
    fi
done

# Si l'utilisateur répond Y ou y
if [[ "$PASSUSER" =~ ^[yY]$ ]]; then
    log_prompt "INFO" && read -p "Saisir le nom d'utilisateur souhaité :" USERNAME 
    echo ""

    log_prompt "INFO" && echo "Ajout de l'utilisateur aux groupes users, audio, video et wheel" && echo ""
    useradd -m -G wheel,users,audio,video -s /bin/bash "${USERNAME}"

    log_prompt "INFO" && echo "Ajout du groupe wheel aux sudoers" && echo ""
    echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

    log_prompt "INFO" && echo "Configuration du mot de passe pour l'utilisateur" && echo ""
    while ! passwd "${USERNAME}"; do
        sleep 1
    done

    # Appliquer immédiatement l'ajout au groupe sans déconnexion
    log_prompt "INFO" && echo "Appliquer les groupes sans déconnexion" && echo ""
    usermod -aG wheel "${USERNAME}"
    newgrp wheel

    log_prompt "SUCCESS" && echo "Terminée" && echo ""
    
# Si l'utilisateur répond N ou n
else
    log_prompt "WARNING" && echo "Attention, pas d'utilisateur de créer." && echo ""
fi



##############################################################################
## quit                                               
##############################################################################
exit




