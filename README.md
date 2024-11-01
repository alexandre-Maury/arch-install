# `arch-install`

## Description
Le projet est un ensemble de configurations et de scripts pour installer et configurer Hyprland sur une base arch linux.
L'objectif est de mettre en place un environnement de développement + versionning ainsi qu'un environnement de pentesting.

Il utilise principalement Ansible pour l'automatisation, avec des rôles et des scripts spécifiques pour différents aspects de l'environnement.

## Visuels
À venir

## Installation

Procédez aux étapes suivantes :

1. Télécharger le support d'installation : `https://archlinux.org/download/`
2. Changer la disposition du clavier : `loadkeys fr`
3. Attention : efface toutes les signatures de système de fichiers : `wipefs --force --all "ex. /dev/sda"`
4. Attention : écrase les données sur le disque : `shred -v -n "ex. 3" -z "ex. /dev/sda"`
5. Installation du paquet git : `pacman -Sy git`
6. Clone du rep : `git clone https://github.com/alexandre-Maury/arch-install.git`
7. Configuration des options : `cd arch-install && config.sh`
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