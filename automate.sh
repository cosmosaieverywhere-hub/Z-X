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

if ! command -v cloudflared &> /dev/null; then
    echo "📦 Installing Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
fi

# --- 2. START CLOUDFLARE (THE ENGINE) ---
echo "🌐 Starting Cloudflare Ephemeral Tunnel on Port 25565..."
cloudflared tunnel --url http://127.0.0.1:25565 > cf.log 2>&1 &

sleep 10
CF_URL=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare\.com' cf.log | head -n 1)
CLEAN_CF=$(echo "$CF_URL" | sed 's~https://~~')

if [ -z "$CF_URL" ]; then
    echo "❌ Error: Cloudflare URL not found."
    exit 1
fi

# --- 3. START SERVEO (THE NO-PASSWORD SIGNPOST) ---
SUBDOMAIN="zx-2025"
# This SSH tunnel is the "Permanent Link" - No password page, no NPM needed!
ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R $SUBDOMAIN.serveo.net:80:localhost:3000 serveo.net &

# This Node script bounces people from Serveo to Cloudflare instantly
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
echo "-----------------------------------------------------"
echo "🎮 SERVER READY!"
echo "🔗 JOIN LINK: https://$SUBDOMAIN.serveo.net"
echo "🎮 DIRECT WSS: wss://$CLEAN_CF/"
echo "-----------------------------------------------------"

curl -H "Content-Type: application/json" \
     -X POST \
     -d "{
           \"content\": \"🚀 **Z-X Survival is ONLINE!**\",
           \"embeds\": [{
             \"title\": \"Server Connection Details\",
             \"color\": 3066993,
             \"fields\": [
               { \"name\": \"Permanent Link (No Password)\", \"value\": \"https://$SUBDOMAIN.serveo.net\", \"inline\": false },
               { \"name\": \"Direct Eagler WSS\", \"value\": \"\`wss://$CLEAN_CF/\`\", \"inline\": false }
             ],
             \"footer\": { \"text\": \"Session: 5 Hours | No Security Bypass Needed\" }
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
pkill -P $$ 
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Automated backup: $(date)" || echo "No changes"
git pull --rebase origin main
git push origin main
