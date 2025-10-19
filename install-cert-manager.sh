#!/bin/bash
# Install cert-manager and Let's Encrypt on K3s

set -e

echo "🔐 Installing cert-manager for Let's Encrypt certificates..."

# Install cert-manager
echo "📦 Installing cert-manager..."
sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
echo "⏳ Waiting for cert-manager to be ready..."
sudo kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

echo "✅ cert-manager installed successfully!"

# Verify installation
echo ""
echo "📊 cert-manager pods:"
sudo kubectl get pods -n cert-manager

# Prompt for email
echo ""
echo "📧 Enter your email for Let's Encrypt notifications:"
read -p "Email: " email

if [ -z "$email" ]; then
  echo "❌ Email is required for Let's Encrypt"
  exit 1
fi

# Create Let's Encrypt ClusterIssuer
echo ""
echo "🌍 Creating Let's Encrypt ClusterIssuer..."
cat <<EOF | sudo kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

echo "✅ Let's Encrypt ClusterIssuer created!"

# Verify issuer
echo ""
echo "📊 ClusterIssuer status:"
sudo kubectl get clusterissuer letsencrypt-prod

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Push keycloak manifests to Git"
echo "2. Apply ArgoCD application: sudo kubectl apply -f argocd-keycloak-noip.yaml"
echo "3. Sync: argocd app sync keycloak-noip"
echo "4. Wait for certificate: sudo kubectl get certificate -n keycloak -w"
echo "5. Access: https://ykt-piserver.zapto.org/"

