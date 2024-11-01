# `arch-install`

## Description
Ce projet a pour objectif d'installer et de configurer Hyprland, un compositeur Wayland dynamique et personnalisable, sur une base Arch Linux. Hyprland est conçu pour offrir un environnement de bureau léger et performant, avec un accent sur la fluidité et la modularité, idéal pour les utilisateurs avancés.

L'objectif est de mettre en place un système optimisé pour deux usages principaux : un environnement de développement et un environnement de pentesting. Ce projet propose ainsi une configuration polyvalente, adaptée aux besoins spécifiques de chaque contexte d'utilisation.

## Visuels
À venir

## Installation

<!-- Procédez aux étapes suivantes :

1. Télécharger le support d'installation : `https://archlinux.org/download/`
2. Changer la disposition du clavier : `loadkeys fr`
3. Attention : efface toutes les signatures de système de fichiers : `wipefs --force --all "ex. /dev/sda"`
4. Attention : écrase les données sur le disque : `shred -v -n "ex. 3" -z "ex. /dev/sda"`
5. Installation du paquet git : `pacman -Sy git`
6. Clone du repo : `git clone https://github.com/alexandre-Maury/arch-install.git`
7. Configuration des options : `cd arch-install && nano config.sh`
8. Exécution du script : `chmod +x install.sh && ./install.sh` -->

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

8- Rendez le script exécutable et lancez-le pour commencer l'installation :

    chmod +x install.sh && ./install.sh


## Feuille de route

1. Mise en place du système [En cours]

Installation et configuration initiale d'Arch Linux avec Hyprland, incluant la gestion des paquets et les configurations de base du système.

2. Mise en place d'un laboratoire de développement [À venir]

Configuration d'un environnement de développement comprenant les outils et bibliothèques nécessaires pour le développement de logiciels, avec des langages et frameworks spécifiques selon les besoins.

3. Mise en place d'un laboratoire de pentesting [À venir]

Installation et configuration des outils de test de pénétration et de sécurité, permettant de simuler des attaques et d'évaluer la sécurité des systèmes.

## Auteurs
`- Alexandre MAURY`

## Contribution
`- Alexandre MAURY`

## Licence

## État du projet
`- En cours de développement`