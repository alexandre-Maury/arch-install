# `arch-install`

## Description
Le projet vise à installer et configurer Hyprland sur une base arch linux.
L'objectif est de mettre en place un environnement de développement ainsi qu'un environnement de pentesting.

## Visuels
À venir

## Installation

Procédez aux étapes suivantes :

1. Télécharger le support d'installation : `https://archlinux.org/download/`
2. Changer la disposition du clavier : `loadkeys fr`
3. Attention : efface toutes les signatures de système de fichiers : `wipefs --force --all "ex. /dev/sda"`
4. Attention : écrase les données sur le disque : `shred -v -n "ex. 3" -z "ex. /dev/sda"`
5. Installation du paquet git : `pacman -Sy git`
6. Clone du repo : `git clone https://github.com/alexandre-Maury/arch-install.git`
7. Configuration des options : `cd arch-install && nano config.sh`
8. Exécution du script : `chmod +x install.sh && ./install.sh`


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