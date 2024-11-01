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

3- Effacer les signatures de système de fichiers :
⚠️ Attention : Cette commande efface toutes les signatures de systèmes de fichiers sur le disque spécifié. Assurez-vous de bien sélectionner le disque cible.

    wipefs --force --all /dev/sdX  # Remplacez /dev/sdX par le disque cible, ex. /dev/sda
    bash

Écraser les données du disque

    ⚠️ Attention : Cette opération est irréversible et écrase tout le contenu du disque.

bash

sudo shred -v -n 3 -z /dev/sdX  # Remplacez /dev/sdX par le disque cible, ex. /dev/sda

Installer Git
Mettez à jour la liste des paquets et installez Git :

bash

pacman -Sy git

Cloner le dépôt
Clonez le dépôt contenant le script d'installation :

bash

git clone https://github.com/alexandre-Maury/arch-install.git

Configurer les options d'installation
Accédez au répertoire cloné et modifiez le fichier config.sh pour ajuster les options d'installation selon vos préférences :

bash

cd arch-install && nano config.sh

Exécuter le script d'installation
Rendez le script exécutable et lancez-le pour commencer l'installation :

bash

chmod +x install.sh && ./install.sh


## Feuille de route
1. `Mise en place du systeme` [En Cours]
2. `Mise en place d'un labo de developpement` [A Venir]
3. `Mise en place d'un labo de pentesting` [A Venir]

## Auteurs
`- Alexandre MAURY`

## Contribution
`- Alexandre MAURY`

## Licence

## État du projet
`- En cours de développement`