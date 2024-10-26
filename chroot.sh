#!/usr/bin/env bash







##############################################################################
## Configuration de PAM                                  
##############################################################################
log_prompt "INFO" && echo "Configuration de passwdqc.conf" && echo ""

# Sauvegarde de l'ancien fichier passwdqc.conf
if [ -f "$PASSWDQC_CONF" ]; then
    cp "$PASSWDQC_CONF" "$PASSWDQC_CONF.bak"
    log_prompt "INFO" && echo "Sauvegarde du fichier existant passwdqc.conf en $PASSWDQC_CONF.bak" && echo ""
fi

# Génération du nouveau contenu de passwdqc.conf
cat <<EOF > "$PASSWDQC_CONF"
min=$MIN
max=$MAX
passphrase=$PASSPHRASE
match=$MATCH
similar=$SIMILAR
enforce=$ENFORCE
retry=$RETRY
EOF

# Vérification du succès
if [ $? -eq 0 ]; then
    log_prompt "INFO" && echo "Fichier passwdqc.conf mis à jour avec succès." && echo ""
    cat "$PASSWDQC_CONF"
    log_prompt "SUCCESS" && echo "Terminée" && echo ""

else
    log_prompt "ERROR" && echo "Erreur lors de la mise à jour du fichier passwdqc.conf." && echo ""
fi










