#!/bin/bash

# script install.sh

# https://github.com/Senshi111/debian-hyprland-hyprdots
# https://github.com/nawfalmrouyan/hyprland

set -e  # Quitte immédiatement en cas d'erreur.

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source $SCRIPT_DIR/misc/config/config.sh # Inclure le fichier de configuration.
source $SCRIPT_DIR/misc/scripts/functions.sh  # Charge les fonctions définies dans le fichier fonction.sh.

