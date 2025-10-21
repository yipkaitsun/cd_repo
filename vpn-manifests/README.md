# VPN Manifests (WireGuard + Pi-hole)

This directory contains Kubernetes manifests for deploying a VPN solution with built-in ad blocking.

## Components

1. **WireGuard** - Fast, modern VPN server
2. **Pi-hole** - Network-wide ad blocker via DNS filtering

## Architecture

```
Internet → WireGuard VPN → Pi-hole DNS (blocks ads) → Upstream DNS → Internet
                                ↓
                        Ad domains blocked!
```

## Setup

### 1. Copy TLS Certificate

The Pi-hole web interface uses the same TLS certificate as Keycloak/Quarkus:

```bash
# Copy certificate from keycloak namespace to vpn namespace
./copy-tls-secret.sh
```

### 2. Deploy with ArgoCD

The VPN stack is deployed via ArgoCD:

**Dev:**
```bash
kubectl apply -f ../argocd-vpn-dev.yaml
```

**Prod:**
```bash
kubectl apply -f ../argocd-vpn-prod.yaml
```

### 3. Get VPN Client Configuration

After WireGuard is deployed:

```bash
# View QR codes for mobile (scan with WireGuard app)
kubectl logs -n vpn -l app=wireguard

# Get config file for desktop
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}') -- cat /config/peer1/peer1.conf

# Available peers: peer1, peer2, peer3, peer4, peer5
```

### 4. Open Firewall Port

WireGuard requires UDP port 51820 to be open in your cloud provider's security group/firewall.

**AWS:**
```bash
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol udp \
    --port 51820 \
    --cidr 0.0.0.0/0
```

**GCP:**
```bash
gcloud compute firewall-rules create allow-wireguard \
    --allow udp:51820 \
    --target-tags vpn \
    --description="WireGuard VPN"
```

## Access

### WireGuard VPN
- **Protocol:** UDP
- **Port:** 51820
- **Clients:** iOS, Android, macOS, Windows, Linux

### Pi-hole Web UI

**Dev:**
```
https://pihole.ykt-piserver.zapto.org/admin
Password: dev-admin-password
```

**Prod:**
```
https://pihole.ykt-piserver.zapto.org/admin
Password: (set in prod overlay)
```

**Or via port-forward (no ingress needed):**
```bash
kubectl port-forward -n vpn svc/pihole-web 8888:80
# Then open: http://localhost:8888/admin
```

## Configuration

### WireGuard Environment Variables

Set in `wireguard-config` ConfigMap:

- `SERVERURL`: Public IP or domain of your VPN server
- `SERVERPORT`: 51820 (default)
- `PEERS`: Number of client configs to generate (default: 5)
- `PEERDNS`: DNS server for VPN clients (10.43.100.100 = Pi-hole)
- `INTERNAL_SUBNET`: VPN internal network (10.13.13.0/24)
- `ALLOWEDIPS`: Traffic to route through VPN (0.0.0.0/0 = all traffic)

### Pi-hole Configuration

Set in `pihole-config` ConfigMap:

- `WEBPASSWORD`: Admin dashboard password
- `DNS1`: Upstream DNS server (1.1.1.1 = Cloudflare)
- `DNS2`: Backup DNS server (1.0.0.1 = Cloudflare)

### Adding Ad Blocklists

