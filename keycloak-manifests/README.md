# Keycloak Identity and Access Management

Complete Keycloak setup with PostgreSQL database, managed by ArgoCD.

## 🎯 What This Provides

- **Keycloak IAM**: Identity and Access Management server
- **PostgreSQL Database**: Persistent database for Keycloak
- **Multi-tenancy**: Support for multiple realms
- **GitOps Ready**: Fully managed by ArgoCD
- **Multi-Environment**: Separate dev and prod configurations

## 📁 Directory Structure

```
keycloak-manifests/
├── base/
│   ├── postgres.yaml          # PostgreSQL database
│   ├── keycloak.yaml          # Keycloak server
│   └── kustomization.yaml     # Base kustomization
└── overlays/
    ├── dev/
    │   ├── keycloak-patch.yaml    # Dev credentials & config
    │   ├── postgres-patch.yaml    # Dev DB password
    │   └── kustomization.yaml
    └── prod/
        ├── keycloak-patch.yaml    # Prod credentials (CHANGE PASSWORDS!)
        ├── postgres-patch.yaml    # Prod DB password (CHANGE THIS!)
        └── kustomization.yaml
```

## 🚀 Quick Start

### Prerequisites

- Kubernetes cluster with ArgoCD installed
- kubectl configured
- Git repository pushed to GitHub

### Step 1: Deploy with ArgoCD

**Development:**
```bash
kubectl apply -f argocd-keycloak-dev.yaml
```

**Production:**
```bash
kubectl apply -f argocd-keycloak-prod.yaml
```

### Step 2: Wait for Deployment

```bash
# Watch pods starting (takes 2-3 minutes)
kubectl get pods -n keycloak -w
```

Expected output:
```
NAME                        READY   STATUS    RESTARTS   AGE
postgres-xxxxxxxxx-xxxxx    1/1     Running   0          2m
keycloak-xxxxxxxxx-xxxxx    1/1     Running   0          3m
```

### Step 3: Access Keycloak

```bash
# Port forward to access Keycloak
kubectl port-forward -n keycloak svc/keycloak 8080:8080
```

Open: **http://localhost:8080**

**Login credentials:**
- Dev: `admin` / `dev-admin-password`
- Prod: `admin` / (check `overlays/prod/keycloak-patch.yaml`)

## 🔧 Configuration

### Keycloak Settings

| Setting | Description | Default |
|---------|-------------|---------|
| KEYCLOAK_ADMIN | Admin username | admin |
| KEYCLOAK_ADMIN_PASSWORD | Admin password | Change in overlays! |
| KC_PROXY | Proxy mode | edge |
| KC_DB | Database type | postgres |
| KC_HEALTH_ENABLED | Health checks | true |
| KC_METRICS_ENABLED | Metrics endpoint | true |

### PostgreSQL Settings

| Setting | Description | Default |
|---------|-------------|---------|
| POSTGRES_DB | Database name | keycloak |
| POSTGRES_USER | Database user | keycloak |
| POSTGRES_PASSWORD | Database password | Change in overlays! |

### Environment Differences

| Feature | Dev | Prod |
|---------|-----|------|
| Replicas | 1 | 2 (HA) |
| Admin Password | dev-admin-password | CHANGE THIS! |
| DB Password | dev-postgres-password | CHANGE THIS! |
| Hostname | keycloak-dev.local | keycloak-prod.yourdomain.com |
| TLS | HTTP only | HTTPS required |
| Storage | 5Gi | 10Gi |

## 📊 Accessing Services

### Keycloak Admin Console

```bash
# Port forward
kubectl port-forward -n keycloak svc/keycloak 8080:8080

# Access at
open http://localhost:8080
```

### PostgreSQL Database

```bash
# Connect to PostgreSQL
kubectl exec -it -n keycloak deployment/postgres -- psql -U keycloak -d keycloak

# List tables
\dt

# Exit
\q
```

### Health Check

```bash
# Check Keycloak health
curl http://localhost:8080/health

# Check readiness
curl http://localhost:8080/health/ready

# Check liveness
curl http://localhost:8080/health/live
```

### Metrics

```bash
# View Keycloak metrics
curl http://localhost:8080/metrics
```

## 🔄 Common Tasks

### Create a New Realm

1. Access Keycloak Admin Console
2. Click dropdown in top-left (currently shows "Master")
3. Click **"Create Realm"**
4. Enter realm name (e.g., "myrealm")
5. Click **"Create"**

### Create a User

1. Select your realm
2. Go to **Users** → **Add user**
3. Enter username and email
4. Click **"Create"**
5. Go to **Credentials** tab
6. Set password
7. Toggle "Temporary" off
8. Click **"Save"**

### Create a Client

1. Go to **Clients** → **Create client**
2. Enter Client ID
3. Click **"Next"**
4. Enable authentication flows
5. Click **"Save"**

### Export Realm Configuration

```bash
# Get pod name
POD=$(kubectl get pod -n keycloak -l app=keycloak -o jsonpath='{.items[0].metadata.name}')

# Export realm
kubectl exec -n keycloak $POD -- /opt/keycloak/bin/kc.sh export \
  --dir /tmp --realm myrealm

# Copy to local
kubectl cp keycloak/$POD:/tmp/myrealm-realm.json ./myrealm-realm.json
```

## 🔐 Security Best Practices

### Before Production Deployment

