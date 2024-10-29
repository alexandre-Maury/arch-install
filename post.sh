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
  kitty \
  alacritty

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
# ---- Fichiers de base ----
monitor=,preferred,auto,1
layout=master

# ---- Paramètres généraux ----
# Définit le modificateur de touche pour Hyprland (ici, la touche super)
general {
    mod=SUPER
    gaps_in=10         # Espacement entre les fenêtres
    gaps_out=20        # Espacement par rapport aux bords de l'écran
    border_size=2      # Taille de la bordure des fenêtres
    col.active_border=0xffa54242  # Couleur de la bordure des fenêtres actives
    col.inactive_border=0xff2e3440  # Couleur des bordures inactives (sombre)
    animations=1       # Active les animations de base
}

# ---- Apparence ----
decoration {
    rounding=8                # Arrondis des fenêtres
    active_opacity=0.95       # Opacité pour les fenêtres actives
    inactive_opacity=0.85     # Opacité pour les fenêtres inactives
    blur_size=4               # Taille du flou pour les effets de transparence
    blur_passes=3             # Passes de flou pour plus de profondeur
    shadow=1                  # Active les ombres pour un effet de profondeur
}

# ---- Gestion des fenêtres ----
master {
    orientation=horizontal     # Disposition horizontale pour le travail en terminal
    msize=0.65                 # Taille du maître (fenêtre principale)
}

# ---- Barre d’état et Polybar ----
bar {
    # Remplace ceci par une configuration Polybar si tu préfères.
    status_command=~/.config/hypr/scripts/polybar.sh
    font=JetBrainsMono Nerd Font:size=10
    bar_position=top
    padding=10
}

# ---- Raccourcis Clavier ----
bind=SUPER,RETURN,exec,alacritty  # Lancer Alacritty avec SUPER+Return
bind=SUPER,d,exec,dmenu_run       # Lancer dmenu avec SUPER+d
bind=SUPER+SHIFT,q,closewindow     # Fermer la fenêtre active
bind=SUPER+SHIFT+R,reload,         # Recharger Hyprland avec SUPER+SHIFT+R

# ---- Définitions des couleurs ----
col {
    active_border=0xff5b3b79   # Violet pour les bordures inactives
    inactive_border=0xff2e3440  # Couleur sombre pour les bordures inactives
    background=0xff1c1f26        # Gris anthracite pour le fond
    text=0xffeceff4              # Gris clair pour le texte
    accent=0xff5294e2            # Bleu clair pour les éléments d'accentuation
}

# ---- Multi-écrans ----
monitor=eDP-1,preferred,0x0,1       # Définir l’écran principal avec des valeurs par défaut

# ---- Répartition des fenêtres ----
# Place des applications fréquemment utilisées pour Kali Purple
rule=alacritty,float               # Alacritty sera flottant pour analyse rapide
rule=firefox,tag=2                 # Firefox ouvert sur le tag (bureau) 2 pour navigation
rule=burpsuite,workspace=3         # Burp Suite, un outil d’analyse, ouvert sur le tag 3
rule=wireshark,workspace=4         # Wireshark pour analyse réseau, sur le tag 4
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