#!/bin/bash

# script functions_install.sh

install_base() {

    local disk="$1"
    local interface="$(ip link show | awk -F': ' '/^[0-9]+: / && !/lo/ {print $2; exit}')"
    local mac_address=$(ip link | awk '/ether/ {print $2; exit}')
    local nc=$(grep -c ^processor /proc/cpuinfo)  # Compte le nombre de cœurs de processeur
    local total_mem=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')  # Récupère la mémoire totale
                                      
    clear
    log_prompt "INFO" && echo "Installation du système de base"
    reflector --country ${PAYS} --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    pacstrap -K ${MOUNT_POINT} base base-devel linux linux-headers linux-firmware dkms

    log_prompt "SUCCESS" && echo "OK" && echo ""

    ## Generating the fstab                                                 
    log_prompt "INFO" && echo "Génération du fstab" 
    genfstab -U -p ${MOUNT_POINT} >> ${MOUNT_POINT}/etc/fstab
    log_prompt "SUCCESS" && echo "OK" && echo ""

    ## Configuration du system                                                    
    log_prompt "INFO" && echo "Changement des makeflags pour " $nc " coeurs."

    
    if [[  $total_mem -gt 8000000 ]]; then  # Vérifie si la mémoire totale est supérieure à 8 Go
        log_prompt "INFO" && echo "Changement des paramètres de compression pour " $nc " coeurs."
        sed -i "s/#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$nc\"/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les makeflags dans makepkg.conf
        sed -i "s/COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -T $nc -z -)/g" ${MOUNT_POINT}/etc/makepkg.conf  # Modifie les paramètres de compression
        log_prompt "SUCCESS" && echo "OK" && echo ""
    fi

    ## Définir le fuseau horaire + local                                                  
    log_prompt "INFO" && echo "Configuration des locales"
    echo "KEYMAP=${KEYMAP}" > ${MOUNT_POINT}/etc/vconsole.conf
    sed -i "/^#$LOCALE/s/^#//g" ${MOUNT_POINT}/etc/locale.gen
    arch-chroot ${MOUNT_POINT} locale-gen
    log_prompt "SUCCESS" && echo "OK" && echo ""

    ## Modification pacman.conf                                                  
    log_prompt "INFO" && echo "Modification du fichier pacman.conf"
    sed -i 's/^#Para/Para/' ${MOUNT_POINT}/etc/pacman.conf
    sed -i "/\[multilib\]/,/Include/"'s/^#//' ${MOUNT_POINT}/etc/pacman.conf
    arch-chroot ${MOUNT_POINT} pacman -Sy --noconfirm
    log_prompt "SUCCESS" && echo "OK" && echo ""

    ## Configuration du réseau                                             
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
    echo "Name=${interface}" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
    echo "MACAddress=${mac_address}" >> "${MOUNT_POINT}/etc/systemd/network/20-wired.network"
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
    echo "DNS=1.1.1.1 9.9.9.9" >> "${MOUNT_POINT}/etc/systemd/resolved.conf"
    echo "FallbackDNS=8.8.8.8" >> "${MOUNT_POINT}/etc/systemd/resolved.conf"
    log_prompt "SUCCESS" && echo "OK" && echo ""
}