- [ ] Change admin password in `overlays/prod/keycloak-patch.yaml`
- [ ] Change PostgreSQL password in `overlays/prod/postgres-patch.yaml`
- [ ] Configure proper hostname/domain
- [ ] Enable HTTPS/TLS
- [ ] Set up proper ingress with certificates
- [ ] Configure backup strategy
- [ ] Review realm security settings

### Production Checklist

- [ ] Use strong passwords (min 16 characters)
- [ ] Enable two-factor authentication
- [ ] Configure SMTP for email verification
- [ ] Set up regular backups
- [ ] Monitor logs for suspicious activity
- [ ] Use Kubernetes secrets (not ConfigMaps) for sensitive data
- [ ] Implement rate limiting
- [ ] Configure session timeouts

## 📈 Monitoring

### Check Application Status

```bash
# Via ArgoCD
argocd app get keycloak-dev

# Via kubectl
kubectl get all -n keycloak
```

### View Logs

```bash
# Keycloak logs
kubectl logs -n keycloak deployment/keycloak -f

# PostgreSQL logs
kubectl logs -n keycloak deployment/postgres -f

# Check for errors
kubectl logs -n keycloak deployment/keycloak --tail=50 | grep -i error
```

### Database Status

```bash
# Check database size
kubectl exec -n keycloak deployment/postgres -- \
  psql -U keycloak -d keycloak -c "\l+"

# Check table sizes
kubectl exec -n keycloak deployment/postgres -- \
  psql -U keycloak -d keycloak -c "\dt+"
```

## 🔧 Troubleshooting

### Keycloak Not Starting

1. Check logs:
```bash
kubectl logs -n keycloak deployment/keycloak --tail=100
```

2. Check database connection:
```bash
kubectl exec -n keycloak deployment/postgres -- \
  psql -U keycloak -d keycloak -c "SELECT 1"
```

3. Verify secrets:
```bash
kubectl get secrets -n keycloak
kubectl describe secret keycloak-secret -n keycloak
```

### Database Connection Issues

```bash
# Test PostgreSQL connectivity
kubectl run -it --rm psql-test --image=postgres:15-alpine --restart=Never -- \
  psql -h postgres.keycloak -U keycloak -d keycloak

# Check PostgreSQL pod
kubectl describe pod -n keycloak -l app=postgres
```

### Admin Console Not Accessible

```bash
# Check service
kubectl get svc -n keycloak keycloak

# Check ingress
kubectl get ingress -n keycloak

# Port forward directly
kubectl port-forward -n keycloak deployment/keycloak 8080:8080
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n keycloak

# Increase resources in deployment
kubectl edit deployment keycloak -n keycloak
# Update resources.requests and resources.limits
```

## 🔄 Updating Configuration

### Change Admin Password

1. Edit overlay file:
```yaml
# keycloak-manifests/overlays/prod/keycloak-patch.yaml
stringData:
  KEYCLOAK_ADMIN_PASSWORD: "your-new-secure-password"
```

2. Commit and push:
```bash
git add keycloak-manifests/
git commit -m "Update Keycloak admin password"
git push
```

3. Restart Keycloak:
```bash
kubectl delete pod -n keycloak -l app=keycloak
```

### Add More Replicas (Production)

```yaml
# keycloak-manifests/overlays/prod/keycloak-patch.yaml
spec:
  replicas: 3  # Increase from 2
```

### Change Database Storage

**Note:** Cannot change after PVC is created! Must recreate.

```bash
# Backup database first
kubectl exec -n keycloak deployment/postgres -- \
  pg_dump -U keycloak keycloak > keycloak-backup.sql

# Delete PVC
kubectl delete pvc postgres-data -n keycloak

# Update size in overlay
# Then redeploy
```

## 🔗 Integration Examples

### Spring Boot Application

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          keycloak:
            client-id: my-app
            client-secret: your-secret
            scope: openid,profile,email
        provider:
          keycloak:
            issuer-uri: http://keycloak.keycloak:8080/realms/myrealm
```

### Node.js with Keycloak

```javascript
const Keycloak = require('keycloak-connect');
const session = require('express-session');

const keycloak = new Keycloak({}, {
  realm: 'myrealm',
  'auth-server-url': 'http://keycloak.keycloak:8080/',
  'ssl-required': 'external',
  resource: 'my-app',
  credentials: {
    secret: 'your-secret'
  }
});
```

## 📦 Backup and Restore

### Backup Database

```bash
# Create backup
kubectl exec -n keycloak deployment/postgres -- \
  pg_dump -U keycloak keycloak | gzip > keycloak-backup-$(date +%Y%m%d).sql.gz

# List backups
ls -lh keycloak-backup-*.sql.gz
```

### Restore Database

```bash
# Restore from backup
gunzip < keycloak-backup-20250119.sql.gz | \
  kubectl exec -i -n keycloak deployment/postgres -- \
  psql -U keycloak keycloak
```

## 📚 Additional Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Keycloak on Kubernetes](https://www.keycloak.org/operator/installation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

## 💡 Tips

**Access admin console directly:**
```bash
kubectl port-forward -n keycloak svc/keycloak 8080:8080
```

**Check Keycloak version:**
```bash
kubectl exec -n keycloak deployment/keycloak -- /opt/keycloak/bin/kc.sh --version
```

**View realm list:**
```bash
POD=$(kubectl get pod -n keycloak -l app=keycloak -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n keycloak $POD -- /opt/keycloak/bin/kcadm.sh get realms
```

**Create user via CLI:**
```bash
kubectl exec -n keycloak $POD -- /opt/keycloak/bin/kcadm.sh create users \
  -r myrealm -s username=testuser -s enabled=true
```

