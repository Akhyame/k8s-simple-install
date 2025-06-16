#!/bin/bash

echo "🚀 Déploiement de l'application de test..."

# Vérifier que kubectl est configuré (pas besoin de root)
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ kubectl n'est pas configuré ou le cluster n'est pas accessible."
    echo "Assurez-vous d'être sur le nœud maître ou d'avoir la configuration kubectl."
    exit 1
fi

# Vérifier que le fichier manifeste existe
MANIFEST_FILE="manifests/test-app.yaml"
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "❌ Fichier $MANIFEST_FILE introuvable."
    exit 1
fi

# Déployer l'application
echo "📦 Déploiement de l'application..."
if kubectl apply -f "$MANIFEST_FILE"; then
    echo "✅ Application déployée avec succès"
else
    echo "❌ Échec du déploiement"
    exit 1
fi

# Attendre que les pods soient prêts
echo "⏳ Attente du démarrage des pods..."
kubectl wait --for=condition=Ready pods -l app=test-app --timeout=300s

# Vérifier le déploiement
echo "🔍 État du déploiement:"
kubectl get pods -o wide
echo ""
kubectl get services

# Obtenir l'IP des nœuds et le port du service
echo ""
echo "🌐 Informations d'accès:"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
fi

NODE_PORT=$(kubectl get service test-app-service -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null || echo "30002")

echo "URL d'accès: http://$NODE_IP:$NODE_PORT"
echo ""
echo "📋 Commandes utiles:"
echo "- Voir les logs: kubectl logs -l app=test-app"
echo "- Supprimer l'app: kubectl delete -f $MANIFEST_FILE"