install_base_chroot() {
    
    local disk="$1"
    local gpu_vendor=$(lspci | grep -i "VGA\|3D" | awk '{print tolower($0)}')
    local root_part=$(lsblk -n -o NAME,LABEL | grep "root" | awk '{print $1}' | sed "s/.*\(${disk}[0-9]*\)/\1/")
    local root_fs=$(blkid -s TYPE -o value /dev/${root_part})
    local cpu_vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')

    local proc_ucode
    local modules
    local kernel_option

    ## Chroot install packages                                                
    log_prompt "INFO" && echo "Installation des paquages de bases"
    arch-chroot ${MOUNT_POINT} pacman -Syu --noconfirm
    arch-chroot ${MOUNT_POINT} pacman -S man-db man-pages nano vim sudo pambase sshpass xdg-user-dirs git curl tar wget --noconfirm
    log_prompt "SUCCESS" && echo "OK" && echo ""

    # Détection du type de processeur
    case "$cpu_vendor" in
        "GenuineIntel")
            proc_ucode="intel-ucode.img"
            arch-chroot ${MOUNT_POINT} pacman -S intel-ucode --noconfirm
            ;;
        "AuthenticAMD")
            proc_ucode="amd-ucode.img"
            arch-chroot ${MOUNT_POINT} pacman -S amd-ucode --noconfirm
            ;;
        *)
            log_prompt "ERROR" && echo "Vendor CPU non reconnu: $cpu_vendor"
            proc_ucode=""
            ;;
    esac


    ## Installation des pilotes GPU                                          
    if [[ "$gpu_vendor" == *"nvidia"* ]]; then
        log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU NVIDIA"
        modules="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
        kernel_option="nvidia_drm.modeset=1"
        arch-chroot "${MOUNT_POINT}" pacman -S nvidia mesa --noconfirm
        # xf86-video-nouveau
        modprobe $modules
        sed -i "s/^MODULES=.*/MODULES=($modules)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
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
        # arch-chroot "${MOUNT_POINT}" mkinitcpio -P
        log_prompt "SUCCESS" && echo "OK" && echo ""

    elif [[ "$gpu_vendor" == *"amd"* || "$gpu_vendor" == *"radeon"* ]]; then
        log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU AMD/Radeon"
        modules="amdgpu"
        kernel_option="amdgpu.dc=1"
        arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-amdgpu xf86-video-ati mesa --noconfirm 
        modprobe $modules
        sed -i "s/^MODULES=.*/MODULES=($modules)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
        # arch-chroot "${MOUNT_POINT}" mkinitcpio -P
        log_prompt "SUCCESS" && echo "OK" && echo ""

    elif [[ "$gpu_vendor" == *"intel"* ]]; then
        log_prompt "INFO" && echo "arch-chroot - Configuration pour GPU Intel"
        modules="i915"
        kernel_option="i915.enable_psr=1"
        arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-intel mesa --noconfirm 
        modprobe $modules
        sed -i "s/^MODULES=.*/MODULES=($modules)/" ${MOUNT_POINT}/etc/mkinitcpio.conf
        # arch-chroot "${MOUNT_POINT}" mkinitcpio -P
        log_prompt "SUCCESS" && echo "OK" && echo ""

    else
        log_prompt "WARNING" && echo "arch-chroot - Aucun GPU reconnu, installation des pilottes générique : xf86-video-vesa mesa"
        arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-vesa mesa --noconfirm
        log_prompt "SUCCESS" && echo "OK" && echo ""
    fi

    while true; do
        if [[ "${BOOTLOADER}" == "grub" ]]; then
            log_prompt "INFO" && echo "arch-chroot - Installation de GRUB" 
            arch-chroot ${MOUNT_POINT} pacman -S grub os-prober --noconfirm

            if [[ "$MODE" == "UEFI" ]]; then
                arch-chroot ${MOUNT_POINT} pacman -S efibootmgr --noconfirm 
                arch-chroot ${MOUNT_POINT} grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
                log_prompt "SUCCESS" && echo "OK" && echo ""

            elif [[ "$MODE" == "LEGACY" ]]; then
                arch-chroot ${MOUNT_POINT} grub-install --target=i386-pc --no-floppy /dev/"${disk}"
                log_prompt "SUCCESS" && echo "OK" && echo ""

            else
                log_prompt "ERROR" && echo "Une erreur est survenue : $MODE non reconnu." && exit 1
            fi
            
            log_prompt "INFO" && echo "arch-chroot - configuration de grub"
            if [[ -n "${kernel_option}" ]]; then
                sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/&$kernel_option /" /etc/default/grub
            fi

            arch-chroot ${MOUNT_POINT} grub-mkconfig -o /boot/grub/grub.cfg
            
            if [[ -n "${proc_ucode}" ]]; then
                echo "initrd /boot/$proc_ucode" >> ${MOUNT_POINT}/boot/grub/grub.cfg
            fi
            log_prompt "SUCCESS" && echo "OK" && echo ""

            break  # Sort de la boucle après une installation réussie

        elif [[ "${BOOTLOADER}" == "systemd-boot" && "$MODE" == "UEFI" ]]; then

            # Préparer les options
            case "$root_fs" in
                "ext4")
                    root_options="root=/dev/${root_part} rw"
                    ;;
                "btrfs")
                    root_uuid=$(blkid -s UUID -o value /dev/${root_part})
                    root_options="root=UUID=${root_uuid} rootflags=subvol=@ rw"
                    ;;
                *)
                    log_prompt "ERROR" && echo "Système de fichiers non pris en charge : ${root_fs}" && exit 1
                    ;;
            esac

            log_prompt "INFO" && echo "arch-chroot - Installation de systemd-boot"
            arch-chroot ${MOUNT_POINT} pacman -S efibootmgr os-prober --noconfirm 
            arch-chroot ${MOUNT_POINT} bootctl --path=/boot install

            {
                echo "title   Arch Linux"
                echo "linux   /vmlinuz-linux"
                echo "initrd  /${proc_ucode}"
                echo "initrd  /initramfs-linux.img"

                if [[ -n "${kernel_option}" ]]; then
                    echo "options ${root_options} $kernel_option"
                else
                    echo "options ${root_options}"
                fi
            } > ${MOUNT_POINT}/boot/loader/entries/arch.conf

            {
                echo "default arch.conf"
                echo "timeout 4"
                echo "console-mode max"
                echo "editor no"

            } > ${MOUNT_POINT}/boot/loader/loader.conf


            break  # Sort de la boucle après une installation réussie

        else
            log_prompt "ERROR" && echo "Bootloader ${BOOTLOADER} non reconnu."
            log_prompt "INFO" && read -p "Veuillez saisir un bootloader valide (grub/systemd-boot) : " BOOTLOADER
            continue  # Revient au début de la boucle pour recommencer avec le nouveau choix
        fi
    done

    log_prompt "INFO" && echo "arch-chroot - mkinitcpio"
    # arch-chroot "${MOUNT_POINT}" mkinitcpio -P || true
    # arch-chroot "${MOUNT_POINT}" mkinitcpio -P && echo "Statut de mkinitcpio : $?"

    arch-chroot "${MOUNT_POINT}" mkinitcpio -P | while IFS= read -r line; do
        echo "$line"
    done

    echo "mkinitcpio terminé avec succès."

}

