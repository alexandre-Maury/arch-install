#!/bin/bash

# script install.sh

set -e  # Quitte immédiatement en cas d'erreur.

source config.sh # Inclure le fichier de configuration.
source functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

chmod +x *.sh # Rendre les scripts exécutables.


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
cd /tmp

git clone https://aur.archlinux.org/yay.git
git clone https://aur.archlinux.org/paru.git

cd /tmp/paru && makepkg -si && paru -Syu
cd /tmp/yay && makepkg -si

##############################################################################
## Install packages                                                
##############################################################################

# Guest tools ==> SPICE support on guest (for UTM)
sudo pacman -S spice-vdagent xf86-video-qxl --noconfirm

# Guest tools ==> for VirtualBox
sudo pacman -S virtualbox-guest-utils --noconfirm

# Guest tools ==> for Fonts
sudo pacman -S noto-fonts ttf-opensans ttf-firacode-nerd --noconfirm
sudo pacman -S noto-fonts-emoji --noconfirm


##############################################################################
## Install SDDM                                            
##############################################################################
# sudo pacman -S sddm sddm-sugar-dark --noconfirm
# sudo systemctl enable sddm

# sudo mkdir /etc/sddm.conf.d
# sudo cp /usr/lib/sddm/sddm.conf.d/default.conf /etc/sddm.conf.d/sddm.conf
# sudo nvim /etc/sddm.conf.d/sddm.conf


##############################################################################
## Install Hyprland                                               
##############################################################################
yay -S --noconfirm gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors hyprutils-git aquamarine

cd /tmp && git clone --recursive https://github.com/hyprwm/Hyprland
cd /tmp/Hyprland && make all && sudo make install
# yay -S hyprland-git

##############################################################################
## Clean                                                
##############################################################################

sudo rm -rf /tmp/*


# Création du dossier de configuration pour Hyprland
mkdir -p ~/.config/hypr

# Génération du fichier de configuration Hyprland
cat <<EOL > ~/.config/hypr/hyprland.conf
# Configuration Hyprland - ~/.config/hypr/hyprland.conf

# Moniteur
monitor=,1920x1080@60,0x0,1  # Configurer l'affichage selon vos besoins

# Fond d'écran
wallpaper=~/Images/wallpapers/default.jpg  # Chemin vers l'image de fond

# Curseur
cursor_size=24
cursor=default

# Application par défaut
default-term=alacritty

# Effets et bordures
shadow=on
blur_size=5
border_size=2

# Thèmes
border_color=0xffa1a1a1
bg_color=0xff2e3440
text_color=0xffffffff

# Raccourcis
bind=SUPER+Return,exec,alacritty  # SUPER+Entrée pour ouvrir Alacritty
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

# Installation des polices pour une compatibilité étendue
sudo pacman -S --noconfirm noto-fonts noto-fonts-emoji

echo "Configuration de Hyprland terminée."