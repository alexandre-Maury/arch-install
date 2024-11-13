# `Projet 1 : Installation de Base Arch Linux (Sans Interface Graphique)`

## Description
Ce projet vise à automatiser l'installation de base d'Arch Linux sans interface graphique. Il est conçu pour les utilisateurs qui souhaitent une installation minimale, offrant une fondation légère et personnalisable pour des environnements spécifiques comme le développement, le pentesting, ou les serveurs.

Projet 2 : Suite de l'installation avec Hyprland : https://github.com/alexandre-Maury/arch-hyprland.git

## Visuels
À venir

## Installation

Suivez les étapes ci-dessous pour installer et configurer Arch Linux avec Hyprland :

1- Télécharger le support d'installation d'Arch Linux depuis le site officiel :

    https://archlinux.org/download/

2- Configurez la disposition du clavier en français pour la session d'installation :

    loadkeys fr

3- ⚠️ Effacer toutes les signatures de systèmes de fichiers sur le disque spécifié : Assurez-vous de bien sélectionner le disque cible.

    wipefs --force --all /dev/sdX  # Remplacez /dev/sdX par le disque cible, ex. /dev/sda
    
4- ⚠️ Écraser les données du disque : Cette opération est irréversible et écrase tout le contenu du disque.

    shred -v -n 3 -z /dev/sdX  # Remplacez /dev/sdX par le disque cible, ex. /dev/sda

5- Mettez à jour la liste des paquets et installez Git :

    pacman -Sy git


6- Clonez le dépôt contenant le script d'installation :

    git clone https://github.com/alexandre-Maury/arch-install.git

7- Accédez au répertoire cloné et modifiez le fichier config.sh pour ajuster les options d'installation selon vos préférences :

    cd arch-install && nano config.sh

    

    ![alt text](https://github.com/alexandre-Maury/arch-install/assets/config.png?raw=true)

8- Rendez le script exécutable et lancez-le pour commencer l'installation :

    chmod +x install.sh && ./install.sh


## Feuille de route

1. Mise en place du système [OK]

Mise en place d'Arch Linux avec les configurations réseau et de base pour un environnement minimal.

2. Ajouts spécifiques [À venir]

Instructions pour des ajouts personnalisés en fonction des besoins, comme les outils de développement ou d'administration.


## Auteurs
`- Alexandre MAURY`

## Contribution
`- Alexandre MAURY`

## Licence

## État du projet
`- En cours de développement`