install_base_secu() {

    local passwdqc_conf="/etc/security/passwdqc.conf"
    local min_simple="4"     # Valeurs : disabled : Longueur minimale pour un mot de passe simple, c'est-à-dire uniquement des lettres minuscules (ex. : "abcdef").
    local min_2classes="4"   # Longueur minimale pour un mot de passe avec deux classes de caractères, par exemple minuscules + majuscules ou minuscules + chiffres (ex. : "Abcdef" ou "abc123").
    local min_3classes="4"   # Longueur minimale pour un mot de passe avec trois classes de caractères, comme minuscules + majuscules + chiffres (ex. : "Abc123").
    local min_4classes="4"   # Longueur minimale pour un mot de passe avec quatre classes de caractères, incluant minuscules + majuscules + chiffres + caractères spéciaux (ex. : "Abc123!").
    local min_phrase="4"     # Longueur minimale pour une phrase de passe, qui est généralement une suite de plusieurs mots ou une longue chaîne de caractères (ex. : "monmotdepassecompliqué").
    local min="$min_simple,$min_2classes,$min_3classes,$min_4classes,$min_phrase"
    local max="72"           # Définit la longueur maximale autorisée pour un mot de passe. Dans cet exemple, un mot de passe ne peut pas dépasser 72 caractères.
    local passphrase="3"     # Définit la longueur minimale pour une phrase de passe en termes de nombre de mots. Ici, une phrase de passe doit comporter au moins 3 mots distincts pour être considérée comme valide.
    local match="4"          # Ce paramètre détermine la longueur minimale des segments de texte qui doivent correspondre entre deux chaînes pour être considérées comme similaires.
    local similar="permit"   # Valeurs : permit ou deny : Définit la politique en matière de similitude entre le mot de passe et d'autres informations (par exemple, le nom de l'utilisateur).
    local random="47"
    local enforce="everyone" #  Valeurs : none ou users ou everyone : Ce paramètre applique les règles de complexité définies à tous les utilisateurs.
    local retry="3"          # Ce paramètre permet à l'utilisateur de réessayer jusqu'à 3 fois pour entrer un mot de passe conforme si le mot de passe initial proposé est refusé. 
    local ssh_config_file="/etc/ssh/sshd_config"

    log_prompt "INFO" && echo "Configuration de passwdqc.conf" && echo ""
    if [ -f "${MOUNT_POINT}$passwdqc_conf" ]; then
        cp "${MOUNT_POINT}$passwdqc_conf" "${MOUNT_POINT}$passwdqc_conf.bak"
    fi

    log_prompt "INFO" && echo "Création ou modification du fichier passwdqc.conf dans ${MOUNT_POINT}${passwdqc_conf}" && echo ""

    {
        echo "min=$min"
        echo "max=$max"
        echo "console-mode max"
        echo "editor no"
        echo "passphrase=$passphrase"
        echo "match=$match"
        echo "similar=$similar"
        echo "enforce=$enforce"
        echo "retry=$retry"

    } > ${MOUNT_POINT}${passwdqc_conf}

    log_prompt "SUCCESS" && echo "Fichier passwdqc.conf créé ou modifié avec succès !" && echo ""  

    ## arch-chroot Création d'un mot de passe root                                             
    while true; do
        log_prompt "INFO" && read -p "Souhaitez-vous changer le mot de passe root (Y/n) : " pass_root && echo ""
            
        # Vérifie la validité de l'entrée
        if [[ "$pass_root" =~ ^[yYnN]$ ]]; then
            break
        else
            log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)." && echo ""
        fi
    done

    # Si l'utilisateur répond Y ou y
    if [[ "$pass_root" =~ ^[yY]$ ]]; then
        # Demande de changer le mot de passe root
        while true; do
            read -p "Veuillez entrer le nouveau mot de passe pour root : " -s new_pass && echo ""
            read -p "Confirmez le mot de passe : " -s confirm_pass && echo ""

            # Vérifie si les mots de passe correspondent
            if [[ "$new_pass" == "$confirm_pass" ]]; then
                log_prompt "INFO" && echo "arch-chroot - Configuration du compte root"
                echo -e "$new_pass\n$new_pass" | arch-chroot ${MOUNT_POINT} passwd "root"
                log_prompt "SUCCESS" && echo "OK" && echo ""
                break
            else
                log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
            fi
        done
    fi

        ## arch-chroot Création d'un utilisateur + mot de passe                                            
    arch-chroot ${MOUNT_POINT} sed -i 's/# %wheel/%wheel/g' /etc/sudoers
    arch-chroot ${MOUNT_POINT} sed -i 's/%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/g' /etc/sudoers

    # Demande tant que la réponse n'est pas y/Y ou n/N
    while true; do
        log_prompt "INFO" && read -p "Souhaitez-vous créer un utilisateur (Y/n) : " add_user && echo ""
            
        # Vérifie la validité de l'entrée
        if [[ "$add_user" =~ ^[yYnN]$ ]]; then
            break
        else
            log_prompt "WARNING" && echo "Veuillez répondre par Y (oui) ou N (non)." && echo ""
        fi
    done

    # Si l'utilisateur répond Y ou y
    if [[ "$add_user" =~ ^[yY]$ ]]; then
        log_prompt "INFO" && read -p "Saisir le nom d'utilisateur souhaité : " sudo_user && echo ""
        arch-chroot ${MOUNT_POINT} useradd -m -G wheel,audio,video,optical,storage,power,input "$sudo_user"

        # Demande de changer le mot de passe $USER
        while true; do
            read -p "Veuillez entrer le nouveau mot de passe pour $sudo_user : " -s new_pass  && echo ""
            read -p "Confirmez le mot de passe : " -s confirm_pass  && echo ""

            # Vérifie si les mots de passe correspondent
            if [[ "$new_pass" == "$confirm_pass" ]]; then
                log_prompt "INFO" && echo "arch-chroot - Configuration du compte $sudo_user"
                echo -e "$new_pass\n$new_pass" | arch-chroot ${MOUNT_POINT} passwd $sudo_user
                log_prompt "SUCCESS" && echo "OK" && echo ""
                break
            else
                log_prompt "WARNING" && echo "Les mots de passe ne correspondent pas. Veuillez réessayer." && echo ""
            fi
        done
    fi

    log_prompt "INFO" && echo "arch-chroot - Configuration du SSH"
    sed -i "s/#Port 22/Port $SSH_PORT/" "${MOUNT_POINT}$ssh_config_file"
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' "${MOUNT_POINT}$ssh_config_file"
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' "${MOUNT_POINT}$ssh_config_file"
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' "${MOUNT_POINT}$ssh_config_file"
    sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' "${MOUNT_POINT}$ssh_config_file"
    log_prompt "SUCCESS" && echo "OK" && echo ""

}

activate_service() {
    log_prompt "INFO" && echo "arch-chroot - Activation des services"
    arch-chroot ${MOUNT_POINT} systemctl enable sshd
    arch-chroot ${MOUNT_POINT} systemctl enable systemd-homed
    arch-chroot ${MOUNT_POINT} systemctl enable systemd-networkd 
    arch-chroot ${MOUNT_POINT} systemctl enable systemd-resolved 
    log_prompt "SUCCESS" && echo "OK" && echo ""
}

