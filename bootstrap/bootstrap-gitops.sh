#!/bin/bash
set -e

echo "Bootstrapping GitOps with ArgoCD..."

echo "Creating root application..."
kubectl apply -f ../argocd-apps/root-app.yaml

echo ""
echo "GitOps bootstrapped successfully!"
echo "ArgoCD will now manage all applications from Git repository:"
echo "https://github.com/meta-boy/homelab.git"
echo ""
echo "Monitor the sync status:"
echo "kubectl get applications -n argocd"
