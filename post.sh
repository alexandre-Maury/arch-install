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
# [Theme]
# Current=${THEME}

# [Users]
# # Définir l'utilisateur par défaut, si souhaité
# DefaultUser=${USER}

# # Activation de l'auto-login (optionnel)
# # AutoLogin=votre_utilisateur
# # AutoLoginSession=your_desktop_environment
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
  libx11 \
  libxkbcommon \
  libdrm \
  pixman \
  vulkan-headers \
  vulkan-icd-loader \
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

# Création des répertoires de configuration
echo "Création des répertoires de configuration..."
mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/dunst

# Création du fichier de configuration Hyprland
echo "Création de la configuration Hyprland..."
cat > ~/.config/hypr/hyprland.conf << 'EOL'
# Configuration moniteur
monitor=,preferred,auto,auto

# Variables d'environnement
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# Démarrage automatique
exec-once = waybar
exec-once = dunst
exec-once = hyprpaper
exec-once = /usr/lib/polkit-kde-authentication-agent-1

# Input configuration
input {
    kb_layout = fr
    follow_mouse = 1
    touchpad {
        natural_scroll = true
        tap-to-click = true
    }
}

# Apparence générale
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee)
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

# Décoration des fenêtres
decoration {
    rounding = 10
    blur = true
    blur_size = 3
    blur_passes = 1
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
}

# Animations
animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Disposition
dwindle {
    pseudotile = true
    preserve_split = true
}

# Raccourcis clavier
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, rofi -show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,

# Gestion des espaces de travail
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

# Déplacement des fenêtres
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

# Capture d'écran
bind = SUPER SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy
EOL

# Configuration de Waybar
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
        "format": "{icon}",
        "format-icons": {
            "1": "1",
            "2": "2",
            "3": "3",
            "4": "4",
            "5": "5",
            "urgent": "",
            "focused": "",
            "default": ""
        }
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

# Style pour Waybar
cat > ~/.config/waybar/style.css << 'EOL'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(21, 18, 27, 0.9);
    color: #cdd6f4;
}

#workspaces button {
    padding: 0 5px;
    background: transparent;
    color: #cdd6f4;
    border-bottom: 3px solid transparent;
}

#workspaces button.active {
    border-bottom: 3px solid #89b4fa;
}

#clock,
#battery,
#cpu,
#memory,
#network,
#pulseaudio,
#tray {
    padding: 0 10px;
    margin: 0 5px;
}
EOL

echo "Installation terminée ! Déconnectez-vous et sélectionnez Hyprland dans votre gestionnaire de session."

# Lancement automatique de Hyprland via SDDM
# echo 'exec Hyprland' > ~/.xprofile

log_prompt "SUCCESS" && echo "Terminée" && echo ""


##############################################################################
## Activation des services                                                
##############################################################################
# sudo systemctl enable sddm
# export PATH="$PATH:$HOME/.local/bin"