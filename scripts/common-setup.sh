#!/bin/bash

# Script d'installation Kubernetes (kubeadm, kubelet, kubectl) avec Docker
set -e  # Arrêter le script en cas d'erreur

echo "🚀 Début de l'installation Kubernetes..."

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Veuillez exécuter ce script avec sudo."
    echo "Usage: sudo $0"
    exit 1
fi

# Obtenir le nom d'utilisateur réel (pas root)
REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo $USER)}
if [ "$REAL_USER" = "root" ]; then
    echo "⚠️  Impossible de déterminer l'utilisateur réel. Veuillez spécifier manuellement."
    read -p "Nom d'utilisateur à ajouter au groupe docker: " REAL_USER
fi

echo "👤 Utilisateur détecté: $REAL_USER"

# 1. Désactiver SWAP
echo "🔄 Désactivation du SWAP..."
swapoff -a
sed -i '/swap/d' /etc/fstab
echo "✅ SWAP désactivé"

# 2. Configuration du hostname et /etc/hosts
echo "🌐 Configuration du hostname..."
CURRENT_HOSTNAME=$(hostname)
echo "127.0.0.1 localhost $CURRENT_HOSTNAME" >> /etc/hosts
echo "✅ Hostname configuré: $CURRENT_HOSTNAME"

# 3. Charger les modules kernel nécessaires
echo "🔧 Configuration des modules kernel..."
cat <<EOF > /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 4. Configuration sysctl pour Kubernetes
echo "⚙️  Configuration sysctl..."
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system > /dev/null
echo "✅ Configuration réseau appliquée"

# 5. Installer Docker
echo "🐳 Installation de Docker..."
apt update -qq
apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Ajouter la clé GPG officielle de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Ajouter le repository Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

apt update -qq
apt install -y docker-ce docker-ce-cli containerd.io

# Configurer containerd pour Kubernetes
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd
systemctl start docker
systemctl enable docker

echo "✅ Docker installé et configuré"

# 6. Ajouter l'utilisateur au groupe docker
echo "👥 Ajout de $REAL_USER au groupe docker..."
usermod -aG docker $REAL_USER
echo "✅ Utilisateur ajouté au groupe docker"

# 7. Installer kubeadm, kubelet, kubectl
echo "☸️  Installation des outils Kubernetes..."
apt update -qq
apt install -y apt-transport-https curl gpg

# Ajouter la clé GPG Kubernetes (nouvelle méthode)
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Ajouter le repository Kubernetes
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

apt update -qq
apt install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable --now kubelet

echo "✅ Kubernetes installé avec succès"

# 8. Vérification des installations
echo ""
echo "🔍 Vérification des versions installées:"
echo "Docker: $(docker --version)"
echo "kubeadm: $(kubeadm version --short)"
echo "kubelet: $(kubelet --version)"
echo "kubectl: $(kubectl version --client --short)"

echo ""
echo "✅ Installation terminée avec succès!"
echo ""
echo "📋 Prochaines étapes:"
echo "1. Redémarrez le système: sudo reboot"
echo "2. Après le redémarrage, initialisez le cluster:"
echo "   sudo kubeadm init --pod-network-cidr=10.244.0.0/16"
echo "3. Configurez kubectl pour l'utilisateur:"
echo "   mkdir -p \$HOME/.kube"
echo "   sudo cp -i /etc/kubernetes/admin.conf \$HOME/.kube/config"
echo "   sudo chown \$(id -u):\$(id -g) \$HOME/.kube/config"
echo "4. Installez un plugin réseau (ex: Flannel):"
echo "   kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

echo ""
read -p "Voulez-vous redémarrer maintenant? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Redémarrage du système..."
    reboot
else
    echo "⚠️  N'oubliez pas de redémarrer le système avant d'utiliser Kubernetes!"
fi
