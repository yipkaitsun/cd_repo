# ArgoCD Setup Guide

Complete guide to install and configure ArgoCD on your Kubernetes cluster.

## Prerequisites

- Kubernetes cluster running (K3s, EKS, GKE, etc.)
- `kubectl` configured and connected to your cluster
- Cluster admin permissions

## Step 1: Install ArgoCD

### Option A: Quick Install (Recommended for Most Users)

```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for all pods to be ready (takes 2-3 minutes)
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

### Option B: High Availability Install (Production)

```bash
# Create namespace
kubectl create namespace argocd

# Install HA version
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml

# Wait for pods
kubectl wait --for=condition=ready pod --all -n argocd --timeout=300s
```

## Step 2: Verify Installation

```bash
# Check all ArgoCD components are running
kubectl get pods -n argocd

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# argocd-application-controller-x       1/1     Running   0          2m
# argocd-dex-server-x                   1/1     Running   0          2m
# argocd-redis-x                        1/1     Running   0          2m
# argocd-repo-server-x                  1/1     Running   0          2m
# argocd-server-x                       1/1     Running   0          2m
```

## Step 3: Access ArgoCD UI

### Option A: Port Forward (Quick Access)

```bash
# Port forward ArgoCD server to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at: https://localhost:8080
# (Accept the self-signed certificate warning)
```

### Option B: LoadBalancer (Permanent Access)

```bash
# Change service type to LoadBalancer
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get the external IP
kubectl get svc argocd-server -n argocd

# Wait for EXTERNAL-IP to appear, then access:
# https://<EXTERNAL-IP>
```

### Option C: Ingress (Best for Production)

Create `argocd-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx  # or traefik
  rules:
  - host: argocd.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 443
  tls:
  - hosts:
    - argocd.yourdomain.com
    secretName: argocd-tls
```

Apply it:
```bash
kubectl apply -f argocd-ingress.yaml
```

## Step 4: Get Initial Admin Password

```bash
# Get the initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Username: admin
# Password: (output from above command)
```

## Step 5: Login to ArgoCD

### Via Web UI

1. Open https://localhost:8080 (or your LoadBalancer/Ingress URL)
2. Username: `admin`
3. Password: (from Step 4)
4. Click "Sign In"

### Via CLI (Optional but Recommended)

Install ArgoCD CLI:

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# Windows
choco install argocd-cli
```

Login:

```bash
# Port forward if not using LoadBalancer
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Login
argocd login localhost:8080 --username admin --insecure

# Enter password from Step 4
```

## Step 6: Change Admin Password (Recommended)

```bash
# Via CLI
argocd account update-password

# Or via UI: User Info → Update Password
```

## Step 7: Deploy Your VPN Applications

Now you can deploy your VPN infrastructure!

### Deploy Development Environment

```bash
kubectl apply -f argocd-vpn-dev.yaml
```

### Deploy Production Environment

```bash
kubectl apply -f argocd-vpn-prod.yaml
```

### Verify in ArgoCD UI

1. Open ArgoCD dashboard
2. You should see:
   - `vpn-infrastructure-dev` (if deployed)
   - `vpn-infrastructure-prod` (if deployed)
   - `quarkus-app-dev` (your existing app)
   - `quarkus-app-prod` (your existing app)

## Step 8: Configure Git Repository (If Private)

If your repository is private, add credentials:

### Via CLI:

```bash
argocd repo add https://github.com/yipkaitsun/cd_repo.git \
  --username your-github-username \
  --password your-github-token
```

### Via UI:

1. Settings → Repositories → Connect Repo
2. Method: HTTPS
3. Repository URL: `https://github.com/yipkaitsun/cd_repo.git`
4. Username: your GitHub username
5. Password: your GitHub personal access token
6. Click "Connect"

## Common ArgoCD Commands

### Application Management

```bash
# List all applications
argocd app list

# Get application details
argocd app get vpn-infrastructure-dev

# Sync application manually
argocd app sync vpn-infrastructure-dev

# View sync status
argocd app sync-status vpn-infrastructure-dev

# Delete application
argocd app delete vpn-infrastructure-dev
```

### View Application in UI

```bash
# Open ArgoCD UI for specific app
argocd app get vpn-infrastructure-dev --show-operation
```

### Check Application Health

