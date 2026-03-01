#!/bin/bash

# --- 1. CONFIG & CLEANUP ---
SUBDOMAIN="zx-survival"
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
rm -f server_input && mkfifo server_input
rm -f tunnel.log
pkill -f "node bouncer.js" || true
pkill -f "cloudflared" || true
pkill -f "localtunnel" || true

# --- 2. DISCORD TOKEN INJECTION ---
if [ -f "$CONFIG_PATH" ]; then
    echo "🔑 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 3. START TUNNEL (Pinggy Alternative) ---
echo "🌐 Starting Pinggy Tunnel (HTTPS/WSS)..."
# We use SSH to create a tunnel to port 8081
# The '-o StrictHostKeyChecking=no' prevents the script from hanging on a yes/no prompt
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:25565 a.pinggy.io > tunnel.log 2>&1 &

# Wait for Pinggy to generate the URL
sleep 10
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.pinggy\.link" tunnel.log | head -n 1)

if [ -z "$ADDRESS" ]; then
    echo "❌ Failed to get Tunnel URL. Printing logs:"
    cat tunnel.log
    exit 1
fi

# Convert https:// to wss:// for Eaglercraft
FINAL_WSS=${ADDRESS/https/wss}
echo "✅ Tunnel Ready: $FINAL_WSS"


# --- 4. START GHOST BOUNCER (Frontend Redirection) ---
echo "👻 Starting Bouncer..."
cat << EOF > bouncer.js
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 25565 });
wss.on('connection', (ws) => {
    setTimeout(() => {
        if (ws.readyState === WebSocket.OPEN) {
            // We send the player to the WSS version of your HTTPS link
            ws.send(JSON.stringify({ type: "transfer", url: "$FINAL_WSS" }));
            setTimeout(() => ws.close(), 300);
        }
    }, 150);
});
EOF
node bouncer.js &

echo "🔗 Registering Static IP: wss://$SUBDOMAIN.loca.lt"
npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &


# --- 6. START MINECRAFT SERVER ---
echo "🚀 Minecraft is starting..."
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
