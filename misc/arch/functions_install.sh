#!/bin/bash

# script functions_install.sh

install_system() {

    _base() {
        ##############################################################################
        ## Installation du système de base                                                
        ##############################################################################
        reflector --country ${PAYS} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
        pacstrap -K ${MOUNT_POINT} base base-devel linux linux-headers linux-firmware dkms

        ##############################################################################
        ## Generating the fstab                                                 
        ##############################################################################
        log_prompt "INFO" && echo "Génération du fstab" 
        genfstab -U -p ${MOUNT_POINT} >> ${MOUNT_POINT}/etc/fstab
        log_prompt "SUCCESS" && echo "OK" && echo ""

        ##############################################################################
        ## Configuration du system                                                    
        ##############################################################################
        nc=$(grep -c ^processor /proc/cpuinfo)  # Compte le nombre de cœurs de processeur
        log_prompt "INFO" && echo "Vous avez " $nc " coeurs." 
        log_prompt "INFO" && echo "Changement des makeflags pour " $nc " coeurs."

        TOTALMEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')  # Récupère la mémoire totale
        if [[  $TOTALMEM -gt 8000000 ]]; then  # Vérifie si la mémoire totale est supérieure à 8 Go
            log_prompt "INFO" && echo "Changement des paramètres de compression pour " $nc " coeurs."
            sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les makeflags dans makepkg.conf
            sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les paramètres de compression
            log_prompt "SUCCESS" && echo "OK" && echo ""
        fi

        ##############################################################################
        ## Définir le fuseau horaire + local                                                  
        ##############################################################################
        log_prompt "INFO" && echo "Configuration des locales"
        echo "KEYMAP=${KEYMAP}" > ${MOUNT_POINT}/etc/vconsole.conf
        sed -i "/^#$LOCALE/s/^#//g" ${MOUNT_POINT}/etc/locale.gen
        arch-chroot ${MOUNT_POINT} locale-gen
        log_prompt "SUCCESS" && echo "OK" && echo ""

        ##############################################################################
        ## Modification pacman.conf                                                  
        ##############################################################################
        log_prompt "INFO" && echo "Modification du fichier pacman.conf"
        sed -i 's/^#Para/Para/' ${MOUNT_POINT}/etc/pacman.conf
        sed -i "/\[multilib\]/,/Include/"'s/^#//' ${MOUNT_POINT}/etc/pacman.conf
        arch-chroot ${MOUNT_POINT} pacman -Sy --noconfirm
        log_prompt "SUCCESS" && echo "OK" && echo ""
    }


    _base_network() {
        ##############################################################################
        ## Configuration du réseau                                             
        ##############################################################################

        local INTERFACE="$(ip link show | awk -F': ' '/^[0-9]+: / && !/lo/ {print $2; exit}')"
        local MAC_ADDRESS=$(ip link | awk '/ether/ {print $2; exit}')
        local DNS_SERVERS="1.1.1.1 9.9.9.9"
        local FALLBACK_DNS="8.8.8.8"

        log_prompt "INFO" && echo "Génération du hostname" 
        echo "${HOSTNAME}" > ${MOUNT_POINT}/etc/hostname
        log_prompt "SUCCESS" && echo "OK" && echo ""

        log_prompt "INFO" && echo "Génération du Host" 
        echo "127.0.0.1 localhost" >> ${MOUNT_POINT}/etc/hosts
        echo "::1 localhost" >> ${MOUNT_POINT}/etc/hosts
        echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> ${MOUNT_POINT}/etc/hosts
        log_prompt "SUCCESS" && echo "OK" && echo ""

        # Créer le fichier 20-wired.network
        log_prompt "INFO" && echo "Configuration du fichier 20-wired.network dans ${MOUNT_POINT}/etc/systemd/network" && echo ""
        echo "[Match]" > "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "Name=${INTERFACE}" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "MACAddress=${MAC_ADDRESS}" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "[Network]" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "DHCP=yes" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "[DHCPv4]" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "RouteMetric=10" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        echo "UseDNS=false" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
        log_prompt "SUCCESS" && echo "OK" && echo ""

        # Configurer /etc/resolv.conf
        log_prompt "INFO" && echo "Configuration de /etc/resolv.conf pour utiliser systemd-resolved" && echo ""
        ln -sf /run/systemd/resolve/stub-resolv.conf "${MOUNT_POINT}/etc/resolv.conf"
        log_prompt "SUCCESS" && echo "OK" && echo ""

        # Configurer /etc/systemd/resolved.conf
        log_prompt "INFO" && echo "Écrire la configuration DNS dans /etc/systemd/resolved.conf" && echo ""
        echo "[Resolve]" > "${MOUNT_POINT}/etc/systemd/resolved.conf"
        echo "DNS=${DNS_SERVERS}" >> "${MOUNT_POINT}/etc/systemd/resolved.conf"
        echo "FallbackDNS=${FALLBACK_DNS}" >> "${MOUNT_POINT}/etc/systemd/resolved.conf"
        log_prompt "SUCCESS" && echo "OK" && echo ""

    }

    _base_chroot_paquages() {
        ##############################################################################
        ## Chroot install packages                                                
        ##############################################################################
        log_prompt "INFO" && echo "Installation des paquages de bases"
        arch-chroot ${MOUNT_POINT} pacman -Syu --noconfirm
        arch-chroot ${MOUNT_POINT} pacman -S man-db man-pages nano vim sudo pambase sshpass xdg-user-dirs git curl tar wget --noconfirm
        log_prompt "SUCCESS" && echo "OK" && echo ""

    }

    _base_chroot_cpu() {
        ##############################################################################
        ## Installation des pilotes CPU et GPU                                          
        ##############################################################################

        # Détection du type de processeur
        if lscpu | awk '{print $3}' | grep -E "GenuineIntel"; then
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel"
            arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
            proc_ucode="intel-ucode.img"
            log_prompt "SUCCESS" && echo "OK" && echo ""

        elif lscpu | awk '{print $3}' | grep -E "AuthenticAMD"; then
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD"
            arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
            proc_ucode="amd-ucode.img"
            log_prompt "SUCCESS" && echo "OK" && echo ""

        else
            log_prompt "WARNING" && echo "arch-chroot - Processeur non reconnu" && echo ""
            read -p "Quel microcode installer (Intel/AMD/ignorer) ? " proctype && echo ""
            
            case "$proctype" in
                Intel|intel)
                    log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel" 
                    arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
                    proc_ucode="intel-ucode.img"
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                AMD|amd)
                    log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD" 
                    arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
                    proc_ucode="amd-ucode.img"
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                ignore|Ignore)
                    log_prompt "WARNING" && echo "arch-chroot - L'utilisateur a choisi de ne pas installer de microcode" 
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                *)
                    log_prompt "ERROR" && echo "Option invalide. Aucun microcode installé." && echo ""
                    ;;
            esac
        fi
    }

    _base_chroot_gpu() {
        ##############################################################################
        ## Installation des pilotes CPU et GPU                                          
        ##############################################################################
        local GPU_VENDOR=$(lspci | grep -i "VGA\|3D" | awk '{print tolower($0)}')

        # Détection du type de processeur
        if lscpu | awk '{print $3}' | grep -E "GenuineIntel"; then
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel"
            arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
            proc_ucode="intel-ucode.img"
            log_prompt "SUCCESS" && echo "OK" && echo ""

        elif lscpu | awk '{print $3}' | grep -E "AuthenticAMD"; then
            log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD"
            arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
            proc_ucode="amd-ucode.img"
            log_prompt "SUCCESS" && echo "OK" && echo ""

        else
            log_prompt "WARNING" && echo "arch-chroot - Processeur non reconnu" && echo ""
            read -p "Quel microcode installer (Intel/AMD/ignorer) ? " proctype && echo ""
            
            case "$proctype" in
                Intel|intel)
                    log_prompt "INFO" && echo "arch-chroot - Installation du microcode Intel" 
                    arch-chroot "${MOUNT_POINT}" pacman -S intel-ucode --noconfirm
                    proc_ucode="intel-ucode.img"
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                AMD|amd)
                    log_prompt "INFO" && echo "arch-chroot - Installation du microcode AMD" 
                    arch-chroot "${MOUNT_POINT}" pacman -S amd-ucode --noconfirm
                    proc_ucode="amd-ucode.img"
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                ignore|Ignore)
                    log_prompt "WARNING" && echo "arch-chroot - L'utilisateur a choisi de ne pas installer de microcode" 
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    ;;
                *)
                    log_prompt "ERROR" && echo "Option invalide. Aucun microcode installé." && echo ""
                    ;;
            esac
        fi

        # Choix des modules et options en fonction du GPU
        if [[ "$GPU_VENDOR" == *"nvidia"* ]]; then
            log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU NVIDIA"
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
            log_prompt "SUCCESS" && echo "OK" && echo ""

        elif [[ "$GPU_VENDOR" == *"amd"* || "$GPU_VENDOR" == *"radeon"* ]]; then
            log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU AMD/Radeon"
            MODULES="amdgpu"
            KERNEL_OPTION="amdgpu.dc=1"
            arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-amdgpu xf86-video-ati mesa --noconfirm 
            modprobe $MODULES
            sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
            arch-chroot "${MOUNT_POINT}" mkinitcpio -P
            log_prompt "SUCCESS" && echo "OK" && echo ""

        elif [[ "$GPU_VENDOR" == *"intel"* ]]; then
            log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU Intel"
            MODULES="i915"
            KERNEL_OPTION="i915.enable_psr=1"
            arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-intel mesa --noconfirm 
            modprobe $MODULES
            sed -i "s/^MODULES=.*/MODULES=($MODULES)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
            arch-chroot "${MOUNT_POINT}" mkinitcpio -P
            log_prompt "SUCCESS" && echo "OK" && echo ""

        else
            log_prompt "WARNING" && echo "arch-chroot - Aucun GPU reconnu, installation des pilottes générique : xf86-video-vesa mesa"
            arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-vesa mesa --noconfirm
            log_prompt "SUCCESS" && echo "OK" && echo ""
        fi
    }


    _base_chroot_bootloader() {
        ##############################################################################
        ## arch-chroot Installation du bootloader (GRUB ou systemd-boot) en mode UEFI ou BIOS                                               
        ##############################################################################
        if [[ "${BOOTLOADER}" == "grub" ]]; then
            log_prompt "INFO" && echo "arch-chroot - Installation de GRUB" 
            arch-chroot ${MOUNT_POINT} pacman -S grub os-prober --noconfirm
            if [[ "$MODE" == "UEFI" ]]; then
                arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
                arch-chroot ${MOUNT_POINT} grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

            elif [[ "$MODE" == "BIOS" ]]; then
                arch-chroot ${MOUNT_POINT} grub-install --target=i386-pc --no-floppy /dev/"${DISK}"
            else
                log_prompt "ERROR" && echo "Une erreur est survenue : $MODE non reconnu." && exit 1
            fi
            log_prompt "SUCCESS" && echo "OK" && echo ""

            log_prompt "INFO" && echo "arch-chroot - configuration de grub"
            if [[ -n "${KERNEL_OPTION}" ]]; then
                sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/&$KERNEL_OPTION /" /etc/default/grub
            fi
            arch-chroot ${MOUNT_POINT} grub-mkconfig -o /boot/grub/grub.cfg
            if [[ -n "${proc_ucode}" ]]; then
                echo "initrd /boot/$proc_ucode" >> ${MOUNT_POINT}/boot/grub/grub.cfg
            fi
            log_prompt "SUCCESS" && echo "OK" && echo ""

        elif [[ "${BOOTLOADER}" == "systemd-boot" ]]; then
            if [[ "$MODE" == "UEFI" ]]; then
                log_prompt "INFO" && echo "arch-chroot - Installation de systemd-boot"
                arch-chroot ${MOUNT_POINT} pacman -S efibootmgr os-prober --noconfirm 
                arch-chroot ${MOUNT_POINT} bootctl --path=/boot install
                log_prompt "SUCCESS" && echo "OK" && echo ""

                log_prompt "INFO" && echo "arch-chroot - Configuration de systemd-boot : arch.conf"
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
                log_prompt "SUCCESS" && echo "OK" && echo ""

                log_prompt "INFO" && echo "arch-chroot - Configuration de systemd-boot : loader.conf"
                echo "default arch.conf" >> ${MOUNT_POINT}/boot/loader/loader.conf
                echo "timeout 4" >> ${MOUNT_POINT}/boot/loader/loader.conf
                echo "console-mode max" >> ${MOUNT_POINT}/boot/loader/loader.conf
                echo "editor no" >> ${MOUNT_POINT}/boot/loader/loader.conf
                log_prompt "SUCCESS" && echo "OK" && echo ""
            else
                log_prompt "ERROR" && echo "systemd-boot ne peut être utilisé qu'en mode UEFI." && exit 1
            fi

        else
            
            log_prompt "ERROR" && echo "Bootloader non reconnu" && exit 1
        fi

        ##############################################################################
        ## arch-chroot Création d'un nouvel initramfs                                             
        ##############################################################################
        log_prompt "INFO" && echo "arch-chroot - mkinitcpio"
        arch-chroot ${MOUNT_POINT} mkinitcpio -p linux
        log_prompt "SUCCESS" && echo "OK" && echo ""
    }


    _base_chroot_pam() {
        ##############################################################################
        ## Configuration de PAM                                  
        ##############################################################################

        local PASSWDQC_CONF="/etc/security/passwdqc.conf"
        local MIN_SIMPLE="4"                                # Valeurs : disabled : Longueur minimale pour un mot de passe simple, c'est-à-dire uniquement des lettres minuscules (ex. : "abcdef").
        local MIN_2CLASSES="4"                              # Longueur minimale pour un mot de passe avec deux classes de caractères, par exemple minuscules + majuscules ou minuscules + chiffres (ex. : "Abcdef" ou "abc123").
        local MIN_3CLASSES="4"                              # Longueur minimale pour un mot de passe avec trois classes de caractères, comme minuscules + majuscules + chiffres (ex. : "Abc123").
        local MIN_4CLASSES="4"                              # Longueur minimale pour un mot de passe avec quatre classes de caractères, incluant minuscules + majuscules + chiffres + caractères spéciaux (ex. : "Abc123!").
        local MIN_PHRASE="4"                                # Longueur minimale pour une phrase de passe, qui est généralement une suite de plusieurs mots ou une longue chaîne de caractères (ex. : "monmotdepassecompliqué").
        local MIN="$MIN_SIMPLE,$MIN_2CLASSES,$MIN_3CLASSES,$MIN_4CLASSES,$MIN_PHRASE"
        local MAX="72"                                      # Définit la longueur maximale autorisée pour un mot de passe. Dans cet exemple, un mot de passe ne peut pas dépasser 72 caractères.
        local PASSPHRASE="3" # Définit la longueur minimale pour une phrase de passe en termes de nombre de mots. Ici, une phrase de passe doit comporter au moins 3 mots distincts pour être considérée comme valide.
        local MATCH="4" # Ce paramètre détermine la longueur minimale des segments de texte qui doivent correspondre entre deux chaînes pour être considérées comme similaires.
        local SIMILAR="permit" # Valeurs : permit ou deny : Définit la politique en matière de similitude entre le mot de passe et d'autres informations (par exemple, le nom de l'utilisateur).
        local RANDOM="47"
        local ENFORCE="everyone" #  Valeurs : none ou users ou everyone : Ce paramètre applique les règles de complexité définies à tous les utilisateurs.
        local RETRY="3" # Ce paramètre permet à l'utilisateur de réessayer jusqu'à 3 fois pour entrer un mot de passe conforme si le mot de passe initial proposé est refusé.
            
        log_prompt "INFO" && echo "Configuration de passwdqc.conf" && echo ""
        # Sauvegarde de l'ancien fichier passwdqc.conf
        if [ -f "${MOUNT_POINT}$PASSWDQC_CONF" ]; then
            cp "${MOUNT_POINT}$PASSWDQC_CONF" "${MOUNT_POINT}$PASSWDQC_CONF.bak"
        fi

        log_prompt "INFO" && echo "Création ou modification du fichier passwdqc.conf dans ${MOUNT_POINT}${PASSWDQC_CONF}" && echo ""
        echo "min=$MIN" > "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "max=$MAX" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "passphrase=$PASSPHRASE" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "match=$MATCH" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "similar=$SIMILAR" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "enforce=$ENFORCE" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        echo "retry=$RETRY" >> "${MOUNT_POINT}${PASSWDQC_CONF}"
        log_prompt "SUCCESS" && echo "Fichier passwdqc.conf créé ou modifié avec succès !" && echo ""
        
    }



    _base_chroot_root() {
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
            # Demande de changer le mot de passe root
            while true; do
                read -p "Veuillez entrer le nouveau mot de passe pour root : " -s NEW_PASS && echo ""
                read -p "Confirmez le mot de passe : " -s CONFIRM_PASS && echo ""

                # Vérifie si les mots de passe correspondent
                if [[ "$NEW_PASS" == "$CONFIRM_PASS" ]]; then
                    log_prompt "INFO" && echo "arch-chroot - Configuration du compte root"
                    echo -e "$NEW_PASS\n$NEW_PASS" | arch-chroot ${MOUNT_POINT} passwd "root"
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    break
                else
                    log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
                fi
            done

        # Si l'utilisateur répond N ou n
        else
            log_prompt "WARNING" && echo "Attention, le mot de passe root d'origine est conservé." && echo ""
        fi
    }

    _base_chroot_user() {
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
                read -p "Veuillez entrer le nouveau mot de passe pour $sudo_user : " -s NEW_PASS  && echo ""
                read -p "Confirmez le mot de passe : " -s CONFIRM_PASS  && echo ""

                # Vérifie si les mots de passe correspondent
                if [[ "$NEW_PASS" == "$CONFIRM_PASS" ]]; then
                    log_prompt "INFO" && echo "arch-chroot - Configuration du compte $sudo_user"
                    echo -e "$NEW_PASS\n$NEW_PASS" | arch-chroot ${MOUNT_POINT} passwd $sudo_user
                    log_prompt "SUCCESS" && echo "OK" && echo ""
                    break
                else
                    log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
                fi
            done
        fi
    }

    _base_chroot_ssh() {
        ##############################################################################
        ## Modifier le fichier de configuration pour renforcer la sécurité                                     
        ##############################################################################

        local SSH_PORT=2222  # Remplacez 2222 par le port que vous souhaitez utiliser
        local SSH_CONFIG_FILE="/etc/ssh/sshd_config"

        log_prompt "INFO" && echo "arch-chroot - Configuration du SSH"
        sed -i "s/#Port 22/Port $SSH_PORT/" "${MOUNT_POINT}$SSH_CONFIG_FILE"
        sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
        sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
        sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' "${MOUNT_POINT}$SSH_CONFIG_FILE"
        log_prompt "SUCCESS" && echo "OK" && echo ""
    }

    _base_activate_service() {
        log_prompt "INFO" && echo "arch-chroot - Activation des services"
        arch-chroot ${MOUNT_POINT} systemctl enable sshd
        arch-chroot ${MOUNT_POINT} systemctl enable systemd-homed
        arch-chroot ${MOUNT_POINT} systemctl enable systemd-networkd 
        arch-chroot ${MOUNT_POINT} systemctl enable systemd-resolved 
        log_prompt "SUCCESS" && echo "OK" && echo ""
    }

    _base
    _base_network
    _base_chroot_paquages
    _base_chroot_cpu
    _base_chroot_gpu
    _base_chroot_bootloader
    _base_chroot_pam
    _base_chroot_root
    _base_chroot_user
    _base_chroot_ssh
    _base_activate_service

}


