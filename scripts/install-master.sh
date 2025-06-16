#!/bin/bash

# =============================================================================
# Script d'initialisation du cluster Kubernetes maître
# =============================================================================
# Ce script initialise un nœud maître Kubernetes après l'installation des
# composants de base (kubeadm, kubelet, kubectl, Docker)
#
# Prérequis: 
# - Système Ubuntu avec Kubernetes et Docker installés
# - Script d'installation précédent exécuté avec succès
# - Système redémarré après l'installation
#
# Usage: sudo ./init-kubernetes-master.sh
# =============================================================================

set -e  # Arrêter le script en cas d'erreur

echo "🚀 Initialisation du cluster Kubernetes maître..."

# =============================================================================
# 1. VÉRIFICATIONS PRÉLIMINAIRES
# =============================================================================

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Veuillez exécuter ce script avec sudo."
    echo "Usage: sudo $0"
    exit 1
fi

# Obtenir l'utilisateur réel (pas root) pour la configuration kubectl
REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || whoami)}
if [ "$REAL_USER" = "root" ]; then
    echo "⚠️  Impossible de déterminer l'utilisateur réel."
    read -p "Nom d'utilisateur pour la configuration kubectl: " REAL_USER
fi

# Obtenir le répertoire home de l'utilisateur réel
USER_HOME=$(eval echo "~$REAL_USER")

echo "👤 Utilisateur détecté: $REAL_USER"
echo "🏠 Répertoire home: $USER_HOME"

# Vérifier que les composants Kubernetes sont installés
echo "🔍 Vérification des prérequis..."
if ! command -v kubeadm &> /dev/null; then
    echo "❌ kubeadm n'est pas installé. Exécutez d'abord le script d'installation."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl n'est pas installé. Exécutez d'abord le script d'installation."
    exit 1
fi

if ! systemctl is-active --quiet docker; then
    echo "❌ Docker n'est pas en cours d'exécution."
    exit 1
fi

echo "✅ Tous les prérequis sont satisfaits"

# =============================================================================
# 2. INITIALISATION DU CLUSTER MAÎTRE
# =============================================================================

echo "☸️  Initialisation du nœud maître Kubernetes..."
echo "   - Configuration du réseau pods: 10.244.0.0/16 (compatible Flannel)"
echo "   - Cette opération peut prendre plusieurs minutes..."

# Initialiser le cluster avec kubeadm
# --pod-network-cidr: Définit la plage d'adresses IP pour les pods (requis pour Flannel)
# --apiserver-advertise-address: Peut être ajouté si nécessaire pour spécifier l'IP
kubeadm init --pod-network-cidr=10.244.0.0/16

echo "✅ Cluster maître initialisé avec succès"

# =============================================================================
# 3. CONFIGURATION DE KUBECTL POUR L'UTILISATEUR
# =============================================================================

echo "🔧 Configuration de kubectl pour l'utilisateur $REAL_USER..."

# Créer le répertoire .kube dans le home de l'utilisateur réel
mkdir -p "$USER_HOME/.kube"

# Copier le fichier de configuration admin vers le répertoire utilisateur
cp -i /etc/kubernetes/admin.conf "$USER_HOME/.kube/config"

# Changer le propriétaire du fichier de configuration
chown "$REAL_USER:$REAL_USER" "$USER_HOME/.kube/config"

# Définir les permissions appropriées (lecture/écriture pour le propriétaire uniquement)
chmod 600 "$USER_HOME/.kube/config"

echo "✅ kubectl configuré pour l'utilisateur $REAL_USER"

# =============================================================================
# 4. INSTALLATION DU PLUGIN RÉSEAU FLANNEL
# =============================================================================

echo "🌐 Installation du plugin réseau Flannel..."
echo "   - Flannel permet la communication entre les pods sur différents nœuds"

# Utiliser l'URL officielle mise à jour de Flannel
# Alternative: utiliser une version spécifique pour la stabilité
FLANNEL_URL="https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml"

# Appliquer la configuration Flannel en tant qu'utilisateur réel
sudo -u "$REAL_USER" kubectl apply -f "$FLANNEL_URL"

