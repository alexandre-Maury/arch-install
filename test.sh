##############################################################################
## Installation des pilotes CPU et GPU                                          
##############################################################################

# Détection du type de processeur et installation du microcode
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

##############################################################################
## Installation des pilotes GPU et configuration de mkinitcpio.conf                                           
##############################################################################

# Détection et installation des pilotes graphiques
if lspci | grep -E "NVIDIA|GeForce"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes NVIDIA" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S nvidia-dkms nvidia-utils opencl-nvidia \
    libglvnd lib32-libglvnd lib32-nvidia-utils lib32-opencl-nvidia nvidia-settings \
    --noconfirm 

    # Configuration de mkinitcpio.conf pour NVIDIA
    log_prompt "INFO" && echo "Configuration de mkinitcpio.conf pour NVIDIA" && echo ""
    arch-chroot "${MOUNT_POINT}" sed -i "s/^MODULES=.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /etc/mkinitcpio.conf
    [ ! -d "${MOUNT_POINT}/etc/pacman.d/hooks" ] && arch-chroot "${MOUNT_POINT}" mkdir -p /etc/pacman.d/hooks
    cat <<EOF | arch-chroot "${MOUNT_POINT}" tee /etc/pacman.d/hooks/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia

[Action]
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
EOF

elif lspci | grep -E "Radeon"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes AMD Radeon" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S xf86-video-amdgpu --noconfirm 

    # Configuration de mkinitcpio.conf pour AMD Radeon
    log_prompt "INFO" && echo "Configuration de mkinitcpio.conf pour AMD Radeon" && echo ""
    arch-chroot "${MOUNT_POINT}" sed -i "s/^MODULES=.*/MODULES=(amdgpu radeon)/" /etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

elif lspci | grep -E "Integrated Graphics Controller"; then
    log_prompt "INFO" && echo "arch-chroot - Installation des pilotes Intel pour GPU intégré" && echo ""
    arch-chroot "${MOUNT_POINT}" pacman -S libva-intel-driver libvdpau-va-gl \
    lib32-vulkan-intel vulkan-intel libva-utils intel-gpu-tools --noconfirm 

    # Configuration de mkinitcpio.conf pour GPU Intel intégré
    log_prompt "INFO" && echo "Configuration de mkinitcpio.conf pour Intel intégré" && echo ""
    arch-chroot "${MOUNT_POINT}" sed -i "s/^MODULES=.*/MODULES=(i915)/" /etc/mkinitcpio.conf
    arch-chroot "${MOUNT_POINT}" mkinitcpio -P

else
    log_prompt "WARNING" && echo "arch-chroot - Aucun GPU reconnu, aucun pilote installé." && echo ""
fi

##############################################################################
## Installation du bootloader (GRUB ou systemd-boot) en mode UEFI ou BIOS                                           
##############################################################################

BOOTLOADER=${BOOTLOADER:-"grub"} # Par défaut, GRUB est utilisé
MODE=${MODE:-"UEFI"}             # Par défaut, UEFI est utilisé


