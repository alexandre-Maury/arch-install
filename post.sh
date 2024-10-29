#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.

##############################################################################
## Information Utilisateur                                              
##############################################################################
log_prompt "INFO" && read -p "Quel est votre nom d'utilisateur : " USER && echo ""

##############################################################################
## Mise à jour du système                                                 
##############################################################################
log_prompt "INFO" && echo "Mise à jour du système " && echo ""
sudo pacman -Syu --noconfirm
log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## arch-chroot Définir le fuseau horaire + local                                                  
##############################################################################
log_prompt "INFO" && echo "Configuration du fuseau horaire" && echo ""
sudo timedatectl set-ntp true
sudo timedatectl set-timezone ${REGION}/${CITY}
sudo localectl set-locale LANG="${LANG}" LC_TIME="${LANG}"
sudo hwclock --systohc --utc
timedatectl status

log_prompt "SUCCESS" && echo "Terminée" && echo ""

##############################################################################
## Installation de YAY && PARU                                                 
##############################################################################
if ! command -v yay &> /dev/null; then
    log_prompt "INFO" && echo "Installation de YAY" && echo ""
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin || exit
    makepkg -si --noconfirm
    cd .. && rm -rf yay-bin
    log_prompt "SUCCESS" && echo "Terminée" && echo ""

else
    log_prompt "INFO" && echo "YAY est déja installé" && echo ""
fi

if ! command -v paru &> /dev/null; then
        log_prompt "INFO" && echo "Installation de PARU" && echo ""
    git clone https://aur.archlinux.org/paru.git
    cd paru || exit
    makepkg -si --noconfirm
    cd .. && rm -rf paru
    log_prompt "SUCCESS" && echo "Terminée" && echo ""

else
    log_prompt "INFO" && echo "PARU est déja installé" && echo ""
fi


##############################################################################
## Install SDDM                                            
##############################################################################
# log_prompt "INFO" && echo "Installation de SDDM" && echo ""
# sudo paru -S sddm sddm-sugar-dark --noconfirm

# THEME="sugar-dark"

# mkdir -p /etc/sddm.conf.d
# # sudo cp /usr/lib/sddm/sddm.conf.d/default.conf /etc/sddm.conf.d/sddm.conf
# cat <<EOF > /etc/sddm.conf.d/sddm.conf
# [Users]
# DefaultUser=${USER}
# Session=hyprland.desktop
# [Theme]
# Current=${THEME}
# [General]
# # Activer le support Wayland
# DisplayServer=wayland
# EOF

# log_prompt "SUCCESS" && echo "Terminée" && echo ""


##############################################################################
## Install Hyprland                                               
##############################################################################
# yay -S --noconfirm gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors hyprutils-git aquamarine
# yay -S hyprland-git

log_prompt "INFO" && echo "installation des dépendances" && echo ""
sudo paru -S --needed --noconfirm \
  base-devel \
  cmake \
  meson \
  ninja \
  wayland \
  wlroots \
  aquamarine \
  hyprwayland-scanner \
  hyprcursor \
  hyprlang \
  xorg-server-devel \
  kitty

# Installation des polices pour une compatibilité étendue
sudo paru -S --noconfirm noto-fonts noto-fonts-emoji

log_prompt "INFO" && echo "Clonage du dépôt Hyprland" && echo ""
git clone --recursive https://github.com/hyprwm/Hyprland.git ~/Hyprland
cd ~/Hyprland || exit

log_prompt "INFO" && echo "Compilation et installation de Hyprland" && echo ""
meson setup build
ninja -C build
sudo ninja -C build install


log_prompt "INFO" && echo "Nettoyage des fichiers temporaires" && echo ""
cd .. && rm -rf ~/Hyprland


log_prompt "INFO" && echo "Configuration de Hyprland" && echo ""

mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/dunst

cat << EOF > ~/.config/hypr/hyprland.conf
# Configuration Hyprland inspirée de Kali Linux Purple

# Définition des couleurs
\$purple = rgb(8A2BE2)
\$darkpurple = rgb(4B0082)
\$black = rgb(000000)
\$white = rgb(FFFFFF)

