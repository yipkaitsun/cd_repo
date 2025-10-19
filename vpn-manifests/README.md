# VPN Infrastructure with WireGuard + Pi-hole

Complete VPN solution with WireGuard VPN server and Pi-hole DNS ad-blocking, managed by ArgoCD.

## 🎯 What This Provides

- **WireGuard VPN Server**: Secure, modern VPN with high performance
- **Pi-hole Ad-Blocker**: DNS-level ad and tracker blocking
- **Integrated DNS**: WireGuard automatically uses Pi-hole for DNS
- **GitOps Ready**: Fully managed by ArgoCD
- **Multi-Environment**: Separate dev and prod configurations

## 📁 Directory Structure

```
vpn-manifests/
├── base/
│   ├── wireguard.yaml         # WireGuard VPN server
│   ├── pihole.yaml            # Pi-hole ad blocker + DNS
│   └── kustomization.yaml     # Base kustomization
└── overlays/
    ├── dev/
    │   ├── wireguard-patch.yaml   # 3 peers, dev settings
    │   ├── pihole-patch.yaml      # Dev password
    │   └── kustomization.yaml
    └── prod/
        ├── wireguard-patch.yaml   # 10 peers, prod settings
        ├── pihole-patch.yaml      # Prod password (CHANGE THIS!)
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
kubectl apply -f argocd-vpn-dev.yaml
```

**Production:**
```bash
kubectl apply -f argocd-vpn-prod.yaml
```

### Step 2: Wait for Deployment

```bash
# Watch pods starting (takes 2-3 minutes)
kubectl get pods -n vpn -w
```

### Step 3: Get LoadBalancer IP

```bash
kubectl get svc -n vpn wireguard

# Copy the EXTERNAL-IP
```

### Step 4: Update Server IP in Git

Edit the appropriate file:
- Dev: `vpn-manifests/overlays/dev/wireguard-patch.yaml`
- Prod: `vpn-manifests/overlays/prod/wireguard-patch.yaml`

Change `SERVERURL: "auto"` to your EXTERNAL-IP:
```yaml
data:
  SERVERURL: "YOUR-EXTERNAL-IP-HERE"
```

Commit and push:
```bash
git add vpn-manifests/overlays/*/wireguard-patch.yaml
git commit -m "Update WireGuard server IP"
git push origin main
```

ArgoCD will auto-sync (dev) or wait for manual sync (prod).

### Step 5: Get Client Configurations
```bash
POD=$(sudo kubectl get pod -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}')

POD=$(sudo kubectl get pod -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}')

sudo kubectl exec -n vpn $POD -- ls -la /config/

sudo kubectl exec -n vpn $POD -- ls -la /config/peer1/ 2>/dev/null || echo "peer1 directory not found"

POD=$(sudo kubectl get pod -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}')

sudo kubectl exec -n vpn $POD -- pihole setpassword 'dev-admin-password'



sudo kubectl exec -n vpn $POD -- bash -c \
  "echo 'cache-size=10000' >> /etc/dnsmasq.d/99-custom.conf"

kubectl exec -n vpn $POD -- pihole restartdns
```


### Step 6: Connect and Test

1. Import config into WireGuard client
2. Activate connection
3. Test: `curl ifconfig.me` (should show VPN server IP)

## 🔧 Configuration

### WireGuard Settings

| Setting | Description | Default |
|---------|-------------|---------|
| SERVERURL | Public IP/domain | auto |
| SERVERPORT | UDP port | 51820 |
| PEERS | Number of client configs | 5 (dev: 3, prod: 10) |
| PEERDNS | DNS server (Pi-hole) | 10.43.100.100 |
| INTERNAL_SUBNET | VPN internal network | 10.13.13.0 |

### Pi-hole Settings

| Setting | Description | Default |
|---------|-------------|---------|
| WEBPASSWORD | Admin password | dev-admin-password / CHANGE-THIS |
| SERVERIP | ClusterIP | 10.43.100.100 |
| DNS1 | Upstream DNS | 1.1.1.1 (Cloudflare) |
| DNS2 | Backup DNS | 1.0.0.1 |

## 📊 Accessing Services

### Pi-hole Dashboard

```bash
# Port forward
kubectl port-forward -n vpn svc/pihole-web 8080:80

# Open browser
open http://localhost:8080/admin

# Password: see pihole-patch.yaml for your environment
```

### WireGuard Configs

```bash
# List all peer configs
POD=$(kubectl get pod -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vpn $POD -- ls -la /config/

# Get specific peer
kubectl exec -n vpn $POD -- cat /config/peer2/peer2.conf
```

## 🔄 Updating Configuration

### Add More VPN Users

