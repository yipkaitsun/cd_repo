# How to Test VPN with Ad Blocking

## Step 1: Verify Pi-hole is Running

```bash
# Check Pi-hole pod status
kubectl get pods -n vpn -l app=pihole

# Should show: Running and Ready 1/1

# Check Pi-hole DNS service
kubectl get svc -n vpn pihole-dns

# Should show ClusterIP: 10.43.100.100
```

## Step 2: Verify WireGuard is Running

```bash
# Check WireGuard pod status
kubectl get pods -n vpn -l app=wireguard

# Should show: Running and Ready 1/1

# Check WireGuard service
kubectl get svc -n vpn wireguard

# Should show LoadBalancer with EXTERNAL-IP
```

## Step 3: Before Connecting - Record Your IP

**Visit these sites BEFORE connecting to VPN:**

1. **Check your current IP:**
   - https://whatismyipaddress.com/
   - https://ifconfig.me/
   - Note down your IP address

2. **Test ad blocking (should see ads):**
   - https://d3ward.github.io/toolz/adblock.html
   - https://ads-blocker.com/testing/
   - You should see ads and trackers loaded

## Step 4: Connect to VPN

### Mobile:
1. Open WireGuard app
2. Enable the tunnel you configured
3. Wait for "Connected" status

### Desktop:
1. Open WireGuard application
2. Activate your tunnel
3. Wait for "Active" status with traffic statistics

## Step 5: Verify VPN Connection

**After connecting, visit these sites:**

1. **Check your new IP (should be different):**
   ```
   https://whatismyipaddress.com/
   ```
   - IP should now be: `18.183.57.208` (your EC2 IP)
   - Location should show: Tokyo, Japan (AWS region)

2. **Confirm VPN is active:**
   ```
   https://ipleak.net/
   ```
   - All IPs should show your VPN server IP
   - DNS should show: `10.43.100.100` (Pi-hole)

3. **DNS leak test:**
   ```
   https://dnsleaktest.com/
   ```
   - Click "Extended test"
   - Should only show your VPN/Pi-hole DNS
   - No ISP DNS servers should appear

## Step 6: Test Ad Blocking

### Quick Tests:

**1. D3ward Ad Block Test (Comprehensive):**
```
https://d3ward.github.io/toolz/adblock.html
```
- **Expected:** Most/all items should show as "Blocked" ✓
- **Good score:** 90%+ blocked
- **Excellent score:** 95%+ blocked

**2. Ads Blocker Testing:**
```
https://ads-blocker.com/testing/
```
- **Expected:** Blank spaces instead of ads
- Should see "Ads Blocked" messages

**3. The Block List Project Test:**
```
https://blocklistproject.github.io/Lists/test.html
```
- **Expected:** Most domains blocked

### Manual Tests:

**1. Test specific ad domains:**
```bash
# On your device with VPN connected
nslookup ads.google.com
nslookup doubleclick.net
nslookup googleadservices.com

# Expected: Should resolve to 0.0.0.0 or not resolve at all
```

**2. Visit ad-heavy websites:**
- https://www.forbes.com/
- https://www.cnn.com/
- https://www.weather.com/

**Expected:** Significantly fewer ads or blank spaces

## Step 7: Check Pi-hole Statistics

### Via Command Line:

```bash
# Get real-time statistics
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -c -e

# Check recent queries
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -t

# See blocked domains count
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -c
```

### Via Web Dashboard:

```bash
# Port forward Pi-hole web interface
kubectl port-forward -n vpn svc/pihole-web 8888:80

# Open browser: http://localhost:8888/admin
# Password: admin123 (or your configured password)
```

**In the dashboard you'll see:**
- Total queries (increases as you browse)
- Queries blocked (should be 15-40%)
- Percentage blocked
- Real-time query log
- Top blocked domains
- Top permitted domains

## Step 8: Test Specific Scenarios

### Test 1: YouTube (Limited blocking)
```
Visit: https://www.youtube.com/
```
- **Expected:** In-video ads may still appear (hard to block)
- Sidebar ads should be reduced/blocked

### Test 2: Mobile Apps
- Open various apps (games, news, weather)
- **Expected:** Fewer/no banner ads and pop-ups

