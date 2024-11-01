#!/bin/bash

# Configuration
SERVER_USER="votre_utilisateur"  # Remplacez par l'utilisateur distant
SERVER_IP="adresse_ip_du_serveur"  # Remplacez par l'adresse IP ou le nom d'hôte du serveur
SSH_PORT=2222  # Remplacez par le port SSH configuré sur le serveur

# Générer une paire de clés SSH si elle n'existe pas
if [ ! -f ~/.ssh/id_rsa ]; then
  echo "Génération d'une nouvelle paire de clés SSH..."
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""  # Génère une clé RSA de 4096 bits sans mot de passe
else
  echo "La paire de clés SSH existe déjà, utilisation de la clé actuelle."
fi

# Copier la clé publique sur le serveur
echo "Copie de la clé publique sur le serveur distant..."
ssh-copy-id -i ~/.ssh/id_rsa.pub -p $SSH_PORT "$SERVER_USER@$SERVER_IP"

# Configurer le serveur pour utiliser uniquement l'authentification par clé publique
echo "Configuration du serveur pour n'autoriser que l'authentification par clé publique..."
ssh -p $SSH_PORT "$SERVER_USER@$SERVER_IP" "sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && sudo systemctl restart sshd"

echo "Configuration terminée ! Vous pouvez maintenant vous connecter au serveur avec la commande suivante :"
echo "ssh -p $SSH_PORT $SERVER_USER@$SERVER_IP"


# Explications détaillées des étapes :

#     Définition des variables :
#         SERVER_USER : Nom de l’utilisateur distant pour se connecter au serveur.
#         SERVER_IP : Adresse IP ou nom de domaine du serveur distant.
#         SSH_PORT : Port SSH configuré sur le serveur pour l'authentification (par défaut 22 ou celui que vous avez spécifié).

#     Génération de la paire de clés SSH :
#         Si la paire de clés SSH (fichier ~/.ssh/id_rsa) n’existe pas sur la machine locale, le script en génère une.
#         La commande ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" crée une clé RSA de 4096 bits sans mot de passe.

#     Copie de la clé publique sur le serveur :
#         ssh-copy-id est utilisé pour copier automatiquement la clé publique sur le serveur et configurer les autorisations.
#         La clé est copiée dans le fichier ~/.ssh/authorized_keys sur le serveur, permettant l’accès sans mot de passe.

#     Configurer le serveur pour n'accepter que l'authentification par clé publique :
#         Utilise sed pour désactiver l’authentification par mot de passe (PasswordAuthentication no) dans le fichier de configuration SSH sur le serveur.
#         Redémarre le service SSH pour appliquer les changements.