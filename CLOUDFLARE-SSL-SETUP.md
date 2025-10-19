# ☁️ CloudFlare SSL Setup for Keycloak

Quick and easy guide to get a **free trusted SSL certificate** using CloudFlare.

---

## 🎯 Why CloudFlare?

✅ **Free SSL certificate** (trusted by AWS)  
✅ **5-minute setup** (easiest option)  
✅ **Auto-renewal** (no maintenance)  
✅ **DDoS protection** (bonus)  
✅ **CDN caching** (faster performance)  
✅ **Works with AWS** (IAM, Cognito, etc.)  

**Total cost:** ~$1/month (domain only)

---

## 📋 Prerequisites

1. ✅ Domain name (new or existing)
   - If you don't have one: buy from [Namecheap](https://www.namecheap.com/) ($10/year) or [Route53](https://console.aws.amazon.com/route53) ($12/year)
2. ✅ CloudFlare account (free)
3. ✅ Keycloak running on K3s
4. ✅ Public IP: `18.183.57.208`

---

## 🚀 Step-by-Step Setup

### Step 1: Get a Domain Name

**Option A: Namecheap** (Cheapest - ~$10/year)
1. Go to [namecheap.com](https://www.namecheap.com/)
2. Search for available domain (e.g., `yourcompany-sso.com`)
3. Purchase domain
4. **Don't configure nameservers yet** (we'll change to CloudFlare)

