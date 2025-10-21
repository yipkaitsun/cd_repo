#!/bin/bash

# Script to copy TLS certificate from keycloak namespace to vpn namespace
# This allows Pi-hole to use the same wildcard certificate

echo "Copying noip-tls-secret from keycloak namespace to vpn namespace..."

# Check if secret exists in source namespace
if ! kubectl get secret noip-tls-secret -n keycloak &> /dev/null; then
    echo "❌ Error: noip-tls-secret not found in keycloak namespace"
    echo "Please ensure the certificate is created in keycloak namespace first."
    exit 1
fi

# Create vpn namespace if it doesn't exist
kubectl create namespace vpn --dry-run=client -o yaml | kubectl apply -f -

# Copy the secret
kubectl get secret noip-tls-secret -n keycloak -o yaml | \
  sed 's/namespace: keycloak/namespace: vpn/' | \
  kubectl apply -f -

# Verify
if kubectl get secret noip-tls-secret -n vpn &> /dev/null; then
    echo "✅ Successfully copied noip-tls-secret to vpn namespace"
    echo ""
    echo "The Pi-hole ingress can now use HTTPS with the shared certificate."
    echo ""
    echo "Access Pi-hole at: https://pihole.ykt-piserver.zapto.org/admin"
else
    echo "❌ Failed to copy secret"
    exit 1
fi

