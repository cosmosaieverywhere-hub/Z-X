#!/bin/bash

# --- 1. SETUP & SECRETS ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token if the config exists
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found at $CONFIG_PATH"
fi

# Install Cloudflared
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

if [ -z "$CF_URL" ]; then
    echo "❌ Error: Cloudflare URL not found. Check cf.log."
    exit 1
fi
echo "✅ Cloudflare Link: $CF_URL"

# --- 3. START LOCALTUNNEL (THE BYPASS PROXY) ---
SUBDOMAIN="zx-survival"
# Install the proxy library needed to handle WebSockets and Headers
npm install localtunnel http-proxy --silent

cat <<EOF > lt-booster.js
const localtunnel = require('localtunnel');
const http = require('http');
const httpProxy = require('http-proxy');

// Create the proxy pointing to your Cloudflare URL
const proxy = httpProxy.createProxyServer({
    target: '$CF_URL',
    changeOrigin: true,
    ws: true // Crucial for Eaglercraft WebSockets
});

const server = http.createServer((req, res) => {
    // Inject the bypass header into the request before it hits Localtunnel's server
    req.headers['bypass-tunnel-reminder'] = 'true';
    proxy.web(req, res);
});

// Handle WebSocket upgrades with the same bypass header
server.on('upgrade', (req, socket, head) => {
    req.headers['bypass-tunnel-reminder'] = 'true';
    proxy.ws(req, socket, head);
});

server.listen(3000);

(async () => {
    const tunnel = await localtunnel({ port: 3000, subdomain: '$SUBDOMAIN' });
    console.log('✅ Permanent Link Active: ' + tunnel.url);
})();
EOF

node lt-booster.js >> tunnel.log 2>&1 &
LT_PID=$!

# --- 4. BYPASS & WATCHDOG ---
echo "-----------------------------------------------------"
echo "🎮 SERVER READY!"
echo "🔗 JOIN LINK: https://$SUBDOMAIN.loca.lt"
echo "✅ BYPASS ACTIVE: You should no longer need a password."
echo "-----------------------------------------------------"
# Add this right after SERVER READY!
if [ ! -z "$ESSENTIALS_DISCORD_TOKEN" ]; then
  curl -H "Content-Type: application/json" \
       -X POST \
       -d "{\"content\": \"🚀 **Server Online!**\n🔗 **Link:** $CF_URL\n🔑 **LT Password:** $(curl -s https://loca.lt/mytunnelpassword)\"}" \
       "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
fi

# --- 4. 5-HOUR AUTO-STOP TIMER ---
(
  sleep 17970
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Saving world..." > server_input
    sleep 1
  done
  echo "save-all" > server_input
  sleep 2
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
echo "🚀 Eaglercraft Server starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 6. CLEANUP & SAVE ---
echo "🔕 Server stopped. Cleaning up..."
pkill -P $$ 

echo "💾 Saving world data and pushing to GitHub..."
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

git add .
git reset "$CONFIG_PATH"

git commit -m "Automated backup: $(date)" || echo "No changes to commit"
git pull --rebase origin main
git push origin main

echo "✅ 5-hour session complete. Data saved."
