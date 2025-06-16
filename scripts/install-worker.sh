#!/bin/bash

# Vérifier si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Veuillez exécuter ce script avec sudo."
    exit 1
fi

echo "🔗 Jointure du nœud worker au cluster Kubernetes..."

# Vérifier que le fichier de jointure existe
JOIN_FILE="/tmp/join-command.txt"
if [ ! -f "$JOIN_FILE" ]; then
    echo "❌ Fichier $JOIN_FILE introuvable."
    echo "Copiez le fichier depuis le nœud maître ou générez un nouveau token."
    exit 1
fi

# Lire et afficher la commande de jointure
JOIN_COMMAND=$(cat "$JOIN_FILE")
echo "📋 Commande de jointure: $JOIN_COMMAND"

# Joindre le worker au cluster
echo "⏳ Jointure en cours..."
if $JOIN_COMMAND; then
    echo "✅ Nœud worker joint au cluster avec succès!"
else
    echo "❌ Échec de la jointure au cluster."
    exit 1
fi

# Vérifier que kubelet fonctionne
echo "🔍 Vérification du service kubelet..."
if systemctl is-active --quiet kubelet; then
    echo "✅ kubelet est actif et fonctionne"
else
    echo "⚠️  kubelet n'est pas actif"
    systemctl status kubelet
fi

echo ""
echo "🎉 Configuration du worker terminée!"
echo "📝 Pour vérifier l'état du nœud, exécutez sur le MAÎTRE:"
echo "   kubectl get nodes"
echo "   kubectl describe node $(hostname)"