# Configuration générale
general {
    border_size = 2
    gaps_in = 5
    gaps_out = 10
    col.active_border = \$purple
    col.inactive_border = \$darkpurple
    layout = dwindle
}

# Décoration des fenêtres
decoration {
    rounding = 5
    blur = true
    blur_size = 5
    blur_passes = 2
    drop_shadow = true
    shadow_range = 15
    shadow_render_power = 3
    col.shadow = \$purple
}

# Animation
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Configuration du clavier
input {
    kb_layout = fr
    kb_variant =
    kb_model =
    kb_options =
    kb_rules =
    follow_mouse = 1
    touchpad {
        natural_scroll = true
    }
}

# Règles pour les fenêtres
windowrule = float, ^(pavucontrol)$
windowrule = float, ^(nm-connection-editor)$

# Raccourcis clavier
bind = SUPER, Return, exec, foot
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, thunar
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, wofi --show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

# Déplacement entre les espaces de travail
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5
bind = SUPER, 6, workspace, 6
bind = SUPER, 7, workspace, 7
bind = SUPER, 8, workspace, 8
bind = SUPER, 9, workspace, 9
bind = SUPER, 0, workspace, 10

# Déplacement des fenêtres entre les espaces de travail
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
bind = SUPER SHIFT, 6, movetoworkspace, 6
bind = SUPER SHIFT, 7, movetoworkspace, 7
bind = SUPER SHIFT, 8, movetoworkspace, 8
bind = SUPER SHIFT, 9, movetoworkspace, 9
bind = SUPER SHIFT, 0, movetoworkspace, 10

# Exécution au démarrage
exec-once = waybar
exec-once = dunst
exec-once = /usr/lib/polkit-kde-authentication-agent-1
exec-once = hyprpaper

exec-once = systemctl --user start pipewire.service
exec-once = systemctl --user start pipewire-pulse.service
exec-once = systemctl --user start wireplumber.service
EOF

log_prompt "INFO" && echo "Configuration de waybar" && echo ""
cat > ~/.config/waybar/config << 'EOL'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["pulseaudio", "network", "cpu", "memory", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "clock": {
        "format": "{:%H:%M}",
        "format-alt": "{:%Y-%m-%d}"
    },
    "cpu": {
        "format": "CPU {usage}%"
    },
    "memory": {
        "format": "RAM {}%"
    },
    "battery": {
        "format": "BAT {capacity}%"
    },
    "network": {
        "format-wifi": "WiFi ({signalStrength}%)",
        "format-ethernet": "ETH",
        "format-disconnected": "Disconnected"
    },
    "pulseaudio": {
        "format": "VOL {volume}%",
        "format-muted": "MUTED"
    },
    "tray": {
        "spacing": 10
    }
}
EOL

# log_prompt "INFO" && echo "Configuration de la session Hyprland pour SDDM" && echo ""
# sudo tee /usr/share/wayland-sessions/hyprland.desktop << 'EOL'
# [Desktop Entry]
# Name=Hyprland
# Comment=A highly customizable dynamic tiling Wayland compositor
# Exec=Hyprland
# Type=Application
# EOL

# log_prompt "INFO" && echo "Configuration de SDDM" && echo ""
# sudo tee /etc/sddm.conf << 'EOL'
# [Autologin]
# # Activer l'auto-login
# User=$USER
# Session=hyprland.desktop

# [Theme]
# # Utiliser le thème Catppuccin
# Current=catppuccin

# [General]
# # Activer le support Wayland
# DisplayServer=wayland
# EOL


# sudo systemctl enable sddm

# Ajout des variables d'environnement
echo '
# Hyprland environment variables
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
' >> ~/.bashrc

log_prompt "INFO" && echo "Installation terminée ! Redémarrez votre système et SDDM démarrera automatiquement avec Hyprland." && echo ""

# Demander si l'utilisateur veut redémarrer maintenant
read -p "Voulez-vous redémarrer maintenant ? (o/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    sudo reboot
fi

# Lancement automatique de Hyprland via SDDM
# echo 'exec Hyprland' > ~/.xprofile

log_prompt "SUCCESS" && echo "Terminée" && echo ""


##############################################################################
## Activation des services                                                
##############################################################################
# sudo systemctl enable sddm
# export PATH="$PATH:$HOME/.local/bin"