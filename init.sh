#!/bin/bash

# Homelab K3s Cluster Initialization Script
# This script sets up a complete K3s homelab environment with ArgoCD, Longhorn, and MetalLB

set -e

echo "🚀 Starting K3s Homelab Initialization..."
echo "=========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to generate secure passwords
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Step 1: Generate and set environment variables for applications
print_status "🔐 Step 1: Setting up application passwords..."

# Generate secure passwords
POSTGRES_PASSWORD=$(generate_password)
ADGUARD_PASSWORD=$(generate_password)

echo "Generated passwords:"
echo "  PostgreSQL: $POSTGRES_PASSWORD"
echo "  AdGuard: $ADGUARD_PASSWORD"

# Create environment file
ENV_FILE="$HOME/.homelab_env"
cat > "$ENV_FILE" << EOF
# Homelab Environment Variables
# Generated on $(date)
export POSTGRES_PASSWORD="$POSTGRES_PASSWORD"
export ADGUARD_PASSWORD="$ADGUARD_PASSWORD"
EOF

# Add to bashrc if not already present
if ! grep -q "source $ENV_FILE" ~/.bashrc; then
    echo "source $ENV_FILE" >> ~/.bashrc
fi

# Source the environment file
source "$ENV_FILE"

print_success "Environment variables configured in $ENV_FILE"

# Step 2: Install K3s
print_status "📦 Step 2: Installing K3s..."

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --disable traefik \
    --disable servicelb \
    --disable local-storage \
    --write-kubeconfig-mode 644 \
    --cluster-init" sh -

print_success "K3s installed"

echo "⏳ Waiting for K3s to start..."
sleep 30

# Step 3: Setup kubeconfig
print_status "🔧 Step 3: Setting up kubeconfig..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(whoami):$(whoami) ~/.kube/config
export KUBECONFIG=~/.kube/config

# Verify K3s is running
print_status "🔍 Verifying K3s installation..."
kubectl get nodes
kubectl get pods -A

print_success "K3s cluster is running"

# Step 4: Install Longhorn for storage
print_status "🗄️  Step 4: Installing Longhorn storage..."
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml

echo "⏳ Waiting for Longhorn to be ready..."
kubectl wait --namespace longhorn-system \
    --for=condition=ready pod \
    --selector=app=longhorn-manager \
    --timeout=300s || true

print_success "Longhorn storage installed"

# Step 5: Install MetalLB
print_status "🌐 Step 5: Installing MetalLB..."
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml

echo "⏳ Waiting for MetalLB to be ready..."
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=180s

print_success "MetalLB installed"

# Step 6: Configure MetalLB IP pool
print_status "🔧 Step 6: Configuring MetalLB IP pool..."

# Detect network automatically
DEFAULT_ROUTE=$(ip route | grep default | head -n1)
GATEWAY_IP=$(echo $DEFAULT_ROUTE | awk '{print $3}')
INTERFACE=$(echo $DEFAULT_ROUTE | awk '{print $5}')
NETWORK=$(ip route | grep "$INTERFACE" | grep -v default | head -n1 | awk '{print $1}')

echo "🔍 Detected network configuration:"
echo "   Gateway: $GATEWAY_IP"
echo "   Interface: $INTERFACE"
echo "   Network: $NETWORK"

# Extract base IP for pool
BASE_IP=$(echo $GATEWAY_IP | cut -d. -f1-3)
POOL_START="${BASE_IP}.240"
POOL_END="${BASE_IP}.250"

echo "📡 Creating IP pool: $POOL_START-$POOL_END"

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab-pool
  namespace: metallb-system
spec:
  addresses:
  - $POOL_START-$POOL_END
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: homelab-advertisement
  namespace: metallb-system
spec:
  ipAddressPools:
  - homelab-pool
EOF

print_success "MetalLB IP pool configured: $POOL_START-$POOL_END"

# Step 7: Install ArgoCD
print_status "🚀 Step 7: Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --namespace argocd \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=argocd-server \
    --timeout=300s

# Create ArgoCD LoadBalancer service
print_status "🌐 Creating ArgoCD LoadBalancer service..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-server-lb
  namespace: argocd
  labels:
    app.kubernetes.io/component: server
    app.kubernetes.io/name: argocd-server
spec:
  type: LoadBalancer
  ports:
  - name: server
    port: 80
    targetPort: 8080
    protocol: TCP
  selector:
    app.kubernetes.io/name: argocd-server
EOF

print_success "ArgoCD installed"

# Step 8: Create Kubernetes secrets for applications
print_status "🔐 Step 8: Creating Kubernetes secrets..."

# Create namespace for database
kubectl create namespace database || true

