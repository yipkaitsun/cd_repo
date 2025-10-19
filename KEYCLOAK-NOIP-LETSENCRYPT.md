# 🔐 Keycloak with No-IP Domain + Let's Encrypt

Setup guide for Keycloak with your existing No-IP domain: **`ykt-piserver.zapto.org`**

---

## 🎯 Why This Works

✅ **You already have a domain** (No-IP)  
✅ **Free trusted SSL** (Let's Encrypt)  
✅ **Auto-renewal** (cert-manager handles it)  
✅ **Works with AWS** (IAM, Cognito, OIDC)  
✅ **No CloudFlare needed** (direct to your server)  

**Total cost:** $0 (completely free!)

---

## 📋 Prerequisites

- ✅ No-IP domain: `ykt-piserver.zapto.org`
- ✅ Domain points to: `18.183.57.208`
- ✅ Keycloak running on K3s
- ✅ Port 80 accessible (for Let's Encrypt validation)
- ✅ Port 443 accessible (for HTTPS)

---

## 🔧 Verify No-IP Configuration

First, make sure your No-IP domain is working:

```bash
# Check DNS resolution
dig ykt-piserver.zapto.org

# Should show:
# ykt-piserver.zapto.org. 60 IN A 18.183.57.208

# Test if domain reaches your server
curl -I http://ykt-piserver.zapto.org/
```

### Update No-IP if Needed

If DNS doesn't resolve to `18.183.57.208`:

1. Go to [No-IP Dashboard](https://my.noip.com/#!/dynamic-dns)
2. Find `ykt-piserver.zapto.org`
3. Click **"Modify"**
4. Set IP to: `18.183.57.208`
5. Click **"Update Host"**

Wait 1-2 minutes for DNS to propagate.

---

## 🚀 Step 1: Install cert-manager

On your **K3s server**:

```bash
# SSH to K3s server
ssh -i "aws_key.pem" ec2-user@ec2-18-183-57-208.ap-northeast-1.compute.amazonaws.com

# Install cert-manager
sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready (takes 1-2 minutes)
sudo kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

# Verify installation
sudo kubectl get pods -n cert-manager
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-7d9f8c8f5-xxxxx              1/1     Running   0          1m
cert-manager-cainjector-5d7b9c8f5-xxxxx   1/1     Running   0          1m
cert-manager-webhook-6f8f8c8f5-xxxxx      1/1     Running   0          1m
```

---

## 🚀 Step 2: Create Let's Encrypt Issuer

```bash
# Create Let's Encrypt ClusterIssuer
cat <<EOF | sudo kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS to your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# Verify issuer was created
sudo kubectl get clusterissuer letsencrypt-prod
```

---

## 🚀 Step 3: Create Keycloak Ingress with TLS

Create the ingress configuration that will automatically get a Let's Encrypt certificate:

```bash
cat <<EOF | sudo kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - ykt-piserver.zapto.org
    secretName: keycloak-letsencrypt-cert
  rules:
  - host: ykt-piserver.zapto.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8081
EOF
```

---

## 🚀 Step 4: Update Keycloak Configuration

Update Keycloak to work with the ingress:

```bash
# Update ConfigMap for proper hostname and proxy settings
cat <<EOF | sudo kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
  namespace: keycloak
data:
  KC_HOSTNAME: "ykt-piserver.zapto.org"
  KC_HOSTNAME_STRICT: "false"
  KC_HTTP_ENABLED: "true"
  KC_PROXY: "edge"
  KC_HEALTH_ENABLED: "true"
  KC_METRICS_ENABLED: "true"
EOF

# Restart Keycloak to apply changes
sudo kubectl rollout restart deployment/keycloak -n keycloak

# Wait for rollout to complete
sudo kubectl rollout status deployment/keycloak -n keycloak
```

---

## 🚀 Step 5: Wait for Certificate

cert-manager will automatically request and install the certificate:

```bash
# Watch certificate creation (takes 1-3 minutes)
sudo kubectl get certificate -n keycloak -w

# You'll see:
# NAME                       READY   SECRET                     AGE
# keycloak-letsencrypt-cert  False   keycloak-letsencrypt-cert  10s
# keycloak-letsencrypt-cert  True    keycloak-letsencrypt-cert  45s

# Press Ctrl+C when READY shows "True"
```

### Check Certificate Details

```bash
# View certificate
sudo kubectl describe certificate keycloak-letsencrypt-cert -n keycloak

# Check if secret was created
sudo kubectl get secret keycloak-letsencrypt-cert -n keycloak

# View certificate expiry
sudo kubectl get certificate keycloak-letsencrypt-cert -n keycloak -o jsonpath='{.status.notAfter}'
```

---

## 🎉 Step 6: Test Your Setup

### Test DNS
```bash
# From your local machine
dig ykt-piserver.zapto.org

# Should return: 18.183.57.208
```

### Test HTTP → HTTPS Redirect
```bash
curl -I http://ykt-piserver.zapto.org/

# Should redirect to HTTPS
```

### Test HTTPS
```bash
# Should show 200 OK with Let's Encrypt certificate
curl -I https://ykt-piserver.zapto.org/

# Check certificate issuer
curl -vI https://ykt-piserver.zapto.org/ 2>&1 | grep -i "issuer"
# Should show: issuer: C=US; O=Let's Encrypt; CN=R3
```

### Test in Browser
```
URL: https://ykt-piserver.zapto.org/
```

You should see:
- ✅ **🔒 Secure padlock** in address bar
- ✅ **No certificate warnings**
- ✅ Certificate issued by **Let's Encrypt**
- ✅ Keycloak login page

---

## 📊 Access URLs

| Purpose | URL | Port |
|---------|-----|------|
| **Keycloak (HTTPS)** | `https://ykt-piserver.zapto.org/` | 443 |
| **Keycloak Admin** | `https://ykt-piserver.zapto.org/admin/` | 443 |
| **AWS SAML Metadata** | `https://ykt-piserver.zapto.org/realms/aws/protocol/saml/descriptor` | 443 |
| **OIDC Discovery** | `https://ykt-piserver.zapto.org/realms/aws/.well-known/openid-configuration` | 443 |

**Login:** `admin` / `dev-admin-password` (change in production!)

---

## 🔧 Configure AWS Integration

Now that you have a trusted certificate, you can use it with AWS!

### AWS IAM Identity Center (SSO)

**Keycloak URLs:**
```
Realm: aws
Issuer: https://ykt-piserver.zapto.org/realms/aws
SAML Metadata: https://ykt-piserver.zapto.org/realms/aws/protocol/saml/descriptor
```

**In AWS Console:**
1. IAM Identity Center → Settings
2. Identity source → External identity provider
3. Service provider metadata → Download
4. Upload to Keycloak (Clients → Create SAML client)
5. Get Keycloak SAML metadata URL
6. Upload to AWS

### AWS Cognito (OIDC)

```
Provider: Keycloak
Issuer: https://ykt-piserver.zapto.org/realms/aws
Client ID: [from Keycloak]
Client Secret: [from Keycloak]
Scopes: openid email profile
```

---

## 🔄 GitOps: Add to Your Repository

Let's add this configuration to your Git repo so ArgoCD can manage it:

### Create No-IP Overlay

```bash
# On your local machine
cd /Users/admin/Project/cd_repo

# Create noip overlay directory
mkdir -p keycloak-manifests/overlays/noip
```

Create `keycloak-manifests/overlays/noip/ingress.yaml`:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: keycloak
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - ykt-piserver.zapto.org
    secretName: keycloak-letsencrypt-cert
  rules:
  - host: ykt-piserver.zapto.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8081
```

Create `keycloak-manifests/overlays/noip/keycloak-patch.yaml`:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
  namespace: keycloak
data:
  KC_HOSTNAME: "ykt-piserver.zapto.org"
  KC_HOSTNAME_STRICT: "false"
  KC_HTTP_ENABLED: "true"
  KC_PROXY: "edge"
  KC_HEALTH_ENABLED: "true"
  KC_METRICS_ENABLED: "true"
---
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secret
  namespace: keycloak
type: Opaque
stringData:
  KEYCLOAK_ADMIN: admin
  KEYCLOAK_ADMIN_PASSWORD: secure-noip-password  # CHANGE THIS!
```

Create `keycloak-manifests/overlays/noip/postgres-patch.yaml`:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: keycloak
type: Opaque
stringData:
  POSTGRES_DB: keycloak
  POSTGRES_USER: keycloak
  POSTGRES_PASSWORD: noip-postgres-password  # CHANGE THIS!
```

Create `keycloak-manifests/overlays/noip/service-patch.yaml`:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  type: ClusterIP  # Use ClusterIP since ingress handles external access
  ports:
  - port: 8081
    targetPort: 8080
    protocol: TCP
    name: http
```

Create `keycloak-manifests/overlays/noip/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: keycloak

resources:
  - ../../base
  - ingress.yaml

patches:
  - path: keycloak-patch.yaml
  - path: postgres-patch.yaml
  - path: service-patch.yaml
```

Create `argocd-keycloak-noip.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak-noip
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yipkaitsun/cd_repo.git
    targetRevision: main
    path: keycloak-manifests/overlays/noip
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 🚀 Deploy via ArgoCD

```bash
# Push to Git
git add -A
git commit -m "Add Keycloak No-IP + Let's Encrypt configuration"
git push origin main

# Apply ArgoCD application (on K3s server)
sudo kubectl apply -f argocd-keycloak-noip.yaml

# Sync application
argocd app sync keycloak-noip

# Watch deployment
argocd app get keycloak-noip
```

---

## 🔒 Important: Traefik Configuration

Make sure Traefik has HTTPS entrypoint enabled:

```bash
# Check Traefik config
sudo kubectl get configmap traefik -n kube-system -o yaml

# Should have:
# entryPoints:
#   web:
#     address: ":80"
#   websecure:
#     address: ":443"
```

If not configured, you may need to update Traefik or use K3s with `--disable traefik` and install Traefik manually.

For K3s default Traefik, it should work out of the box on port 443.

---

## 🐛 Troubleshooting

### Certificate not issued

```bash
# Check certificate status
sudo kubectl describe certificate keycloak-letsencrypt-cert -n keycloak

# Check cert-manager logs
sudo kubectl logs -n cert-manager -l app=cert-manager --tail=50

# Check if Let's Encrypt can reach your server
curl -I http://ykt-piserver.zapto.org/.well-known/acme-challenge/test
```

**Common issues:**
- Port 80 not accessible (Let's Encrypt needs it for validation)
- DNS not resolving correctly
- Firewall blocking traffic

### Port 80 accessibility

```bash
# Test from another machine
curl -I http://ykt-piserver.zapto.org/

# Check AWS Security Group
# Make sure ports 80 and 443 are open:
# - Port 80: HTTP (for Let's Encrypt validation)
# - Port 443: HTTPS (for Keycloak access)
```

### Certificate shows "Fake LE"

This means cert-manager is using staging environment:

```bash
# Check issuer
sudo kubectl describe clusterissuer letsencrypt-prod

# Make sure it uses:
# server: https://acme-v02.api.letsencrypt.org/directory
# NOT: https://acme-staging-v02.api.letsencrypt.org/directory
```

### Ingress not working

```bash
# Check ingress
sudo kubectl get ingress -n keycloak

# Should show:
# NAME                CLASS     HOSTS                    ADDRESS         PORTS
# keycloak-ingress    traefik   ykt-piserver.zapto.org   18.183.57.208   80, 443

# Check Traefik
sudo kubectl get svc -n kube-system traefik
```

---

## 🔄 Certificate Auto-Renewal

Let's Encrypt certificates expire after **90 days**, but cert-manager automatically renews them at **60 days**.

### Check renewal status

```bash
# View certificate details
sudo kubectl get certificate -n keycloak

# View expiry date
sudo kubectl get certificate keycloak-letsencrypt-cert -n keycloak \
  -o jsonpath='{.status.notAfter}' && echo

# Check renewal history
sudo kubectl describe certificate keycloak-letsencrypt-cert -n keycloak
```

### Manual renewal (if needed)

```bash
# Delete certificate (will be recreated automatically)
sudo kubectl delete certificate keycloak-letsencrypt-cert -n keycloak

# Wait for recreation
sudo kubectl get certificate -n keycloak -w
```

---

## 📊 Comparison: No-IP vs CloudFlare

| Feature | No-IP + Let's Encrypt | CloudFlare |
|---------|----------------------|------------|
| **Cost** | Free | ~$1/month (domain) |
| **Setup Time** | 10 minutes | 5 minutes |
| **Certificate** | Let's Encrypt | CloudFlare |
| **DDoS Protection** | ❌ No | ✅ Yes |
| **CDN** | ❌ No | ✅ Yes |
| **Your Current Setup** | ✅ Works now | Need new domain |
| **AWS Compatible** | ✅ Yes | ✅ Yes |

**Recommendation:** Since you already have No-IP, use Let's Encrypt! It's free and works perfectly.

---

## ✅ Final Checklist

- ✅ cert-manager installed
- ✅ Let's Encrypt ClusterIssuer created
- ✅ Ingress configured with TLS
- ✅ Certificate issued (READY = True)
- ✅ HTTPS accessible (https://ykt-piserver.zapto.org/)
- ✅ No browser warnings
- ✅ Certificate valid for 90 days
- ✅ Auto-renewal configured

---

## 🎯 Next Steps

1. ✅ **Set up HTTPS** (you're here!)
2. Create AWS realm in Keycloak
3. Configure AWS IAM Identity Center or Cognito
4. Test SSO login
5. Add users and groups
6. Enable MFA

See: `KEYCLOAK-AWS-INTEGRATION.md` for AWS setup details.

---

## 🎉 Success!

Your Keycloak is now accessible at:

**🌐 https://ykt-piserver.zapto.org/**

- ✅ Free domain (No-IP)
- ✅ Free SSL certificate (Let's Encrypt)
- ✅ Trusted by AWS
- ✅ Auto-renewal every 90 days
- ✅ **Total cost: $0**

Perfect for AWS integration! 🚀

