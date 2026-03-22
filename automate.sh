#!/bin/bash

# --- 1. SETUP & SECRETS ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# Install Dependencies
echo "📦 Installing Network Tools..."
sudo apt-get update && sudo apt-get install -y wireguard-tools
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
fi

# --- 2. START CLOUDFLARE (THE ENGINE) ---
echo "🌐 Starting Cloudflare Ephemeral Tunnel..."
cloudflared tunnel --url http://127.0.0.1:25565 > cf.log 2>&1 &

sleep 10
CF_URL=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare\.com' cf.log | head -n 1)
CLEAN_CF=$(echo "$CF_URL" | sed 's~https://~~')

if [ -z "$CF_URL" ]; then
    echo "❌ Error: Cloudflare URL not found."
    exit 1
fi

# --- 3. START WIREGUARD (THE PRO TUNNEL) ---
echo "⚙️ Configuring WireGuard for zx.serveousercontent.com..."

# FIX: Using 'tee' with sudo to avoid Permission Denied error
sudo mkdir -p /etc/wireguard
cat <<EOF | sudo tee /etc/wireguard/serveo.conf > /dev/null
[Interface]
PrivateKey = UPbZUMnsC6mwyBimUfijp1hCtAV3pQ3AIa+jKG1VcW4=
Address = fd1d:84e3:8aca:1:beb:4c17:e55:1231/128

[Peer]
PublicKey = dnu982a30YcXBh3Zy4PlPM6nbfavgfOyxx629AO7VEU=
AllowedIPs = fd1d:84e3:8aca::/48
Endpoint = wg.serveo.net:51820
PersistentKeepalive = 25
EOF

sudo wg-quick up serveo
sleep 5

# Start the Redirect Server on Port 3000
cat <<EOF > redirect-server.js
const http = require('http');
const server = http.createServer((req, res) => {
    res.writeHead(301, { "Location": "$CF_URL" });
    res.end();
});
server.listen(3000);
EOF
node redirect-server.js &

# --- 4. DISCORD NOTIFICATION ---
MY_HOSTNAME="zx.serveousercontent.com"

echo "-----------------------------------------------------"
echo "🎮 SERVER READY!"
echo "🔗 JOIN LINK: https://$MY_HOSTNAME"
echo "🎮 DIRECT WSS: wss://$CLEAN_CF/"
echo "-----------------------------------------------------"

curl -H "Content-Type: application/json" \
     -X POST \
     -d "{
           \"content\": \"🚀 **Z-X Survival is ONLINE!**\",
           \"embeds\": [{
             \"title\": \"Registered Connection Details\",
             \"color\": 3066993,
             \"fields\": [
               { \"name\": \"Permanent Link\", \"value\": \"https://$MY_HOSTNAME\", \"inline\": false },
               { \"name\": \"Direct Eagler WSS\", \"value\": \"\`wss://$CLEAN_CF/\`\", \"inline\": false }
             ],
             \"footer\": { \"text\": \"Session: 5 Hours | WireGuard Optimized\" }
           }]
         }" \
     "https://discord.com/api/webhooks/1485309593742475438/YTuVxDuv8WqXN6gwJARR_ZroTmPl8JEju7AQit_2gmVpMTmS75l2i6xm7VuewBmSzYeA"

# --- 5. 5-HOUR AUTO-STOP & START SERVER ---
(
  sleep 17970
  echo "stop" > server_input
) &

echo "🚀 Eaglercraft Server starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 6. CLEANUP & SAVE ---
sudo wg-quick down serveo
pkill -P $$ 
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Automated backup: $(date)" || echo "No changes"
git pull --rebase origin main
git push origin main