# Create PostgreSQL secret
kubectl create secret generic postgres-env-secret-prod \
    --namespace=database \
    --from-literal=POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create namespace for network
kubectl create namespace network || true

# Create AdGuard secret
kubectl create secret generic adguard-env-secret-prod \
    --namespace=network \
    --from-literal=ADGUARD_PASSWORD="$ADGUARD_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

print_success "Kubernetes secrets created"

# Step 9: Get ArgoCD admin password
print_status "🔐 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Step 10: Wait for LoadBalancer IP
print_status "⏳ Waiting for ArgoCD LoadBalancer IP..."
sleep 30
ARGOCD_IP=""
for i in {1..30}; do
    ARGOCD_IP=$(kubectl get svc argocd-server-lb -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ ! -z "$ARGOCD_IP" ]; then
        break
    fi
    echo "   Waiting for IP assignment... ($i/30)"
    sleep 10
done

# Step 11: Create summary file
SUMMARY_FILE="$HOME/homelab-summary.txt"
cat > "$SUMMARY_FILE" << EOF
🎉 K3s Homelab Setup Complete! 🎉
==================================

📊 Cluster Status:
$(kubectl get nodes)

🌐 Network Configuration:
   IP Pool Range: $POOL_START-$POOL_END
   Gateway: $GATEWAY_IP

🚀 ArgoCD Access:
$(if [ ! -z "$ARGOCD_IP" ]; then
    echo "   URL: http://$ARGOCD_IP"
else
    echo "   URL: Run 'kubectl get svc argocd-server-lb -n argocd' to get IP"
fi)
   Username: admin
   Password: $ARGOCD_PASSWORD

🔐 Application Passwords:
   PostgreSQL: $POSTGRES_PASSWORD
   AdGuard: $ADGUARD_PASSWORD

💾 Storage:
   Longhorn UI: kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
   Then visit: http://localhost:8080

🔧 Useful Commands:
   kubectl get pods -A                    # Check all pods
   kubectl get svc -A                     # Check all services
   kubectl get pv                         # Check persistent volumes
   source $ENV_FILE                       # Load environment variables

📝 Next Steps:
1. Access ArgoCD and set up your applications
2. Deploy the app-of-apps: kubectl apply -f applications/app-of-apps.yaml
3. Each app will get its own LoadBalancer IP
4. Use 'longhorn' as storageClass in your PVCs

⚡ Ready to deploy your homelab applications!
EOF

# Final status
echo ""
print_success "K3s Homelab Setup Complete! 🎉"
echo "=================================="
echo ""
echo "📊 Cluster Status:"
kubectl get nodes
echo ""
echo "🌐 Network Configuration:"
echo "   IP Pool Range: $POOL_START-$POOL_END"
echo "   Gateway: $GATEWAY_IP"
echo ""
echo "🚀 ArgoCD Access:"
if [ ! -z "$ARGOCD_IP" ]; then
    echo "   URL: http://$ARGOCD_IP"
else
    echo "   URL: Run 'kubectl get svc argocd-server-lb -n argocd' to get IP"
fi
echo "   Username: admin"
echo "   Password: $ARGOCD_PASSWORD"
echo ""
echo "🔐 Application Passwords (saved in $ENV_FILE):"
echo "   PostgreSQL: $POSTGRES_PASSWORD"
echo "   AdGuard: $ADGUARD_PASSWORD"
echo ""
echo "💾 Storage:"
echo "   Longhorn UI: kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"
echo "   Then visit: http://localhost:8080"
echo ""
echo "🔧 Useful Commands:"
echo "   kubectl get pods -A                    # Check all pods"
echo "   kubectl get svc -A                     # Check all services"
echo "   kubectl get pv                         # Check persistent volumes"
echo "   source $ENV_FILE                       # Load environment variables"
echo ""
echo "📝 Next Steps:"
echo "1. Access ArgoCD and set up your applications"
echo "2. Deploy the app-of-apps:"
echo "   kubectl apply -f applications/app-of-apps.yaml"
echo "3. Each app will get its own LoadBalancer IP"
echo "4. Use 'longhorn' as storageClass in your PVCs"
echo ""
print_success "Summary saved to: $SUMMARY_FILE"
echo ""
print_success "⚡ Ready to deploy your homelab applications!"

# Set executable permissions and completion message
chmod +x "$0" 2>/dev/null || true

echo ""
print_warning "Important Notes:"
echo "• Environment variables are loaded in: $ENV_FILE"
echo "• Kubernetes secrets are created in their respective namespaces"
echo "• Run 'source ~/.bashrc' or restart your terminal to load environment variables"
echo "• Your homelab setup is now ready for ArgoCD deployments!"