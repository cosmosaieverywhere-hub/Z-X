#!/bin/bash

# --- 1. CONFIG & CLEANUP ---
SUBDOMAIN="zx-survival"
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
rm -f server_input && mkfifo server_input
pkill -f "node bouncer.js" || true
pkill -f "cloudflared" || true
pkill -f "localtunnel" || true

# --- 2. DISCORD TOKEN INJECTION ---
if [ -f "$CONFIG_PATH" ]; then
    echo "🔑 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 3. DEPENDENCIES ---
echo "📦 Installing Networking Tools..."
npm install ws localtunnel -g || npm install ws localtunnel 

# --- 4. THE GHOST BOUNCER (Embedded Node.js) ---
# This script catches players on Localtunnel and shoots them to Cloudflare.
cat << 'EOF' > bouncer.js
const WebSocket = require('ws');
const TARGET_CF_URL = process.argv[2]; 
const wss = new WebSocket.Server({ port: 25566 });

console.log(`🚀 Bouncer Active. Target: ${TARGET_CF_URL}`);

wss.on('connection', (ws) => {
    // Wait 150ms to ensure the handshake is stable
    setTimeout(() => {
        if (ws.readyState === WebSocket.OPEN) {
            // Eaglercraft Transfer Packet
            ws.send(JSON.stringify({
                type: "transfer", 
                url: TARGET_CF_URL
            }));
            console.log("⚡ Player Handover: LT -> Cloudflare");
            // Disconnect from LT after 300ms so the 2-player limit is never hit
            setTimeout(() => ws.close(), 300);
        }
    }, 150);
});
EOF

# --- 5. START CLOUDFLARE (The Speed) ---
echo "🌐 Setting up Cloudflare..."

# Download cloudflared if it doesn't exist
if [ ! -f "./cloudflared" ]; then
    echo "📥 Downloading Cloudflare Binary..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
    chmod +x cloudflared
fi

echo "📡 Opening High-Speed Tunnel..."
./cloudflared tunnel --url tcp://localhost:25565 > cloudflare.log 2>&1 &

# Wait and verify the URL
MAX_RETRIES=30
COUNT=0
STABLE_ADDR=""

while [ -z "$STABLE_ADDR" ] && [ $COUNT -lt $MAX_RETRIES ]; do
    STABLE_ADDR=$(grep -oE "[a-zA-Z0-9.-]+\.tcp\.cloudflare\.com:[0-9]+" cloudflare.log | head -n 1)
    sleep 1
    ((COUNT++))
done

if [ -z "$STABLE_ADDR" ]; then
    echo "❌ Error: Cloudflare Tunnel failed. Content of cloudflare.log:"
    cat cloudflare.log
    exit 1
fi
FINAL_WSS="wss://${STABLE_ADDR}"  

echo "🚀 Starting Ghost Bouncer on port 25566..."
node bouncer.js "$FINAL_WSS" &
BOUNCER_PID=$!

echo "🔗 Registering Static IP: wss://$SUBDOMAIN.loca.lt"
# We run this in the background so the script can continue to Minecraft
npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &

# --- 7. START MINECRAFT SERVER ---
echo "------------------------------------------------"
echo "✅ STEALTH SYSTEM ONLINE"
echo "🏠 JOIN AT: wss://$SUBDOMAIN.loca.lt"
echo "💨 DATA REDIRECT: -> $FINAL_WSS"
echo "------------------------------------------------"

# 5-hour auto-stop (18000 seconds)
(
  sleep 3600
  echo "say [SYSTEM] Server auto-restarting for backup..." > server_input
  sleep 10
  echo "stop" > server_input
) &

echo "🚀 Minecraft is starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 8. SAVE & PUSH TO GITHUB ---
echo "💾 Saving world data..."
pkill -P $$ 
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH" # Don't push the secret token
git commit -m "Auto-Save: $(date)" || echo "No changes to save"
git pull --rebase origin main
git push origin main
