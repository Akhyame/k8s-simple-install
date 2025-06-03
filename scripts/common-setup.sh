#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script avec sudo."
  exit 1
fi

# Désactiver SWAP
# Dans GitHub Codespaces, le SWAP n'est pas activé par défaut, donc cette étape peut être ignorée.
# sudo swapoff -a
# sudo sed -i '/swap/d' /etc/fstab

# Ajouter le nom de domaine complet (FQDN) dans /etc/hosts
# Dans Codespaces, l'hostname et les hôtes sont déjà configurés automatiquement.
# sudo hostnamectl set-hostname $HOSTNAME
# echo "127.0.0.1 localhost $(hostname)" | sudo tee -a /etc/hosts

# Activer IP forwarding
# Ces paramètres sont généralement configurés par défaut dans Codespaces.
# cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
# net.bridge.bridge-nf-call-ip6tables = 1
# net.bridge.bridge-nf-call-iptables = 1
# EOF
# sudo sysctl --system

# Installer Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter le groupe docker au utilisateur actuel
sudo usermod -aG docker $USER
newgrp docker

# Installer kubeadm, kubelet, kubectl
sudo apt update
sudo apt install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg  | sudo apt-key add -
echo "deb https://apt.kubernetes.io/  kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# Redémarrer le système
# Ne redémarre pas le système dans Codespaces, car cela annulerait la session.
# sudo reboot
