#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo."
  exit 1
fi

# Initialiser le maître avec kubeadm
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# Configurer kubectl pour l'utilisateur courant
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# Installer Flannel
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml 

# Générer le token de jointure pour les workers
TOKEN=$(sudo kubeadm token create --print-join-command)

# Sauvegarder le token dans un fichier
echo "$TOKEN" > /tmp/join-command.txt

# Vérifier le bon fonctionnement du cluster
kubectl get nodes
kubectl get pods --all-namespaces
