#!/bin/bash

# Fonction pour le logging
log() {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

# Fonction pour vérifier si une commande existe
check_command() {
    if ! command -v $1 &> /dev/null; then
        log "$1 n'est pas installé. Installation..."
        return 1
    else
        log "$1 est déjà installé"
        return 0
    fi
}

# Installation de yay si nécessaire
if ! check_command yay; then
    log "Installation de yay..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si
    cd ..
    rm -rf yay
fi

# Installation des dépendances de base nécessaires pour la compilation
log "Installation des dépendances de compilation..."
sudo yay -S --needed \
    base-devel \
    cmake \
    meson \
    ninja \
    wayland \               # Protocole d'affichage moderne remplaçant X11
    wlroots \               # Bibliothèque pour compositors Wayland
    libx11 \                # Support X11 (rétrocompatibilité)
    libxkbcommon \          # Gestion du clavier
    libdrm \                # Direct Rendering Manager (accès GPU)
    pixman \                # Manipulation d'images bas niveau
    vulkan-headers \        # Support Vulkan (performances graphiques)
    vulkan-icd-loader \     # Chargeur Vulkan
    cairo \                 # Bibliothèque graphique 2D
    pango \                 # Rendu de texte
    xorg-server-devel       # Headers Xorg

# Installation de SDDM et son thème
log "Installation de SDDM..."
sudo yay -S --needed \
    sddm \
    sddm-theme-catppuccin-git  # Un thème moderne pour SDDM (optionnel)

# Installation de PipeWire et ses dépendances
log "Installation de PipeWire..."
sudo yay -S --needed \
    pipewire \         # Serveur multimédia moderne
    pipewire-alsa \    # Support ALSA
    pipewire-audio \   # Support audio
    pipewire-jack \    # Support JACK
    pipewire-pulse \   # Support PulseAudio
    wireplumber        # Session manager pour PipeWire

# Installation des outils essentiels pour l'environnement Wayland
log "Installation des outils Wayland..."
sudo yay -S --needed \
    xdg-desktop-portal-hyprland \  # Portail XDG pour Hyprland
    qt5-wayland \                  # Support Wayland pour Qt5
    qt6-wayland \                  # Support Wayland pour Qt6
    kitty \                        # Terminal moderne
    waybar-hyprland \              # Barre de status
    rofi-lbonn-wayland-git \       # Lanceur d'applications
    dunst \                        # Notifications
    swaylock-effects \             # Verrouillage d'écran
    swayidle \                     # Gestion de l'idle
    grim \                         # Capture d'écran
    slurp \                        # Sélection de zone d'écran
    wl-clipboard \                 # Gestionnaire de presse-papier
    polkit-kde-agent \             # Agent d'authentification
    xdg-desktop-portal-hyprland    # Portail XDG pour Hyprland

# Installation des polices
log "Installation des polices..."
sudo yay -S --needed \
    noto-fonts \                   # Police de base Google
    noto-fonts-emoji \             # Emojis
    ttf-jetbrains-mono-nerd        # Police pour terminal avec icônes

# Clonage et compilation de Hyprland
log "Clonage de Hyprland..."
git clone --recursive https://github.com/hyprwm/Hyprland.git ~/Hyprland
cd ~/Hyprland || exit

log "Compilation de Hyprland..."
meson setup build
ninja -C build
sudo ninja -C build install

# Création des répertoires de configuration
log "Création des répertoires de configuration..."
mkdir -p ~/.config/hypr
mkdir -p ~/.config/waybar
mkdir -p ~/.config/dunst

# Configuration de Hyprland
log "Configuration de Hyprland..."
cat > ~/.config/hypr/hyprland.conf << 'EOL'
# Configuration moniteur
monitor=,preferred,auto,auto

# Variables d'environnement
env = XCURSOR_SIZE,24
env = QT_QPA_PLATFORMTHEME,qt5ct
env = XDG_SESSION_TYPE,wayland

# Configuration pour Nvidia si nécessaire
# env = LIBVA_DRIVER_NAME,nvidia
# env = GBM_BACKEND,nvidia-drm
# env = __GLX_VENDOR_LIBRARY_NAME,nvidia
# env = WLR_NO_HARDWARE_CURSORS,1

# Configuration PipeWire
exec-once = systemctl --user start pipewire.service
exec-once = systemctl --user start pipewire-pulse.service
exec-once = systemctl --user start wireplumber.service

# Démarrage automatique
exec-once = waybar
exec-once = dunst
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

# Raccourcis clavier
bind = SUPER, Return, exec, kitty
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,
bind = SUPER, E, exec, dolphin
bind = SUPER, V, togglefloating,
bind = SUPER, R, exec, rofi -show drun
bind = SUPER, P, pseudo,
bind = SUPER, J, togglesplit,
bind = SUPER SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy

# Gestion des espaces de travail
bind = SUPER, 1, workspace, 1
bind = SUPER, 2, workspace, 2
bind = SUPER, 3, workspace, 3
bind = SUPER, 4, workspace, 4
bind = SUPER, 5, workspace, 5

# Déplacement des fenêtres
bind = SUPER SHIFT, 1, movetoworkspace, 1
bind = SUPER SHIFT, 2, movetoworkspace, 2
bind = SUPER SHIFT, 3, movetoworkspace, 3
bind = SUPER SHIFT, 4, movetoworkspace, 4
bind = SUPER SHIFT, 5, movetoworkspace, 5
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

# Création du fichier de session Hyprland pour SDDM
log "Configuration de la session Hyprland pour SDDM..."
sudo tee /usr/share/wayland-sessions/hyprland.desktop << 'EOL'
[Desktop Entry]
Name=Hyprland
Comment=A highly customizable dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOL

# Configuration de SDDM
log "Configuration de SDDM..."
sudo tee /etc/sddm.conf << 'EOL'
[Autologin]
# Activer l'auto-login
User=$USER
Session=hyprland.desktop

[Theme]
# Utiliser le thème Catppuccin
Current=catppuccin

[General]
# Activer le support Wayland
DisplayServer=wayland
EOL

# Activation de SDDM
log "Activation de SDDM..."
sudo systemctl enable sddm

# Ajout des variables d'environnement
log "Configuration des variables d'environnement..."
echo '
# Hyprland environment variables
export XDG_CURRENT_DESKTOP=Hyprland
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_DESKTOP=Hyprland
' >> ~/.bashrc

log "Installation terminée ! Redémarrez votre système et SDDM démarrera automatiquement avec Hyprland."

# Demander si l'utilisateur veut redémarrer maintenant
read -p "Voulez-vous redémarrer maintenant ? (o/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Oo]$ ]]; then
    sudo reboot
fi