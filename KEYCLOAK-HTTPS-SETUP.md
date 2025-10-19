# 🔐 Keycloak HTTPS Setup

This guide shows how to enable HTTPS for Keycloak with a self-signed certificate.

## 📋 Prerequisites

- K3s cluster running
- Keycloak deployed via ArgoCD
- SSH access to K3s server

---

## 🚀 Quick Setup

### On Your K3s Server

```bash
# 1. Copy the script to your K3s server
scp -i "aws_key.pem" generate-keycloak-tls.sh ec2-user@ec2-18-183-57-208.ap-northeast-1.compute.amazonaws.com:~

# 2. SSH into your K3s server
ssh -i "aws_key.pem" ec2-user@ec2-18-183-57-208.ap-northeast-1.compute.amazonaws.com

# 3. Run the certificate generation script
chmod +x generate-keycloak-tls.sh
./generate-keycloak-tls.sh 18.183.57.208

# 4. Sync ArgoCD to apply HTTPS configuration
argocd app sync keycloak-dev

# 5. Wait for rollout
kubectl rollout status deployment/keycloak -n keycloak

# 6. Check service
kubectl get svc -n keycloak keycloak
```

---

## 🌐 Access URLs

After setup:

| Protocol | URL | Port |
|----------|-----|------|
| **HTTPS** | `https://18.183.57.208:8443/` | 8443 |
| HTTP | `http://18.183.57.208:8081/` | 8081 |

---

## ⚠️ Browser Security Warning

Since this is a **self-signed certificate**, your browser will show a security warning:

### Chrome/Edge:
1. You'll see "Your connection is not private"
2. Click **"Advanced"**
3. Click **"Proceed to 18.183.57.208 (unsafe)"**

### Firefox:
1. You'll see "Warning: Potential Security Risk Ahead"
2. Click **"Advanced..."**
3. Click **"Accept the Risk and Continue"**

### Safari:
1. You'll see "This Connection Is Not Private"
2. Click **"Show Details"**
3. Click **"visit this website"**
4. Click **"Visit Website"** in the popup

---

## ✅ Verify HTTPS is Working

```bash
# Test HTTPS endpoint (will show certificate error)
curl -k https://18.183.57.208:8443/

# Check certificate details
openssl s_client -connect 18.183.57.208:8443 -showcerts

# Test HTTP endpoint (still works)
curl http://18.183.57.208:8081/
```

---

## 🔧 Troubleshooting

### Check if TLS secret exists
```bash
kubectl get secret keycloak-tls -n keycloak
```

### View certificate
```bash
kubectl get secret keycloak-tls -n keycloak -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Check Keycloak logs
```bash
kubectl logs -n keycloak -l app=keycloak --tail=100
```

### Regenerate certificate
```bash
# Delete old secret
kubectl delete secret keycloak-tls -n keycloak

# Run script again
./generate-keycloak-tls.sh 18.183.57.208
```

---

## 🎯 Option 2: Use a Domain Name + Let's Encrypt (Recommended for Production)

For a **trusted certificate** without browser warnings:

### Prerequisites
1. Get a domain name (e.g., `keycloak.yourdomain.com`)
2. Point DNS A record to `18.183.57.208`
3. Install cert-manager

### Setup Steps

```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Create Let's Encrypt issuer
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # Change this
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# 3. Update Ingress to request certificate
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - keycloak.yourdomain.com
    secretName: keycloak-tls-cert
  rules:
  - host: keycloak.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
EOF
```

---

## 📊 Ports Summary

| Service | HTTP Port | HTTPS Port |
|---------|-----------|------------|
| Quarkus | 80 | - |
| Keycloak | 8081 | **8443** |
| Jenkins | 8080 | - |

---

## 🔒 Security Notes

1. **Self-signed certificates** are OK for:
   - Development/testing
   - Internal networks
   - Learning purposes

2. **Let's Encrypt certificates** are needed for:
   - Production environments
   - Public-facing services
   - When you need trusted certificates

3. **Always use HTTPS** for:
   - Login pages
   - Admin interfaces
   - Sensitive data transmission

---

## 📝 What Changed

### Files Modified:
- `keycloak-manifests/overlays/dev/keycloak-patch.yaml` - Added HTTPS config
- `keycloak-manifests/overlays/dev/deployment-patch.yaml` - Added TLS volume mount
- `keycloak-manifests/overlays/dev/service-patch.yaml` - Added HTTPS port 8443
- `keycloak-manifests/overlays/dev/kustomization.yaml` - Added new patches

### New Files:
- `generate-keycloak-tls.sh` - Certificate generation script
- `KEYCLOAK-HTTPS-SETUP.md` - This documentation

---

## 🎉 Success!

Your Keycloak instance now supports HTTPS! 🔐

Access at: **https://18.183.57.208:8443/**

Login: `admin` / `dev-admin-password`

