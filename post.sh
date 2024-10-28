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
# cd /tmp

# git clone https://aur.archlinux.org/yay.git
# git clone https://aur.archlinux.org/paru.git

# cd /tmp/paru && makepkg -si && paru -Syu
# cd /tmp/yay && makepkg -si





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
# yay -S --noconfirm gdb ninja gcc cmake meson libxcb xcb-proto xcb-util xcb-util-keysyms libxfixes libx11 libxcomposite xorg-xinput libxrender pixman wayland-protocols cairo pango seatd libxkbcommon xcb-util-wm xorg-xwayland libinput libliftoff libdisplay-info cpio tomlplusplus hyprlang hyprcursor hyprwayland-scanner xcb-util-errors hyprutils-git aquamarine

# cd /tmp && git clone --recursive https://github.com/hyprwm/Hyprland
# cd /tmp/Hyprland && make all && sudo make install
# yay -S hyprland-git

##############################################################################
## Clean                                                
##############################################################################



# Mettre à jour le système et installer les dépendances requises
echo "Mise à jour du système et installation des dépendances..."
sudo pacman -Syu --noconfirm
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
  xorg-server-devel

# Cloner le dépôt Hyprland
echo "Clonage du dépôt Hyprland..."
git clone --recursive https://github.com/hyprwm/Hyprland.git ~/Hyprland
cd ~/Hyprland || exit

# Compiler et installer Hyprland
echo "Compilation et installation de Hyprland..."
meson setup build
ninja -C build
sudo ninja -C build install

# Ajouter Hyprland à l'option de session pour les gestionnaires de sessions (optionnel)
echo "Hyprland est maintenant installé !"
echo "Pour démarrer Hyprland, choisissez-le dans votre gestionnaire de sessions ou lancez 'Hyprland' depuis un terminal."

# Nettoyage des fichiers de compilation
echo "Nettoyage des fichiers temporaires..."
cd ..
rm -rf ~/Hyprland

echo "Installation terminée avec succès."


# Création du dossier de configuration pour Hyprland
mkdir -p ~/.config/hypr

# Génération du fichier de configuration Hyprland
cat <<EOL > ~/.config/hypr/hyprland.conf
# Configuration Hyprland - ~/.config/hypr/hyprland.conf

# Moniteur
monitor=,1920x1080@60,0x0,1  # Configurer l'affichage selon vos besoins

# Fond d'écran
# wallpaper=~/Images/wallpapers/default.jpg  # Chemin vers l'image de fond

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