#!/bin/bash

# --- 1. SETUP & CLEANUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
SUBDOMAIN="zx-survival"

# Kill old processes
pkill -f "ssh.*pinggy" || true
pkill -f "node bouncer.js" || true
pkill -f "localtunnel" || true

# --- 2. DISCORD TOKEN INJECTION ---
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 3. FIX PLUGIN CONFIG (Ensure Port 8081) ---
echo "⚙️ Configuring Eaglercraft..."
mkdir -p plugins/EaglercraftXServer
cat << EOF > plugins/EaglercraftXServer/settings.yml
server:
  address: '0.0.0.0:8081'
  server_icon: 'server-icon.gif'
tls_config:
  enable_tls: false
EOF

# --- 4. START PINGGY TUNNEL (Replacing Cloudflare) ---
echo "🌐 Starting Pinggy Tunnel on Port 8081..."
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:8081 a.pinggy.io > tunnel.log 2>&1 &

# --- 5. WAIT FOR URL & SETUP BOUNCER ---
echo "⏳ Waiting for Pinggy link..."
sleep 15
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.pinggy\.link" tunnel.log | head -n 1)

if [ -n "$ADDRESS" ]; then
    FINAL_WSS=${ADDRESS/https/wss}
    echo "✅ Backend Live: $FINAL_WSS"

    # Start the Bouncer for your Static Localtunnel IP
    npm install ws --no-save
    cat << EOF > bouncer.js
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 25566 });
wss.on('connection', (ws) => {
    setTimeout(() => {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: "transfer", url: "$FINAL_WSS" }));
            setTimeout(() => ws.close(), 500);
        }
    }, 200);
});
EOF
    node bouncer.js &
    npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &

    # Send to Discord
    if [ ! -z "$DISCORD_WEBHOOK" ]; then
        curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online!**\\n🏠 **Static IP:** \`wss://$SUBDOMAIN.loca.lt\`\\n🔗 **Direct IP:** \`$FINAL_WSS\`\"}" "$DISCORD_WEBHOOK"
    fi
else
    echo "❌ Failed to get Pinggy URL. Check tunnel.log"
    cat tunnel.log
fi

# --- 6. 5-HOUR TIMER ---
(
  sleep 18000
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds!" > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 7. START SERVER ---
echo "🚀 Minecraft is starting..."
tail -f server_input | bash ./run.sh

# --- 8. SAVE & PUSH ---
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
