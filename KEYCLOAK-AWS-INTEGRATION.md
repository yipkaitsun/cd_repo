# 🔐 Keycloak as AWS Identity Provider

Guide to integrate Keycloak with AWS (IAM Identity Center, Cognito, or IAM OIDC).

---

## ⚠️ AWS Requirements

AWS **REQUIRES**:
1. ✅ **HTTPS** (SSL/TLS)
2. ✅ **Trusted Certificate** (from recognized CA)
3. ✅ **Public accessibility** (or VPN/Direct Connect)
4. ✅ **Stable endpoint** (domain name recommended)

**Your current setup:**
- ❌ Self-signed certificate → AWS will reject
- ✅ Public IP (18.183.57.208) → Accessible
- ⚠️ No domain name → Not ideal

---

## 🎯 Solution Options

### Option 1: Domain Name + Let's Encrypt (FREE ✅ Recommended)

#### Prerequisites:
1. Get a domain name (e.g., from Route53, Namecheap, GoDaddy)
2. Point DNS to your IP: `keycloak.yourdomain.com` → `18.183.57.208`

#### Setup Steps:

```bash
# 1. Install cert-manager (on K3s server)
sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready
sudo kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# 2. Create Let's Encrypt issuer
cat <<EOF | sudo kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # CHANGE THIS
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF
```

#### Update Keycloak Manifests:

Create `keycloak-manifests/overlays/aws-prod/ingress-patch.yaml`:

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
    - keycloak.yourdomain.com  # CHANGE THIS
    secretName: keycloak-letsencrypt-cert
  rules:
  - host: keycloak.yourdomain.com  # CHANGE THIS
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
```

#### Result:
- ✅ Trusted certificate from Let's Encrypt
- ✅ Free (renews automatically)
- ✅ Works with AWS
- 🌐 Access: `https://keycloak.yourdomain.com/realms/aws`

---

### Option 2: AWS Certificate Manager + ALB (AWS Native)

If you want AWS-managed certificates:

#### Setup:
1. Create Application Load Balancer (ALB) in AWS
2. Request certificate from AWS Certificate Manager (ACM)
3. Point ALB to your K3s instance on port 8081
4. Use ALB's HTTPS endpoint with AWS

#### Architecture:
```
Internet → ALB (AWS) → K3s (18.183.57.208:8081)
         [ACM Cert]
```

#### Pros:
- ✅ AWS-managed certificate
- ✅ Trusted by AWS services
- ✅ Can use custom domain

#### Cons:
- 💰 ALB costs (~$16/month)
- 🔧 More complex setup

---

### Option 3: CloudFlare SSL (Free Alternative)

Use CloudFlare as reverse proxy with their free SSL:

1. Add domain to CloudFlare
2. Enable CloudFlare proxy (orange cloud)
3. Set SSL mode to "Flexible" or "Full"
4. Point DNS to 18.183.57.208

#### Result:
- ✅ Free trusted certificate
- ✅ DDoS protection
- ✅ CDN benefits
- 🌐 Access: `https://keycloak.yourdomain.com/realms/aws`

---

## 🔧 Configure Keycloak Realm for AWS

### Step 1: Create AWS Realm

```bash
# Access Keycloak admin console
# https://keycloak.yourdomain.com/ (or https://18.183.57.208:8443/)

# Login: admin / dev-admin-password
```

1. Click **"Create Realm"**
2. Name: `aws`
3. Click **"Create"**

### Step 2: Create Client for AWS

**For AWS IAM Identity Center (SSO):**

1. Go to **Clients** → **Create Client**
2. Settings:
   - **Client ID**: `aws-sso`
   - **Client Protocol**: `saml`
   - **Valid redirect URIs**: `https://your-sso-region.awsapps.com/start/saml/callback`
   - **IDP-Initiated SSO URL**: `aws-sso`

**For AWS IAM OIDC:**

1. Go to **Clients** → **Create Client**
2. Settings:
   - **Client ID**: `aws-oidc`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
   - **Valid redirect URIs**: `https://signin.aws.amazon.com/saml`
   - **Web Origins**: `https://console.aws.amazon.com`

### Step 3: Create Users

1. Go to **Users** → **Add User**
2. Create test user
3. Set password in **Credentials** tab
4. Add email attribute

### Step 4: Configure Mappers

Add required AWS attributes:
- `email`
- `name`
- `groups` (for role mapping)

---

## 🔗 AWS Integration Types

### 1. AWS IAM Identity Center (formerly AWS SSO)

**Best for:** Enterprise SSO to AWS Console

**Setup:**
1. AWS Console → IAM Identity Center
2. Settings → Identity source → External identity provider
3. Upload Keycloak SAML metadata
4. Configure attribute mappings

**Keycloak URL:**
```
https://keycloak.yourdomain.com/realms/aws
```

**Metadata URL:**
```
https://keycloak.yourdomain.com/realms/aws/protocol/saml/descriptor
```

