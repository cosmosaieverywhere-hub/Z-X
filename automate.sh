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
# Install Cloudflared (for the high-speed tunnel)
if ! command -v cloudflared &> /dev/null; then
    echo "📦 Installing Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb
fi

# ... (Keep your Discord Token injection code here) ...

# --- 2. START CLOUDFLARE (THE ENGINE) ---
echo "🌐 Starting Cloudflare Ephemeral Tunnel on Port 25565..."
# Start CF and log it to a file so we can scrape the random URL
cloudflared tunnel --url http://127.0.0.1:25565 > cf.log 2>&1 &

# Wait for the URL to generate (usually takes 5-10 seconds)
sleep 10
CF_URL=$(grep -o 'https://[-a-z0-9.]*\.trycloudflare\.com' cf.log | head -n 1)

if [ -z "$CF_URL" ]; then
    echo "❌ Error: Cloudflare URL not found. Check cf.log."
    exit 1
fi

echo "✅ Cloudflare Link: $CF_URL"

# --- 3. START LOCALTUNNEL (THE SIGNPOST) ---
SUBDOMAIN="zx-survival"
npm install localtunnel --silent

# This script creates a Redirect Server on Port 3000
# It sends anyone who visits your LT link directly to the new CF link
cat <<EOF > lt-booster.js
const localtunnel = require('localtunnel');
const http = require('http');

const server = http.createServer((req, res) => {
    res.setHeader("bypass-tunnel-reminder", "true");
    res.writeHead(301, { "Location": "$CF_URL" });
    res.end();
});
server.listen(3000);

(async () => {
    const tunnel = await localtunnel({ 
        port: 3000, 
        subdomain: '$SUBDOMAIN' 
    });
    console.log('✅ Entry Point Live: ' + tunnel.url);
})();
EOF

node lt-booster.js >> tunnel.log 2>&1 &
LT_PID=$!

# --- 4. BYPASS & WATCHDOG ---
echo "-----------------------------------------------------"
echo "🎮 SERVER READY!"
echo "🔗 JOIN LINK (Permanent): https://$SUBDOMAIN.loca.lt"
echo "🔑 BYPASS PASSWORD (IP): $(curl -s https://loca.lt/mytunnelpassword)"
echo "-----------------------------------------------------"

# ... (Keep your Watchdog, Timer, and Start Server code here) ...

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
# Don't save the secret token back to the repo
git reset "$CONFIG_PATH"

git commit -m "Automated backup: $(date)" || echo "No changes to commit"
git pull --rebase origin main
git push origin main

echo "✅ 5-hour session complete. Data saved."
