# VPN Infrastructure with WireGuard and Pi-hole

This directory contains Kubernetes manifests for deploying a VPN infrastructure with WireGuard and Pi-hole ad-blocking, managed by ArgoCD.

## Architecture

- **WireGuard VPN**: Secure VPN server for remote access
- **Pi-hole**: DNS-based ad blocking and DNS server
- **Integration**: WireGuard uses Pi-hole as DNS server (PEERDNS=10.43.100.100)

## Structure

```
vpn-manifests/
├── base/                      # Base configurations
│   ├── wireguard.yaml         # WireGuard VPN server
│   ├── pihole.yaml            # Pi-hole ad blocker
│   └── kustomization.yaml     # Base kustomization
└── overlays/
    ├── dev/                   # Development environment
    │   ├── wireguard-patch.yaml
    │   ├── pihole-patch.yaml
    │   └── kustomization.yaml
    └── prod/                  # Production environment
        ├── wireguard-patch.yaml
        ├── pihole-patch.yaml
        └── kustomization.yaml
```

## ArgoCD Deployment

### Deploy Development Environment

```bash
kubectl apply -f argocd-vpn-dev.yaml
```

This will:
- Create the `vpn` namespace
- Deploy WireGuard with 3 peer configurations
- Deploy Pi-hole with development password
- Enable auto-sync and self-healing

### Deploy Production Environment

```bash
kubectl apply -f argocd-vpn-prod.yaml
```

This will:
- Create the `vpn` namespace
- Deploy WireGuard with 10 peer configurations
- Deploy Pi-hole with production settings
- Require manual sync for changes (safer for production)

### Manual Sync in ArgoCD

For production, you'll need to manually sync changes:

```bash
argocd app sync vpn-infrastructure-prod
```

## Configuration

### WireGuard Configuration

Key configuration values in `vpn-manifests/base/wireguard.yaml`:

- `SERVERURL`: Your server's public IP address (currently: 18.183.57.208)
- `SERVERPORT`: WireGuard port (51820)
- `PEERS`: Number of client configurations to generate
- `PEERDNS`: Pi-hole DNS server IP (10.43.100.100)
- `INTERNAL_SUBNET`: VPN internal network (10.13.13.0)

### Pi-hole Configuration

Key configuration values in `vpn-manifests/base/pihole.yaml`:

- `WEBPASSWORD`: Admin panel password (**CHANGE THIS IN PRODUCTION!**)
- `SERVERIP`: Pi-hole service IP (10.43.100.100)
- `DNS1/DNS2`: Upstream DNS servers (Cloudflare 1.1.1.1 and 1.0.0.1)

### Environment-Specific Overrides

**Development** (`overlays/dev/`):
- 3 WireGuard peers
- Dev password for Pi-hole
- Hostname: `pihole-dev.vpn.local`

**Production** (`overlays/prod/`):
- 10 WireGuard peers
- Secure password (must be changed!)
- Hostname: `pihole-prod.vpn.local`

## Accessing the Services

### Get WireGuard Client Configurations

```bash
# Get the WireGuard pod name
kubectl get pods -n vpn

# View peer1 configuration
kubectl exec -n vpn wireguard-XXXXX -- cat /config/peer1/peer1.conf

# Or get QR code for mobile
kubectl exec -n vpn wireguard-XXXXX -- cat /config/peer1/peer1.png
```

### Access Pi-hole Admin Panel

1. Port forward to access the web interface:
```bash
kubectl port-forward -n vpn svc/pihole-web 8080:80
```

2. Open browser: http://localhost:8080/admin
3. Login with the password from the ConfigMap

### Check LoadBalancer IP

```bash
kubectl get svc -n vpn wireguard
```

Update the `SERVERURL` in the WireGuard configuration with this IP.

## Monitoring

### Check Application Status

```bash
# Via ArgoCD CLI
argocd app get vpn-infrastructure-dev
argocd app get vpn-infrastructure-prod

# Via kubectl
kubectl get applications -n argocd
```

### Check Pod Status

```bash
kubectl get pods -n vpn
kubectl logs -n vpn deployment/wireguard
kubectl logs -n vpn deployment/pihole
```

## Troubleshooting

### WireGuard Issues

1. Check if the service has an external IP:
```bash
kubectl get svc -n vpn wireguard
```

2. Verify WireGuard is running:
```bash
kubectl exec -n vpn deployment/wireguard -- wg show
```

### Pi-hole Issues

1. Check DNS is responding:
```bash
kubectl exec -n vpn deployment/pihole -- dig @127.0.0.1 google.com
```

2. Verify Pi-hole service has the correct ClusterIP:
```bash
kubectl get svc -n vpn pihole-dns
# Should show 10.43.100.100
```

### ArgoCD Sync Issues

1. Check application health:
```bash
argocd app get vpn-infrastructure-dev --refresh
```

2. View sync status:
```bash
argocd app sync-status vpn-infrastructure-dev
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Change Pi-hole Password**: The default production password in `overlays/prod/pihole-patch.yaml` must be changed!
2. **Update Server IP**: Set the correct `SERVERURL` for your environment
3. **Network Policies**: Consider adding NetworkPolicies to restrict traffic
4. **Secrets Management**: Consider using sealed-secrets or external secret management for passwords
5. **TLS/HTTPS**: Add TLS certificates for Pi-hole ingress in production

## Updating Configuration

1. Modify the appropriate files in `vpn-manifests/`
2. Commit and push changes to git
3. ArgoCD will automatically sync (dev) or wait for manual sync (prod)

```bash
git add vpn-manifests/
git commit -m "Update VPN configuration"
git push origin main
```

## Cleanup

### Remove Development Environment

```bash
kubectl delete -f argocd-vpn-dev.yaml
kubectl delete namespace vpn
```

### Remove Production Environment

```bash
kubectl delete -f argocd-vpn-prod.yaml
kubectl delete namespace vpn
```

