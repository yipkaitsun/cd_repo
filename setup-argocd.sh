#!/bin/bash

# ArgoCD Quick Setup Script
# This script installs ArgoCD on your Kubernetes cluster

set -e

echo "================================================"
echo "ArgoCD Quick Setup"
echo "================================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster."
    echo "Please configure kubectl to connect to your cluster."
    exit 1
fi

echo "✅ Kubernetes cluster accessible"
echo ""

# Step 1: Create namespace
echo "Step 1: Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace created"
echo ""

# Step 2: Install ArgoCD
echo "Step 2: Installing ArgoCD..."
echo "This will take 2-3 minutes..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s

echo "✅ ArgoCD installed successfully"
echo ""

# Step 3: Get admin password
echo "Step 3: Retrieving admin credentials..."
echo ""
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "================================================"
echo "✅ ArgoCD Installation Complete!"
echo "================================================"
echo ""
echo "Access ArgoCD UI:"
echo ""
echo "1. Run port-forward in a separate terminal:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Open your browser:"
echo "   https://localhost:8080"
echo ""
echo "3. Login credentials:"
echo "   Username: admin"
echo "   Password: $ADMIN_PASSWORD"
echo ""
echo "================================================"
echo ""

# Step 4: Optional - Install ArgoCD CLI
echo "Do you want to install ArgoCD CLI? (y/n)"
read -p "Choice: " install_cli

if [[ "$install_cli" == "y" || "$install_cli" == "Y" ]]; then
    echo ""
    echo "Installing ArgoCD CLI..."
    
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    if [[ "$ARCH" == "x86_64" ]]; then
        ARCH="amd64"
    elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        ARCH="arm64"
    fi
    
    if [[ "$OS" == "darwin" ]]; then
        if command -v brew &> /dev/null; then
            echo "Installing via Homebrew..."
            brew install argocd
        else
            echo "Downloading binary..."
            curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-$ARCH
            chmod +x /usr/local/bin/argocd
        fi
    elif [[ "$OS" == "linux" ]]; then
        echo "Downloading binary..."
        sudo curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-$ARCH
        sudo chmod +x /usr/local/bin/argocd
    else
        echo "⚠️  Please install ArgoCD CLI manually from:"
        echo "   https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    fi
    
    if command -v argocd &> /dev/null; then
        echo "✅ ArgoCD CLI installed: $(argocd version --client --short)"
    fi
fi

echo ""
echo "================================================"
echo "Next Steps:"
echo "================================================"
echo ""
echo "1. Start port-forward:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "2. Deploy your VPN infrastructure:"
echo "   kubectl apply -f argocd-vpn-dev.yaml"
echo "   kubectl apply -f argocd-vpn-prod.yaml"
echo ""
echo "3. Deploy your Quarkus apps:"
echo "   kubectl apply -f argocd-app-dev.yaml"
echo "   kubectl apply -f argocd-app-prod.yaml"
echo ""
echo "4. View applications in ArgoCD UI:"
echo "   https://localhost:8080"
echo ""
echo "For more details, see: ARGOCD-SETUP.md"
echo ""

