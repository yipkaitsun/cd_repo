# VPN Server with Ad Blocking Setup

This setup deploys WireGuard VPN with Pi-hole ad blocking in your k3s cluster.

## Features

✅ **WireGuard VPN** - Fast, modern, secure VPN protocol
✅ **Pi-hole** - Network-wide ad blocking via DNS
✅ **Auto Ad Blocking** - All VPN traffic goes through Pi-hole
✅ **5 Client Configs** - Pre-generated for easy setup
✅ **Mobile & Desktop** - QR codes for mobile, config files for desktop

## Prerequisites

1. k3s cluster running on AWS EC2
2. kubectl configured and working
3. AWS Security Group access

## Quick Deploy

```bash
# Deploy everything (Pi-hole + WireGuard)
./deploy-vpn-with-adblock.sh
```

## Manual Deployment

```bash
# 1. Deploy Pi-hole
kubectl apply -f pihole-adblock.yaml

# 2. Deploy WireGuard
kubectl apply -f wireguard-vpn.yaml

# 3. Check status
kubectl get pods,svc -n vpn
```

## AWS Security Group Configuration

**Open UDP port 51820 for WireGuard:**

### Via AWS Console:
1. Go to EC2 → Instances → Select your instance
2. Security tab → Click security group
3. Inbound rules → Edit inbound rules
4. Add rule:
   - Type: Custom UDP
   - Port: 51820
   - Source: 0.0.0.0/0
5. Save rules

### Via AWS CLI:
```bash
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol udp \
    --port 51820 \
    --cidr 0.0.0.0/0
```

## Get VPN Client Configurations

### For Mobile (iOS/Android):

```bash
# View QR codes in logs
kubectl logs -n vpn -l app=wireguard

# You'll see QR codes for peer1, peer2, peer3, peer4, peer5
# Scan with WireGuard mobile app
```

### For Desktop (macOS/Windows/Linux):

```bash
# Get peer1 config
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}') -- cat /config/peer1/peer1.conf > ~/wireguard-peer1.conf

# Get peer2 config
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}') -- cat /config/peer2/peer2.conf > ~/wireguard-peer2.conf

# Import to WireGuard desktop client
```

## Access Pi-hole Admin Dashboard

```bash
# Port forward to access locally
kubectl port-forward -n vpn svc/pihole-web 8888:80

# Open browser to: http://localhost:8888/admin
# Default password: admin123 (change in pihole-adblock.yaml)
```

## Connect to VPN

### Mobile:
1. Install WireGuard app from App Store/Play Store
2. Scan QR code from logs
3. Enable the connection
4. Test: Visit http://ad-check.com

### Desktop:
1. Download WireGuard from https://www.wireguard.com/install/
2. Import the .conf file
3. Activate the tunnel
4. Test: Visit http://ad-check.com

## Test Ad Blocking

After connecting to VPN:

1. Visit https://ads-blocker.com/testing/
2. Ads should be blocked automatically
3. Check Pi-hole dashboard to see blocked queries

## Configuration

### Change Pi-hole Password

Edit `pihole-adblock.yaml`:
```yaml
data:
  WEBPASSWORD: "YOUR_SECURE_PASSWORD"
```

Then reapply:
```bash
kubectl apply -f pihole-adblock.yaml
kubectl rollout restart deployment/pihole -n vpn
```

### Change Number of VPN Clients

Edit `wireguard-vpn.yaml`:
```yaml
data:
  PEERS: "10"  # Change from 5 to 10
```

Then reapply:
```bash
kubectl apply -f wireguard-vpn.yaml
kubectl rollout restart deployment/wireguard -n vpn
```

### Change Server IP

Edit `wireguard-vpn.yaml`:
```yaml
data:
  SERVERURL: "YOUR_NEW_EC2_IP"
```

## Verify Setup

```bash
# Check all pods are running
kubectl get pods -n vpn

# Check services
kubectl get svc -n vpn

# Check WireGuard status
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}') -- wg show

# Check Pi-hole status
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole status
```

## Troubleshooting

### WireGuard not connecting:
```bash
# Check logs
kubectl logs -n vpn -l app=wireguard -f

# Verify port 51820 is open in Security Group
# Verify SERVERURL matches your EC2 public IP
```

### Ads not being blocked:
```bash
# Check Pi-hole is running
kubectl get pods -n vpn -l app=pihole

# Verify DNS in WireGuard config
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=wireguard -o jsonpath='{.items[0].metadata.name}') -- cat /config/peer1/peer1.conf | grep DNS

# Should show: DNS = 10.43.100.100
```

### Pi-hole dashboard not accessible:
```bash
# Restart port-forward
kubectl port-forward -n vpn svc/pihole-web 8888:80

# Or access via ingress (if configured)
```

## Uninstall

```bash
# Remove everything
kubectl delete -f wireguard-vpn.yaml
kubectl delete -f pihole-adblock.yaml

# Or delete the entire namespace
kubectl delete namespace vpn
```

## How It Works

1. **WireGuard** creates secure VPN tunnel
2. All DNS queries from VPN clients go to **Pi-hole** (10.43.100.100)
3. **Pi-hole** blocks ad domains and forwards legitimate queries to upstream DNS (1.1.1.1)
4. Result: **Ad-free browsing** on all connected devices

## Block Lists

Pi-hole comes with default block lists. To add more:

1. Access Pi-hole dashboard
2. Go to Group Management → Adlists
3. Add additional lists (e.g., https://firebog.net/)
4. Update gravity: Tools → Update Gravity

## Performance

- WireGuard: Very fast, minimal overhead
- Pi-hole: Caches DNS, speeds up browsing
- Combined: Better experience than no VPN!

## Security Notes

- Change default Pi-hole password immediately
- Consider restricting VPN port 51820 to specific IPs
- Regularly update containers: `kubectl rollout restart deployment -n vpn`
- Monitor Pi-hole logs for suspicious queries

## Support

For issues:
- WireGuard: https://www.wireguard.com/
- Pi-hole: https://pi-hole.net/
- k3s: https://k3s.io/