1. Edit overlay file:
```yaml
# vpn-manifests/overlays/dev/wireguard-patch.yaml
data:
  PEERS: "5"  # Increase number
```

2. Commit and push:
```bash
git add vpn-manifests/
git commit -m "Add more VPN peers"
git push
```

3. ArgoCD will sync automatically

### Change Pi-hole Password

1. Edit overlay file:
```yaml
# vpn-manifests/overlays/prod/pihole-patch.yaml
data:
  WEBPASSWORD: "your-new-secure-password"
```

2. Commit, push, and sync

## 🎨 Architecture

```
┌─────────────────────────────────────────────┐
│  Client Devices (Laptops, Phones)          │
│  - peer1.conf                               │
│  - peer2.conf                               │
│  - peer3.conf                               │
└──────────────┬──────────────────────────────┘
               │ WireGuard VPN (UDP 51820)
               ▼
┌─────────────────────────────────────────────┐
│  Kubernetes Cluster (vpn namespace)         │
│                                             │
│  ┌───────────────┐      ┌─────────────┐   │
│  │  WireGuard    │─────▶│  Pi-hole    │   │
│  │  VPN Server   │ DNS  │  Ad-Block   │   │
│  │  LoadBalancer │      │  DNS Server │   │
│  └───────────────┘      └─────────────┘   │
│         │                      │           │
│         │ PVC                  │ PVC       │
│         ▼                      ▼           │
│  wireguard-data           pihole-data      │
└─────────────────────────────────────────────┘
         │
         │ ArgoCD GitOps
         ▼
┌─────────────────────────────────────────────┐
│  Git Repository                             │
│  github.com/yipkaitsun/cd_repo              │
└─────────────────────────────────────────────┘
```

## 🔍 Monitoring

### Check Status

```bash
# Application status
kubectl get applications -n argocd | grep vpn

# Pod status
kubectl get pods -n vpn

# Service status
kubectl get svc -n vpn
```

### View Logs

```bash
# WireGuard logs
kubectl logs -n vpn deployment/wireguard -f

# Pi-hole logs
kubectl logs -n vpn deployment/pihole -f
```

### Check VPN Stats

```bash
# WireGuard connections
POD=$(sudo kubectl get pod -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n vpn $POD -- wg show

# Pi-hole stats
sudo kubectl exec -n vpn deployment/pihole -- pihole -c -e
```

## 🛠️ Troubleshooting

### VPN Not Connecting

1. Check LoadBalancer has external IP:
```bash
kubectl get svc -n vpn wireguard
```

2. Verify SERVERURL is set correctly in git

3. Check firewall allows UDP port 51820

4. View WireGuard logs:
```bash
kubectl logs -n vpn deployment/wireguard --tail=50
```

### DNS Not Working

1. Check Pi-hole is running:
```bash
kubectl get pods -n vpn -l app=pihole
```

2. Verify ClusterIP is correct:
```bash
kubectl get svc -n vpn pihole-dns
# Should show: 10.43.100.100
```

3. Test DNS from Pi-hole:
```bash
kubectl exec -n vpn deployment/pihole -- dig @127.0.0.1 google.com
```

### ArgoCD Not Syncing

1. Check application:
```bash
kubectl get application vpn-infrastructure-dev -n argocd
```

2. Force refresh:
```bash
argocd app get vpn-infrastructure-dev --refresh
```

3. Manual sync:
```bash
argocd app sync vpn-infrastructure-dev
```

## 🔐 Security Recommendations

### Before Production

- [ ] Change Pi-hole password in `overlays/prod/pihole-patch.yaml`
- [ ] Update SERVERURL with actual server IP
- [ ] Review firewall rules
- [ ] Limit VPN user access
- [ ] Enable TLS for Pi-hole ingress (optional)

### Regular Maintenance

- [ ] Rotate WireGuard peer configs periodically
- [ ] Review Pi-hole logs for suspicious activity
- [ ] Update images regularly
- [ ] Monitor resource usage
- [ ] Backup client configurations

## 📚 Additional Resources

- [WireGuard Documentation](https://www.wireguard.com/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)

## 💡 Tips

**Get all peer configs at once:**
```bash
POD=$(kubectl get pod -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}')
for i in {1..3}; do
  kubectl exec -n vpn $POD -- cat /config/peer$i/peer$i.conf > peer$i.conf
done
```

**Test ad blocking:**
Visit https://d3ward.github.io/toolz/adblock.html while connected to VPN

**Whitelist a domain:**
```bash
kubectl exec -n vpn deployment/pihole -- pihole -w example.com
```

**Check bandwidth usage:**
```bash
kubectl exec -n vpn $POD -- wg show wg0 transfer
```

