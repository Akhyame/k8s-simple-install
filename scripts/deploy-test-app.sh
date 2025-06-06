#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo."
  exit 1
fi

# Déployer l'application test
kubectl apply -f manifests/test-app.yaml

# Vérifier le déploiement
kubectl get pods
kubectl get services

# Tester l'accès à l'application
echo "Accédez à l'application via http://<IP-worker>:30002"
