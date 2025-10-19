#!/bin/bash
# Generate self-signed certificate for Keycloak HTTPS

set -e

echo "🔐 Generating self-signed TLS certificate for Keycloak..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Get the public IP (or use provided IP)
PUBLIC_IP="${1:-18.183.57.208}"

echo "📝 Using IP: $PUBLIC_IP"

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=$PUBLIC_IP/O=Keycloak" \
  -addext "subjectAltName=IP:$PUBLIC_IP"

echo "✅ Certificate generated"

# Create Kubernetes secret
echo "🔧 Creating Kubernetes secret..."
kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls keycloak-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n keycloak \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret created: keycloak-tls"

# Cleanup
cd -
rm -rf $TEMP_DIR

echo ""
echo "🎉 TLS certificate setup complete!"
echo ""
echo "📌 Next steps:"
echo "1. Sync ArgoCD: argocd app sync keycloak-dev"
echo "2. Access via HTTPS: https://18.183.57.208:8443/"
echo ""
echo "⚠️  Note: Browser will show security warning (self-signed certificate)"
echo "    Click 'Advanced' → 'Proceed to site' to continue"