1. Access Pi-hole web UI
2. Go to **Group Management** → **Adlists**
3. Add blocklist URLs (see: https://firebog.net/)
4. Update Gravity: **Tools** → **Update Gravity**

Or via command line:
```bash
PIHOLE_POD=$(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}')

# Add blocklist
kubectl exec -n vpn $PIHOLE_POD -- sqlite3 /etc/pihole/gravity.db \
  "INSERT INTO adlist (address, enabled, comment) VALUES ('https://example.com/blocklist.txt', 1, 'Description');"

# Update gravity
kubectl exec -n vpn $PIHOLE_POD -- pihole -g
```

## Testing

### Verify VPN Connection

1. **Connect to VPN** using WireGuard app
2. **Check IP changed:**
   ```bash
   curl ifconfig.me
   # Should show your server IP
   ```
3. **Verify DNS:**
   ```bash
   nslookup google.com
   # Server should be: 10.43.100.100 (Pi-hole)
   ```

### Test Ad Blocking

Visit these sites after connecting to VPN:

1. **D3ward Ad Block Test:**
   ```
   https://d3ward.github.io/toolz/adblock.html
   ```
   Expected: 90%+ blocked

2. **DNS Leak Test:**
   ```
   https://dnsleaktest.com/
   ```
   Expected: Only shows VPN server DNS (no ISP DNS leak)

### Check Pi-hole Statistics

```bash
PIHOLE_POD=$(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}')

# View stats
kubectl exec -n vpn $PIHOLE_POD -- pihole -c -e

# Watch queries in real-time
kubectl exec -n vpn $PIHOLE_POD -- pihole -t

# Check status
kubectl exec -n vpn $PIHOLE_POD -- pihole status
```

## Troubleshooting

### VPN Not Connecting

```bash
# Check WireGuard logs
kubectl logs -n vpn -l app=wireguard -f

# Verify service has external IP
kubectl get svc -n vpn wireguard

# Check if port 51820 is open
nc -vuz YOUR_SERVER_IP 51820
```

### Ads Not Being Blocked

```bash
# Check if Pi-hole is running
kubectl get pods -n vpn -l app=pihole

# Verify DNS is correct in WireGuard config
# Should have: DNS = 10.43.100.100

# Check if blocklists are loaded
kubectl exec -n vpn $PIHOLE_POD -- pihole -c
```

### Pi-hole Web UI Not Accessible

```bash
# Check ingress
kubectl get ingress -n vpn pihole-ingress

# Verify TLS secret exists
kubectl get secret noip-tls-secret -n vpn

# If secret missing, run:
./copy-tls-secret.sh
```

### Website Not Loading (False Positive)

```bash
# Whitelist domain in Pi-hole
kubectl exec -n vpn $PIHOLE_POD -- pihole -w example.com

# Or via web UI: Whitelist section
```

## Maintenance

### Update WireGuard

```bash
kubectl rollout restart deployment/wireguard -n vpn
```

### Update Pi-hole

```bash
# Update Pi-hole core
kubectl exec -n vpn $PIHOLE_POD -- pihole -up

# Update blocklists
kubectl exec -n vpn $PIHOLE_POD -- pihole -g
```

### Backup Configuration

```bash
# Backup Pi-hole config
kubectl cp vpn/$PIHOLE_POD:/etc/pihole ./pihole-backup

# Backup WireGuard configs
kubectl cp vpn/$WIREGUARD_POD:/config ./wireguard-backup
```

## Security Notes

1. **Change default Pi-hole password** in prod overlay
2. **Limit WireGuard port** to specific IPs if possible
3. **Regularly update** containers and blocklists
4. **Monitor Pi-hole logs** for suspicious queries
5. **Use strong passwords** for VPN clients

## Architecture Notes

- **WireGuard LoadBalancer**: Exposes UDP 51820 externally
- **Pi-hole ClusterIP (10.43.100.100)**: Fixed IP for DNS
- **Pi-hole Web ClusterIP**: Internal only, accessed via ingress or port-forward
- **Shared TLS Certificate**: Uses same cert as Keycloak/Quarkus (noip-tls-secret)

## Features

✅ **Network-wide ad blocking** for all VPN users
✅ **Encrypted VPN tunnel** with WireGuard
✅ **HTTPS web interface** for Pi-hole
✅ **5 pre-configured VPN clients**
✅ **Works on mobile and desktop**
✅ **Automatic ArgoCD deployment**
✅ **Shared TLS certificate** (no rate limits)

## Support

- **WireGuard**: https://www.wireguard.com/
- **Pi-hole**: https://pi-hole.net/
- **Traefik**: https://doc.traefik.io/traefik/
