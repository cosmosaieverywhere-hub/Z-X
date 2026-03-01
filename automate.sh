#!/bin/bash

# --- 1. CONFIG & CLEANUP ---
SUBDOMAIN="zx-survival"
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
rm -f server_input && mkfifo server_input
rm -f tunnel.log
pkill -f "node bouncer.js" || true
pkill -f "ssh.*pinggy" || true
pkill -f "localtunnel" || true

# --- 2. INSTALL DEPENDENCIES ---
echo "📦 Installing WebSocket library..."
npm install ws --no-save

# --- 3. START TUNNEL (Backend Data) ---
echo "🌐 Starting Pinggy Tunnel..."
# Tunnel points to the Minecraft Server port (25565)
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:25565 a.pinggy.io > tunnel.log 2>&1 &

sleep 10
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.pinggy\.link" tunnel.log | head -n 1)

if [ -z "$ADDRESS" ]; then
    echo "❌ Failed to get Tunnel URL. Logs:"
    cat tunnel.log
    exit 1
fi

FINAL_WSS=${ADDRESS/https/wss}
echo "✅ Tunnel Ready: $FINAL_WSS"

# --- 4. START GHOST BOUNCER (Frontend Redirection) ---
echo "👻 Starting Bouncer on Port 25566..."
cat << EOF > bouncer.js
const WebSocket = require('ws');
// Bouncer MUST be on a different port than the Minecraft Server
const wss = new WebSocket.Server({ port: 25566 });
wss.on('connection', (ws) => {
    setTimeout(() => {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: "transfer", url: "$FINAL_WSS" }));
            setTimeout(() => ws.close(), 300);
        }
    }, 150);
});
EOF
node bouncer.js &

# --- 5. START LOCALTUNNEL ---
echo "🔗 Registering Static IP: wss://$SUBDOMAIN.loca.lt"
# Localtunnel points to the Bouncer (25566)
npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &

# --- 6. START MINECRAFT SERVER ---
echo "🚀 Minecraft is starting on 25565..."
# The server runs on 25565. Pinggy sends players here AFTER the bounce.
( tail -f server_input & ) | bash ./run.sh

# --- 7. SAVE & PUSH ---
echo "💾 Saving world data..."
pkill -P $$ 
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Auto-Save: $(date)" || echo "No changes to save"
git push origin main