### Test 3: Cryptocurrency Mining Protection
```bash
# Check if crypto mining domains are blocked
nslookup coin-hive.com
nslookug coinhive.com
```
- **Expected:** Blocked/not resolving

### Test 4: Tracker Blocking
```
Visit: https://coveryourtracks.eff.org/
```
- **Expected:** Better privacy score than without VPN

### Test 5: Smart TV (if connected)
- Connect Smart TV to VPN network
- Open apps (YouTube, Hulu, etc.)
- **Expected:** Fewer ad breaks and tracking

## Step 9: Performance Test

### Speed Test:
```
Visit: https://fast.com/
or: https://speedtest.net/
```

**Compare:**
- Speed without VPN: _____
- Speed with VPN: _____

**Expected:** 10-30% slower with VPN is normal

### Latency Test:
```bash
# Ping test from your device
ping 8.8.8.8
```
**Expected:** 5-50ms added latency depending on your location to Tokyo

## Step 10: Check Query Logs in Real-Time

```bash
# Watch Pi-hole queries in real-time
kubectl logs -n vpn -l app=pihole -f

# In another terminal, browse the web
# You should see DNS queries being processed and blocked
```

## Expected Results Summary

✅ **VPN Working:**
- IP address changed to EC2 server IP
- No DNS leaks
- All traffic encrypted

✅ **Ad Blocking Working:**
- 90%+ score on D3ward test
- Blank spaces where ads should be
- Pi-hole dashboard shows blocked queries
- DNS queries to ad domains return 0.0.0.0

✅ **Performance:**
- Browsing speed acceptable
- Pages load faster (no ads to load)
- Mobile data usage reduced

## Troubleshooting

### VPN Connected but No Internet:
```bash
# Check WireGuard logs
kubectl logs -n vpn -l app=wireguard -f

# Verify AllowedIPs in config
# Should be: AllowedIPs = 0.0.0.0/0
```

### Ads Still Showing:
```bash
# 1. Verify DNS is set to Pi-hole
nslookup example.com
# Should show server: 10.43.100.100

# 2. Check if blocklists are loaded
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -g

# 3. Add more blocklists
./add-pihole-blocklists.sh
```

### Website Not Loading:
```bash
# Whitelist the domain
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -w example.com

# Or via dashboard: Whitelist section
```

### False Positives:
Some legitimate sites may be blocked. Check Pi-hole query log and whitelist as needed.

## Advanced Testing

### Test DNSSEC:
```
https://dnssec.vs.uni-due.de/
```
Should show DNSSEC validation working

### Test IPv6 Leaks:
```
https://test-ipv6.com/
```
Should show no IPv6 connectivity (or VPN IPv6 if configured)

### Browser Fingerprinting:
```
https://amiunique.org/
```
VPN should improve your privacy score

## Benchmarking

### Compare Before/After:

| Metric | Without VPN | With VPN+AdBlock |
|--------|-------------|------------------|
| Ads on CNN.com | ~20 | ~2 |
| Page load time | 3.5s | 2.8s |
| Data transferred | 5.2MB | 2.1MB |
| Tracking scripts | 15 | 2 |

## Automated Test Script

```bash
#!/bin/bash
echo "Testing VPN and Ad Blocking..."
echo ""

echo "1. Current IP:"
curl -s ifconfig.me
echo ""

echo "2. DNS Server:"
nslookup -type=txt test.example.com | grep "Server:"
echo ""

echo "3. Testing ad domain (should be blocked):"
curl -I -s doubleclick.net | head -1
echo ""

echo "4. Pi-hole Stats:"
kubectl exec -n vpn $(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}') -- pihole -c -e
```

## Success Criteria

✅ IP changed to VPN server
✅ DNS set to Pi-hole (10.43.100.100)
✅ 90%+ ads blocked on test sites
✅ Pi-hole dashboard showing blocked queries
✅ No DNS leaks
✅ Websites load properly (with whitelisting as needed)
✅ Mobile apps show fewer ads

If all criteria are met: **Your VPN with Ad Blocking is working perfectly!** 🎉