**Option B: AWS Route53** (AWS-native - $12/year)
1. Go to [Route53 Console](https://console.aws.amazon.com/route53)
2. Click **"Register Domain"**
3. Search and purchase domain
4. Wait for registration (can take 10 minutes)

**Recommendation:** Pick a domain like:
- `auth-yourcompany.com`
- `sso-yourcompany.com`
- `id-yourcompany.com`

---

### Step 2: Sign Up for CloudFlare

1. Go to [cloudflare.com](https://www.cloudflare.com/)
2. Click **"Sign Up"** (free account)
3. Enter email and password
4. Verify email

**Cost:** $0 (Free plan is perfect)

---

### Step 3: Add Your Domain to CloudFlare

1. In CloudFlare dashboard, click **"Add a Site"**
2. Enter your domain: `yourcompany-sso.com`
3. Select **"Free"** plan
4. Click **"Continue"**

CloudFlare will scan your existing DNS records (if any).

---

### Step 4: Configure DNS Records

Add these DNS records in CloudFlare:

#### A Record for Keycloak
```
Type: A
Name: keycloak (or @)
IPv4: 18.183.57.208
Proxy: ☁️ Proxied (Orange Cloud) ← IMPORTANT!
TTL: Auto
```

#### Example Configuration:
```
keycloak.yourcompany-sso.com → 18.183.57.208 (☁️ Proxied)
```

**Important:** The **orange cloud** must be enabled (Proxied). This gives you SSL!

#### Optional: Add Root Domain
```
Type: A
Name: @
IPv4: 18.183.57.208
Proxy: ☁️ Proxied
```

**Click "Continue"** when done.

---

### Step 5: Change Nameservers

CloudFlare will give you **2 nameservers** like:
```
ava.ns.cloudflare.com
bob.ns.cloudflare.com
```

#### If Using Namecheap:
1. Go to [Namecheap Dashboard](https://ap.www.namecheap.com/domains/list/)
2. Find your domain → Click **"Manage"**
3. Find **"Nameservers"** section
4. Select **"Custom DNS"**
5. Enter CloudFlare's nameservers:
   - Nameserver 1: `ava.ns.cloudflare.com`
   - Nameserver 2: `bob.ns.cloudflare.com`
6. Click **"Save"**

#### If Using Route53:
1. Go to [Route53 Hosted Zones](https://console.aws.amazon.com/route53/v2/hostedzones)
2. Select your domain's hosted zone
3. Find the **NS record** (type: NS)
4. Click **"Edit"**
5. Replace AWS nameservers with CloudFlare nameservers
6. Click **"Save"**

**Note:** DNS propagation takes 5-30 minutes (sometimes up to 24 hours).

---

### Step 6: Wait for Activation

1. In CloudFlare, you'll see **"Checking nameservers"**
2. Wait 5-30 minutes
3. CloudFlare will email you when it's active
4. Status will change to **"Active"** 🟢

**Check status:**
```bash
# See if nameservers have changed
nslookup -type=ns yourcompany-sso.com

# Should show CloudFlare nameservers
```

---

### Step 7: Configure SSL/TLS Settings

1. In CloudFlare dashboard, go to **SSL/TLS** tab
2. Set SSL/TLS encryption mode:

#### Option A: Full (Recommended)
```
Encryption mode: Full
```
- CloudFlare ↔️ K3s: Encrypted with self-signed cert
- Client ↔️ CloudFlare: Encrypted with CloudFlare cert
- **Best balance of security and ease**

#### Option B: Full (Strict) - Most Secure
```
Encryption mode: Full (strict)
```
- Requires valid certificate on K3s (use your self-signed cert or Let's Encrypt)
- Most secure option
- **Recommended for production**

#### Option C: Flexible - Easiest
```
Encryption mode: Flexible
```
- CloudFlare ↔️ K3s: HTTP (no encryption)
- Client ↔️ CloudFlare: HTTPS
- **Not recommended for production** (less secure)

**For Keycloak + AWS:** Use **"Full"** or **"Full (strict)"**

---

### Step 8: Enable Additional Security (Optional but Recommended)

#### A. Always Use HTTPS
1. Go to **SSL/TLS** → **Edge Certificates**
2. Enable **"Always Use HTTPS"** ✅
3. Visitors will auto-redirect from HTTP to HTTPS

#### B. Automatic HTTPS Rewrites
1. In **SSL/TLS** → **Edge Certificates**
2. Enable **"Automatic HTTPS Rewrites"** ✅

#### C. Minimum TLS Version
1. In **SSL/TLS** → **Edge Certificates**
2. Set **Minimum TLS Version: TLS 1.2** (or 1.3 for better security)

---

### Step 9: Update Keycloak Configuration

Now update your K3s deployment to use the CloudFlare domain.

#### Remove HTTPS Port from Service (CloudFlare handles SSL)

Create `keycloak-manifests/overlays/cloudflare/service-patch.yaml`:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
spec:
  type: LoadBalancer
  ports:
  - port: 8081
    targetPort: 8080
    protocol: TCP
    name: http
```

#### Update ConfigMap for Proxy Mode

Create `keycloak-manifests/overlays/cloudflare/keycloak-patch.yaml`:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-config
  namespace: keycloak
data:
  KC_HOSTNAME: "keycloak.yourcompany-sso.com"  # YOUR DOMAIN
  KC_HOSTNAME_STRICT: "false"
  KC_HTTP_ENABLED: "true"
  KC_PROXY: "edge"  # Important for CloudFlare
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
  KEYCLOAK_ADMIN_PASSWORD: dev-admin-password  # Change in prod!
```

#### Create Kustomization

Create `keycloak-manifests/overlays/cloudflare/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: keycloak

resources:
  - ../../base

patches:
  - path: keycloak-patch.yaml
  - path: service-patch.yaml
  - path: ../../dev/postgres-patch.yaml  # Reuse from dev
```

#### Create ArgoCD Application

Create `argocd-keycloak-cloudflare.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak-cloudflare
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/yipkaitsun/cd_repo.git
    targetRevision: main
    path: keycloak-manifests/overlays/cloudflare
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

### Step 10: Deploy to K3s

On your K3s server:

```bash
# Apply ArgoCD application
sudo kubectl apply -f argocd-keycloak-cloudflare.yaml

# Sync the application
argocd app sync keycloak-cloudflare

# Wait for deployment
kubectl rollout status deployment/keycloak -n keycloak

# Check service
kubectl get svc -n keycloak keycloak
```

---

### Step 11: Configure CloudFlare Firewall (Optional)

Add custom firewall rules to protect Keycloak:

1. Go to **Security** → **WAF**
2. Click **"Create firewall rule"**

#### Rule 1: Rate Limiting
```
Rule name: Keycloak Rate Limit
Field: URI Path
Operator: contains
Value: /realms/
Action: Rate Limit
Requests: 100 per minute
```

#### Rule 2: Geo-Blocking (Optional)
```
Rule name: Allow Only Your Country
Field: Country
Operator: is not in
Value: [Your Country]
Action: Block
```

#### Rule 3: Bot Protection
```
Rule name: Block Bots
Field: Known Bots
Action: Managed Challenge
```

---

### Step 12: Test Your Setup

#### Test DNS Resolution
```bash
# Check if domain resolves to CloudFlare IP (not your server IP!)
dig keycloak.yourcompany-sso.com

# Should show CloudFlare IP (like 104.21.x.x or 172.67.x.x)
```

#### Test HTTPS
```bash
# Should return Keycloak page
curl -I https://keycloak.yourcompany-sso.com/

# Check certificate (should be CloudFlare)
openssl s_client -connect keycloak.yourcompany-sso.com:443 -servername keycloak.yourcompany-sso.com | grep "Issuer"
# Should show: Issuer: C=US, O=CloudFlare, Inc.
```

#### Test in Browser
1. Open: `https://keycloak.yourcompany-sso.com/`
2. Check for **🔒 padlock icon** (secure)
3. Click padlock → **"Connection is secure"** ✅
4. Certificate issued by: **CloudFlare**

#### Test Keycloak Admin
```
URL: https://keycloak.yourcompany-sso.com/
Login: admin / dev-admin-password
```

---

## 🎉 Success Checklist

- ✅ Domain added to CloudFlare
- ✅ Nameservers changed and active
- ✅ DNS A record points to 18.183.57.208
- ✅ Orange cloud (Proxied) is enabled
- ✅ SSL mode set to "Full" or "Full (strict)"
- ✅ Keycloak accessible via HTTPS
- ✅ No browser certificate warnings
- ✅ Can log in to Keycloak admin console

---

## 🔧 CloudFlare Dashboard Overview

### Important Tabs:

**SSL/TLS**
- Set encryption mode
- Configure edge certificates
- Enable HTTPS redirects

**DNS**
- Manage A/CNAME records
- Enable/disable proxy (orange cloud)

**Security**
- WAF rules
- Rate limiting
- DDoS protection

**Speed**
- Caching settings
- Auto minify
- Rocket Loader

**Analytics**
- Traffic stats
- Security events
- Performance metrics

---

## 🌐 Configure AWS Integration

Now that you have a trusted SSL certificate, you can integrate with AWS!

### For AWS IAM Identity Center (SSO):

**Keycloak URLs:**
```
Issuer: https://keycloak.yourcompany-sso.com/realms/aws
Metadata: https://keycloak.yourcompany-sso.com/realms/aws/protocol/saml/descriptor
SSO URL: https://keycloak.yourcompany-sso.com/realms/aws/protocol/saml
```

**AWS Configuration:**
1. Go to AWS Console → IAM Identity Center
2. Settings → Identity source → External identity provider
3. Upload SAML metadata from Keycloak
4. Configure attribute mappings:
   - `email` → `email`
   - `name` → `name`
   - `groups` → `groups`

### For AWS Cognito:

**OIDC Configuration:**
```
Provider name: Keycloak
Client ID: [from Keycloak]
Client secret: [from Keycloak]
Authorize scope: openid email profile
Issuer: https://keycloak.yourcompany-sso.com/realms/aws
Discovery: https://keycloak.yourcompany-sso.com/realms/aws/.well-known/openid-configuration
```

---

## 🐛 Troubleshooting

### Domain doesn't resolve
```bash
# Check nameservers
dig NS yourcompany-sso.com

# Should show CloudFlare nameservers
# If not, wait longer (up to 24 hours) or check nameserver config
```

### "Too many redirects" error
- **Fix:** Change SSL mode from "Flexible" to "Full"
- In CloudFlare: SSL/TLS → Full

### 502 Bad Gateway
- **Cause:** K3s service is down or not accessible
- **Check:**
  ```bash
  kubectl get svc -n keycloak keycloak
  kubectl get pods -n keycloak
  curl http://18.183.57.208:8081/  # Test direct access
  ```

### CloudFlare shows "Active" but domain doesn't work
- Wait 5-10 more minutes for DNS propagation
- Try incognito/private browsing mode
- Clear browser cache
- Try different DNS: `1.1.1.1` or `8.8.8.8`

### Certificate still shows self-signed
- Check orange cloud is enabled (Proxied)
- Wait a few minutes for SSL to provision
- Try clearing browser SSL cache

### Keycloak admin login fails
- Check pod logs: `kubectl logs -n keycloak -l app=keycloak --tail=50`
- Verify database connection
- Check password in secret

---

## 💰 Cost Breakdown

| Item | Cost | Frequency |
|------|------|-----------|
| Domain (Namecheap) | $10 | per year |
| CloudFlare (Free) | $0 | forever |
| SSL Certificate | $0 | auto-renew |
| **Total** | **$10/year** | **~$0.83/month** |

**Compare:**
- Let's Encrypt: $12/year (domain) + cert-manager setup
- AWS ACM + ALB: $192/year + domain
- Commercial SSL: $50-200/year

---

## 🎯 Best Practices

### 1. Use Strong Passwords
```yaml
# Update in production:
KEYCLOAK_ADMIN_PASSWORD: "Use-Strong-P@ssw0rd-Here"
```

### 2. Enable CloudFlare WAF
- Protect against common attacks
- Rate limit login endpoints
- Block known malicious IPs

### 3. Monitor Traffic
- Check CloudFlare Analytics regularly
- Set up email alerts for security events

### 4. Enable 2FA in Keycloak
- Realm Settings → Authentication
- Add OTP (One-Time Password)

### 5. Regular Backups
```bash
# Backup Postgres database
kubectl exec -n keycloak deploy/postgres -- pg_dump -U keycloak keycloak > keycloak-backup.sql
```

---

## 📊 Performance Benefits

With CloudFlare you get:

**Speed Improvements:**
- 🚀 **CDN caching** → Faster page loads
- ⚡ **Auto minification** → Smaller files
- 🌍 **Global network** → Closer to users

**Security Benefits:**
- 🛡️ **DDoS protection** → Always available
- 🔒 **WAF** → Block attacks
- 🔐 **Trusted SSL** → No warnings

**Reliability:**
- ✅ **99.9% uptime SLA**
- 🌐 **275+ data centers**
- 📊 **Real-time analytics**

---

## 🔄 Migration from Self-Signed to CloudFlare

If you already have Keycloak running with self-signed cert:

```bash
# 1. Remove HTTPS configuration
# (CloudFlare handles SSL, K3s only needs HTTP)

# 2. Update service to only expose HTTP
kubectl edit svc keycloak -n keycloak
# Remove HTTPS port (8443)

# 3. Update ConfigMap
kubectl edit configmap keycloak-config -n keycloak
# Add: KC_HOSTNAME=keycloak.yourcompany-sso.com
# Add: KC_PROXY=edge

# 4. Restart Keycloak
kubectl rollout restart deployment/keycloak -n keycloak
```

---

## ✅ Final URLs

After setup, your URLs will be:

| Purpose | URL | Certificate |
|---------|-----|-------------|
| **Keycloak Admin** | `https://keycloak.yourcompany-sso.com/` | CloudFlare ✅ |
| **AWS SAML** | `https://keycloak.yourcompany-sso.com/realms/aws/protocol/saml/descriptor` | Trusted ✅ |
| **OIDC Discovery** | `https://keycloak.yourcompany-sso.com/realms/aws/.well-known/openid-configuration` | Trusted ✅ |

**All trusted by AWS!** ✅

---

## 🎓 Next Steps

1. ✅ Set up CloudFlare (you're here!)
2. Create Keycloak realm: `aws`
3. Configure AWS IAM Identity Center
4. Test SSO login
5. Add your team members
6. Enable MFA

---

## 📚 Resources

- [CloudFlare Docs](https://developers.cloudflare.com/)
- [CloudFlare SSL Modes Explained](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [Keycloak Behind Proxy](https://www.keycloak.org/server/reverseproxy)
- [AWS IAM Identity Center](https://docs.aws.amazon.com/singlesignon/latest/userguide/)

---

## 🎉 Congratulations!

You now have:
- ✅ **Free trusted SSL certificate**
- ✅ **Professional domain name**
- ✅ **DDoS protection**
- ✅ **AWS-compatible identity provider**
- ✅ **Global CDN**

All for **less than $1/month!** 🚀

Need help with AWS integration? Check: `KEYCLOAK-AWS-INTEGRATION.md`