echo "✅ Plugin réseau Flannel installé"

# =============================================================================
# 5. ATTENDRE QUE LE CLUSTER SOIT PRÊT
# =============================================================================

echo "⏳ Attente du démarrage des composants système..."

# Attendre que tous les pods système soient prêts (timeout de 5 minutes)
sudo -u "$REAL_USER" kubectl wait --for=condition=Ready pods --all -n kube-system --timeout=300s

echo "✅ Tous les pods système sont opérationnels"

# =============================================================================
# 6. GÉNÉRATION DU TOKEN DE JOINTURE POUR LES WORKERS
# =============================================================================

echo "🔑 Génération du token de jointure pour les nœuds workers..."

# Créer un nouveau token avec la commande de jointure complète
JOIN_COMMAND=$(kubeadm token create --print-join-command)

# Sauvegarder la commande dans un fichier accessible
JOIN_FILE="/tmp/kubernetes-join-command.txt"
echo "$JOIN_COMMAND" > "$JOIN_FILE"

# Rendre le fichier lisible par l'utilisateur
chown "$REAL_USER:$REAL_USER" "$JOIN_FILE"
chmod 644 "$JOIN_FILE"

echo "✅ Token de jointure généré et sauvegardé dans: $JOIN_FILE"

# =============================================================================
# 7. PERMETTRE L'EXÉCUTION DE PODS SUR LE NŒUD MAÎTRE (OPTIONNEL)
# =============================================================================

echo "🤔 Configuration du nœud maître..."
read -p "Voulez-vous permettre l'exécution de pods sur le nœud maître? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   - Suppression du taint 'master' du nœud..."
    sudo -u "$REAL_USER" kubectl taint nodes --all node-role.kubernetes.io/control-plane-
    echo "✅ Le nœud maître peut maintenant exécuter des pods utilisateur"
else
    echo "ℹ️  Le nœud maître restera dédié aux composants système"
fi

# =============================================================================
# 8. VÉRIFICATIONS FINALES ET INFORMATIONS
# =============================================================================

echo ""
echo "🔍 Vérification finale du cluster..."

# Afficher l'état des nœuds
echo "📋 État des nœuds:"
sudo -u "$REAL_USER" kubectl get nodes -o wide

echo ""
echo "📋 État des pods système:"
sudo -u "$REAL_USER" kubectl get pods --all-namespaces

echo ""
echo "📋 Informations du cluster:"
sudo -u "$REAL_USER" kubectl cluster-info

# =============================================================================
# 9. INSTRUCTIONS FINALES
# =============================================================================

echo ""
echo "🎉 Initialisation du cluster Kubernetes terminée avec succès!"
echo ""
echo "📋 Informations importantes:"
echo "┌─────────────────────────────────────────────────────────────────┐"
echo "│ Configuration kubectl: $USER_HOME/.kube/config"
echo "│ Token de jointure: $JOIN_FILE"
echo "│ Réseau des pods: 10.244.0.0/16"
echo "└─────────────────────────────────────────────────────────────────┘"
echo ""
echo "📝 Prochaines étapes:"
echo "1. Pour ajouter un nœud worker, exécutez sur le worker:"
echo "   $(cat $JOIN_FILE)"
echo ""
echo "2. Pour utiliser kubectl en tant qu'utilisateur normal:"
echo "   su - $REAL_USER"
echo "   kubectl get nodes"
echo ""
echo "3. Pour déployer une application test:"
echo "   kubectl create deployment nginx --image=nginx"
echo "   kubectl expose deployment nginx --port=80 --type=NodePort"
echo ""
echo "4. Pour surveiller les ressources:"
echo "   kubectl top nodes  # (nécessite metrics-server)"
echo "   kubectl get events --sort-by=.metadata.creationTimestamp"
echo ""
echo "🔗 Ressources utiles:"
echo "   - Documentation Kubernetes: https://kubernetes.io/docs/"
echo "   - Flannel: https://github.com/flannel-io/flannel"
echo "   - Troubleshooting: kubectl describe nodes"
echo ""
echo "✅ Le cluster est prêt à accueillir vos applications!"
