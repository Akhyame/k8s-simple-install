#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo."
  exit 1
fi

# Lire le token de jointure depuis le fichier
JOIN_COMMAND=$(cat /tmp/join-command.txt)

# Joindre le worker au cluster
sudo $JOIN_COMMAND

# Vérifier le bon fonctionnement du worker
kubectl get nodes
kubectl get pods --all-namespaces