---

### 2. AWS Cognito Identity Provider

**Best for:** Application authentication

**Setup:**
1. Cognito → User Pools → Identity Providers
2. Choose **OIDC**
3. Configure:
   - **Provider name**: `Keycloak`
   - **Client ID**: (from Keycloak)
   - **Client secret**: (from Keycloak)
   - **Authorize scope**: `openid email profile`
   - **Issuer**: `https://keycloak.yourdomain.com/realms/aws`

---

### 3. AWS IAM OIDC Provider

**Best for:** EKS, Lambda, or programmatic access

**Setup:**
1. IAM → Identity Providers → Add Provider
2. Provider Type: **OpenID Connect**
3. Provider URL: `https://keycloak.yourdomain.com/realms/aws`
4. Audience: (your client ID)

---

## 🧪 Test Integration

### Test OIDC Discovery

```bash
# Should return JSON with endpoints
curl https://keycloak.yourdomain.com/realms/aws/.well-known/openid-configuration
```

### Test SAML Metadata

```bash
# Should return XML metadata
curl https://keycloak.yourdomain.com/realms/aws/protocol/saml/descriptor
```

---

## 🔒 Security Best Practices

### 1. Enable MFA in Keycloak
```bash
# In Keycloak Admin Console:
# Authentication → Required Actions → Configure OTP
```

### 2. Restrict IP Access (Optional)
```yaml
# Add to ingress annotations:
traefik.ingress.kubernetes.io/whitelist-source-range: "your-office-ip/32,aws-ip-ranges"
```

### 3. Enable Rate Limiting
```yaml
# Add to ingress annotations:
traefik.ingress.kubernetes.io/rate-limit: |
  average: 100
  burst: 200
```

### 4. Use Strong Passwords
```bash
# In Keycloak:
# Realm Settings → Password Policy → Add policy
```

---

## 📊 Comparison Matrix

| Solution | Cost | AWS Compatible | Auto-Renew | Setup Complexity |
|----------|------|----------------|------------|------------------|
| **Self-signed** | Free | ❌ No | N/A | Easy |
| **Let's Encrypt** | Free | ✅ Yes | ✅ Yes | Medium |
| **AWS ACM + ALB** | ~$16/mo | ✅ Yes | ✅ Yes | Hard |
| **CloudFlare SSL** | Free | ✅ Yes | ✅ Yes | Easy |

---

## 🎯 Recommended Path

For AWS integration:

1. **Get a domain name** (or use existing)
   - Route53: $12/year for `.com`
   - Namecheap: $10/year

2. **Use Let's Encrypt** (free trusted certificate)
   - Install cert-manager
   - Configure automatic renewal
   - No cost, fully automated

3. **Configure Keycloak realm**
   - Create `aws` realm
   - Set up SAML or OIDC client
   - Add users and groups

4. **Integrate with AWS**
   - IAM Identity Center (for console access)
   - Or Cognito (for applications)
   - Or IAM OIDC (for programmatic access)

---

## 🚀 Quick Start (Assuming you have domain)

```bash
# On K3s server
# 1. Install cert-manager
sudo kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Wait for it
sudo kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# 3. Create issuer (replace email!)
cat <<EOF | sudo kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# 4. Update Keycloak ingress with your domain and cert-manager annotation
# (See ingress-patch.yaml example above)

# 5. Wait for certificate
sudo kubectl get certificate -n keycloak -w
```

---

## ❓ FAQ

### Q: Can I use IP address instead of domain?
**A:** Not for AWS integration. AWS requires domain names for OIDC/SAML.

### Q: Is self-signed certificate enough?
**A:** No. AWS will reject self-signed certificates.

### Q: How much does a domain cost?
**A:** $10-15/year for common TLDs (.com, .net, .org)

### Q: Can I use AWS Route53 for DNS?
**A:** Yes! Route53 is $12/year for .com domain + $0.50/month for hosted zone.

### Q: Does Let's Encrypt cost money?
**A:** No, it's completely free. Certificates auto-renew every 90 days.

---

## 📝 Summary

**Current Status:**
- ❌ Can't use with AWS (self-signed cert)
- ✅ Keycloak is working
- ✅ Publicly accessible

**To Make It Work:**
1. Get domain name ($10-15/year)
2. Install cert-manager (free)
3. Get Let's Encrypt certificate (free)
4. Configure AWS integration
5. ✅ Production-ready!

**Total Cost:** ~$1/month (domain only)

---

## 🔗 Useful Links

- [Keycloak AWS Integration Guide](https://www.keycloak.org/docs/latest/server_admin/#_identity_broker_saml)
- [AWS IAM Identity Center SAML](https://docs.aws.amazon.com/singlesignon/latest/userguide/manage-your-identity-source-idp.html)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Next:** Get a domain name and I'll help you set up Let's Encrypt! 🚀

