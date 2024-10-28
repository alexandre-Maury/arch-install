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
pacman -Syu --noconfirm
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
log_prompt "INFO" && echo "Installation de SDDM" && echo ""
sudo pacman -S sddm sddm-sugar-dark --noconfirm

THEME="sugar-dark"

mkdir -p /etc/sddm.conf.d
# sudo cp /usr/lib/sddm/sddm.conf.d/default.conf /etc/sddm.conf.d/sddm.conf
cat <<EOF > /etc/sddm.conf.d/sddm.conf
[Theme]
Current=${THEME}

[Users]
# Définir l'utilisateur par défaut, si souhaité
DefaultUser=${USER}

# Activation de l'auto-login (optionnel)
# AutoLogin=votre_utilisateur
# AutoLoginSession=your_desktop_environment
EOF

log_prompt "SUCCESS" && echo "Terminée" && echo ""


##############################################################################
## Install Hyprland                                               
##############################################################################
# yay -S --noconfirm gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors hyprutils-git aquamarine
# yay -S hyprland-git

log_prompt "INFO" && echo "installation des dépendances" && echo ""
sudo pacman -S --needed --noconfirm \
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
sudo pacman -S --noconfirm noto-fonts noto-fonts-emoji

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

cat <<EOL > ~/.config/hypr/hyprland.conf
# Configuration Hyprland - ~/.config/hypr/hyprland.conf

# Moniteur
monitor=,1920x1080@60,0x0,1  # Configurer l'affichage selon vos besoins

# Fond d'écran
# wallpaper=~/Images/wallpapers/default.jpg  # Chemin vers l'image de fond

# Effets et bordures
border_size=2

# Thèmes
border_color=0xffa1a1a1
bg_color=0xff2e3440
text_color=0xffffffff

# Raccourcis
bind=SUPER+Return,exec,kitty  # SUPER+Entrée pour ouvrir kitty
bind=SUPER+D,exec,rofi -show drun # SUPER+D pour ouvrir Rofi
bind=SUPER+Q,close                 # SUPER+Q pour fermer une fenêtre

# Gestion des fenêtres
bind=SUPER+F,fullscreen            # Mode plein écran
bind=SUPER+Left,moveleft 10        # Déplacer une fenêtre à gauche
bind=SUPER+Right,moveright 10      # Déplacer une fenêtre à droite
bind=SUPER+Up,moveup 10            # Déplacer une fenêtre en haut
bind=SUPER+Down,movedown 10        # Déplacer une fenêtre en bas

# Barre de tâches (si Waybar est installé)
exec-once=waybar &
EOL

# Configuration de Waybar
mkdir -p ~/.config/waybar

cat <<EOL > ~/.config/waybar/config
// ~/.config/waybar/config
{
  "layer": "top",
  "position": "top",
  "modules-left": ["sway/workspaces"],
  "modules-center": ["clock"],
  "modules-right": ["network", "battery", "memory", "cpu", "temperature"],
  "clock": {
    "format": "{:%H:%M:%S}"
  },
  "battery": {
    "format": "{capacity}% {icon}"
  }
}
EOL

# Lancement automatique de Hyprland via SDDM
echo 'exec Hyprland' > ~/.xprofile


##############################################################################
## Activation des services                                                
##############################################################################
sudo systemctl enable sddm
# export PATH="$PATH:$HOME/.local/bin"