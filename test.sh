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
    active_border=0xff5294e2  # Couleur bleue pour les bordures actives
    inactive_border=0xff2e3440  # Couleur sombre pour les bordures inactives
    background=0xff1c1f26     # Fond sombre
    text=0xffeceff4           # Couleur de texte clair pour un contraste
}

# ---- Multi-écrans ----
monitor=eDP-1,preferred,0x0,1       # Définir l’écran principal avec des valeurs par défaut

# ---- Répartition des fenêtres ----
# Place des applications fréquemment utilisées pour Kali Purple
rule=alacritty,float               # Alacritty sera flottant pour analyse rapide
rule=firefox,tag=2                 # Firefox ouvert sur le tag (bureau) 2 pour navigation
rule=burpsuite,workspace=3         # Burp Suite, un outil d’analyse, ouvert sur le tag 3
rule=wireshark,workspace=4         # Wireshark pour analyse réseau, sur le tag 4
