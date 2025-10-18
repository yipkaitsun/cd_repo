#!/bin/bash

# Pi-hole Blocklist Auto-Installer 2025
# This script adds curated blocklists to your Pi-hole instance

echo "================================================"
echo "Pi-hole Blocklist Auto-Installer 2025"
echo "================================================"
echo ""

# Get Pi-hole pod name
PIHOLE_POD=$(kubectl get pods -n vpn -l app=pihole -o jsonpath='{.items[0].metadata.name}')

if [ -z "$PIHOLE_POD" ]; then
    echo "❌ Error: Pi-hole pod not found in vpn namespace"
    echo "Please deploy Pi-hole first: kubectl apply -f pihole-adblock.yaml"
    exit 1
fi

echo "✅ Found Pi-hole pod: $PIHOLE_POD"
echo ""

# Function to add blocklist
add_blocklist() {
    local url=$1
    local comment=$2
    echo "Adding: $comment"
    kubectl exec -n vpn $PIHOLE_POD -- sqlite3 /etc/pihole/gravity.db \
        "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$url', 1, '$comment');"
}

echo "Select blocklist profile:"
echo "1) Balanced (Recommended) - Good blocking, minimal issues"
echo "2) Aggressive - More blocking, may need whitelisting"
echo "3) Maximum - Most blocking, requires regular whitelisting"
echo "4) Custom - Essential lists only, you add more manually"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo "Installing BALANCED profile..."
        echo ""
        
        # Hagezi Set and Forget
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/multi.txt" "Hagezi Multi"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/popupads.txt" "Hagezi Popup Ads"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt" "Hagezi TIF"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/fake.txt" "Hagezi Fake Sites"
        
        # Essential Core
        add_blocklist "https://v.firebog.net/hosts/Easylist.txt" "EasyList"
        add_blocklist "https://v.firebog.net/hosts/Easyprivacy.txt" "EasyPrivacy"
        add_blocklist "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt" "AdGuard DNS"
        add_blocklist "https://small.oisd.nl/" "OISD Basic"
        add_blocklist "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext" "Peter Lowe"
        
        # Security
        add_blocklist "https://urlhaus.abuse.ch/downloads/hostfile/" "URLhaus Malware"
        add_blocklist "https://phishing.army/download/phishing_army_blocklist_extended.txt" "Phishing Army"
        
        # Specific blockers
        add_blocklist "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt" "NoCoin"
        add_blocklist "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt" "Smart TV Ads"
        ;;
        
    2)
        echo ""
        echo "Installing AGGRESSIVE profile..."
        echo ""
        
        # All Balanced lists
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/multi.txt" "Hagezi Multi"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/popupads.txt" "Hagezi Popup Ads"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/tif.txt" "Hagezi TIF"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/fake.txt" "Hagezi Fake Sites"
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/pro.txt" "Hagezi Pro"
        
        # Essential Core
        add_blocklist "https://v.firebog.net/hosts/Easylist.txt" "EasyList"
        add_blocklist "https://v.firebog.net/hosts/Easyprivacy.txt" "EasyPrivacy"
        add_blocklist "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt" "AdGuard DNS"
        add_blocklist "https://small.oisd.nl/" "OISD Basic"
        add_blocklist "https://o0.pages.dev/Lite/adblock.txt" "1Hosts Lite"
        
        # More comprehensive lists
        add_blocklist "https://someonewhocares.org/hosts/zero/hosts" "Dan Pollock"
        add_blocklist "https://adaway.org/hosts.txt" "AdAway"
        add_blocklist "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" "Steven Black"
        
        # Security
        add_blocklist "https://urlhaus.abuse.ch/downloads/hostfile/" "URLhaus Malware"
        add_blocklist "https://phishing.army/download/phishing_army_blocklist_extended.txt" "Phishing Army"
        add_blocklist "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt" "Anti-Malware"
        
        # Specific
        add_blocklist "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt" "NoCoin"
        add_blocklist "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt" "Smart TV Ads"
        add_blocklist "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt" "Windows Telemetry"
        ;;
        
    3)
        echo ""
        echo "Installing MAXIMUM profile..."
        echo ""
        
        # Ultimate blocking
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/ultimate.txt" "Hagezi Ultimate"
        
        # All aggressive lists
        add_blocklist "https://v.firebog.net/hosts/Easylist.txt" "EasyList"
        add_blocklist "https://v.firebog.net/hosts/Easyprivacy.txt" "EasyPrivacy"
        add_blocklist "https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt" "AdGuard DNS"
        add_blocklist "https://big.oisd.nl/" "OISD Big"
        add_blocklist "https://someonewhocares.org/hosts/zero/hosts" "Dan Pollock"
        add_blocklist "https://adaway.org/hosts.txt" "AdAway"
        add_blocklist "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" "Steven Black"
        
        # Security
        add_blocklist "https://urlhaus.abuse.ch/downloads/hostfile/" "URLhaus Malware"
        add_blocklist "https://phishing.army/download/phishing_army_blocklist_extended.txt" "Phishing Army"
        add_blocklist "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt" "Anti-Malware"
        add_blocklist "https://raw.githubusercontent.com/davidonzo/Threat-Intel/master/lists/latestdomains.txt" "Risk Analytics"
        
        # Specific
        add_blocklist "https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt" "NoCoin"
        add_blocklist "https://raw.githubusercontent.com/Perflyst/PiHoleBlocklist/master/SmartTV.txt" "Smart TV Ads"
        add_blocklist "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt" "Windows Telemetry"
        add_blocklist "https://raw.githubusercontent.com/r-a-y/mobile-hosts/master/AdguardMobileAds.txt" "Mobile Ads"
        add_blocklist "https://raw.githubusercontent.com/pixeltris/TwitchAdSolutions/master/dnsblock.txt" "Twitch Ads"
        add_blocklist "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt" "KADhosts"
        ;;
        
    4)
        echo ""
        echo "Installing CUSTOM (Essential only) profile..."
        echo ""
        
        # Minimal essential lists
        add_blocklist "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/light.txt" "Hagezi Light"
        add_blocklist "https://v.firebog.net/hosts/Easylist.txt" "EasyList"
        add_blocklist "https://v.firebog.net/hosts/Easyprivacy.txt" "EasyPrivacy"
        add_blocklist "https://small.oisd.nl/" "OISD Basic"
        add_blocklist "https://urlhaus.abuse.ch/downloads/hostfile/" "URLhaus Malware"
        ;;
        
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "✅ Blocklists added to database"
echo ""
echo "Updating Gravity (this may take a few minutes)..."
kubectl exec -n vpn $PIHOLE_POD -- pihole -g

echo ""
echo "================================================"
echo "✅ Installation Complete!"
echo "================================================"
echo ""
echo "Blocklists have been added and Gravity updated."
echo ""
echo "Access Pi-hole dashboard:"
echo "  kubectl port-forward -n vpn svc/pihole-web 8888:80"
echo "  Then open: http://localhost:8888/admin"
echo ""
echo "Test ad blocking:"
echo "  https://d3ward.github.io/toolz/adblock.html"
echo ""
echo "View statistics:"
kubectl exec -n vpn $PIHOLE_POD -- pihole -c -e

echo ""
echo "If you need to whitelist a domain:"
echo "  kubectl exec -n vpn $PIHOLE_POD -- pihole -w example.com"
echo ""

