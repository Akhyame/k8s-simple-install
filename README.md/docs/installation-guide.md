# Guide d'Installation Kubernetes Simple

## Préparation des Machines
- Assurez-vous que vous disposez de trois machines Ubuntu 20.04.
- Configurez la connectivité réseau entre les machines.
- Activez l'accès SSH avec sudo sur toutes les machines.

## Comment Utiliser
1. **Exécuter `common-setup.sh` sur toutes les machines** :
   ```bash
   sudo ./scripts/common-setup.sh

# Exécuter install-master.sh sur le Master :
sudo ./scripts/install-master.sh

# Exécuter install-worker.sh sur les workers :
sudo ./scripts/install-worker.sh

# Dans master déployer l'application test :
sudo ./scripts/deploy-test-app.sh