```bash
# Get health status
argocd app get vpn-infrastructure-dev --refresh

# Watch sync progress
argocd app wait vpn-infrastructure-dev --health
```

## Troubleshooting

### ArgoCD Pods Not Starting

```bash
# Check pod status
kubectl get pods -n argocd

# View logs
kubectl logs -n argocd deployment/argocd-server
kubectl logs -n argocd deployment/argocd-repo-server
```

### Can't Access UI

```bash
# Verify service is running
kubectl get svc -n argocd argocd-server

# Check port forward
lsof -ti:8080
kill $(lsof -ti:8080)  # Kill if stuck
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### Application Not Syncing

```bash
# Check application status
argocd app get vpn-infrastructure-dev

# View sync errors
kubectl describe application vpn-infrastructure-dev -n argocd

# Force refresh
argocd app get vpn-infrastructure-dev --refresh --hard
```

### Git Repository Connection Issues

```bash
# Test repository connection
argocd repo list

# Re-add repository
argocd repo rm https://github.com/yipkaitsun/cd_repo.git
argocd repo add https://github.com/yipkaitsun/cd_repo.git
```

## ArgoCD Configuration Options

### Enable Auto-Sync for All Apps

Edit application YAML:
```yaml
syncPolicy:
  automated:
    prune: true      # Remove resources not in git
    selfHeal: true   # Force sync when cluster state changes
```

### Sync Windows (Only sync during certain times)

```yaml
syncPolicy:
  syncOptions:
  - CreateNamespace=true
  automated:
    prune: true
    selfHeal: true
  syncWindows:
  - kind: allow
    schedule: '0 9-17 * * *'  # Only during business hours
    duration: 8h
```

### Notifications Setup (Optional)

Get notified about sync events:

```bash
# Install ArgoCD Notifications
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml
```

## Best Practices

### 1. Use Projects for Organization

```bash
# Create a VPN project
argocd proj create vpn-project \
  --dest https://kubernetes.default.svc,vpn \
  --src https://github.com/yipkaitsun/cd_repo.git
```

### 2. Enable Resource Tracking

In your application:
```yaml
spec:
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
    - PruneLast=true
```

### 3. Use Health Checks

ArgoCD automatically monitors:
- Pod status
- Deployment rollout status
- Service endpoints
- Custom health checks

### 4. Backup ArgoCD Configuration

```bash
# Backup all applications
kubectl get applications -n argocd -o yaml > argocd-apps-backup.yaml

# Backup ArgoCD configuration
kubectl get configmap argocd-cm -n argocd -o yaml > argocd-config-backup.yaml
```

## Security Recommendations

### 1. Disable Admin User (Use SSO Instead)

```bash
# After setting up SSO
argocd account update-password --account admin --new-password "$(openssl rand -base64 32)"
```

### 2. Enable RBAC

Create `argocd-rbac-cm.yaml`:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:vpn-admin, applications, *, vpn-*/*, allow
    p, role:vpn-admin, clusters, get, *, allow
    g, vpn-team, role:vpn-admin
```

### 3. Use Private Repositories

- Use SSH keys or GitHub tokens
- Never commit credentials to git
- Use sealed-secrets or external secret managers

## Monitoring ArgoCD

### Prometheus Metrics

ArgoCD exposes Prometheus metrics:

```bash
# Check metrics endpoint
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082
curl http://localhost:8082/metrics
```

### Dashboard

```bash
# View ArgoCD dashboard
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Next Steps

1. ✅ ArgoCD installed and running
2. ✅ Access ArgoCD UI
3. ✅ Deploy VPN applications
4. 📊 Monitor your deployments
5. 🔄 Update configs in git → ArgoCD auto-syncs

## Quick Reference

```bash
# Installation
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Deploy apps
kubectl apply -f argocd-vpn-dev.yaml
kubectl apply -f argocd-vpn-prod.yaml

# Check status
argocd app list
argocd app get vpn-infrastructure-dev
```

## Resources

- [ArgoCD Official Docs](https://argo-cd.readthedocs.io/)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [ArgoCD CLI Reference](https://argo-cd.readthedocs.io/en/stable/user-guide/commands/argocd/)

---

**Need help?** Check the troubleshooting section or ArgoCD logs:
```bash
kubectl logs -n argocd deployment/argocd-server -f
```

