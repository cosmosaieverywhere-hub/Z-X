#!/bin/bash

# --- 1. CONFIG & CLEANUP ---
SUBDOMAIN="zx-survival"
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
rm -f server_input && mkfifo server_input
rm -f tunnel.log
pkill -f "node bouncer.js" || true
pkill -f "ssh.*pinggy" || true
pkill -f "localtunnel" || true

# --- 2. REPAIR & CONFIGURE PLUGINS ---
echo "🧹 Fixing EaglercraftXServer Plugin..."
# Redownload if corrupted (fixes the Zip END header error)
if [ ! -f "plugins/EaglercraftXServer.jar" ] || ! unzip -t plugins/EaglercraftXServer.jar > /dev/null 2>&1; then
    curl -L "https://github.com/lax1dude/eaglerxserver/releases/latest/download/EaglerXServer.jar" -o plugins/EaglercraftXServer.jar
fi

# Force the correct port (8081) and GIF icon support in settings.yml
mkdir -p plugins/EaglercraftXServer
if [ -f "plugins/EaglercraftXServer/settings.yml" ]; then
    sed -i "s/address: .*/address: '0.0.0.0:8081'/" plugins/EaglercraftXServer/settings.yml
    sed -i "s/enable_tls: true/enable_tls: false/" plugins/EaglercraftXServer/settings.yml
    # Set this to .gif if you uploaded a gif!
    sed -i "s/server_icon: .*/server_icon: 'server-icon.gif'/" plugins/EaglercraftXServer/settings.yml
fi

# --- 3. INSTALL DEPENDENCIES ---
echo "📦 Installing WebSocket library..."
npm install ws --no-save

# --- 4. START TUNNEL ON 8081 (The WebSocket Port) ---
echo "🌐 Starting Pinggy Tunnel..."
ssh -o StrictHostKeyChecking=no -p 443 -R0:localhost:8081 a.pinggy.io > tunnel.log 2>&1 &

sleep 10
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.pinggy\.link" tunnel.log | head -n 1)

if [ -z "$ADDRESS" ]; then
    echo "❌ Failed to get Tunnel URL. Logs:"
    cat tunnel.log
    exit 1
fi

FINAL_WSS=${ADDRESS/https/wss}
echo "✅ Tunnel Ready: $FINAL_WSS"

# --- 5. START GHOST BOUNCER ---
echo "👻 Starting Bouncer on Port 25566..."
cat << EOF > bouncer.js
const WebSocket = require('ws');
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

# --- 6. START LOCALTUNNEL & MINECRAFT ---
echo "🔗 Registering Static IP: wss://$SUBDOMAIN.loca.lt"
npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &

echo "🚀 Minecraft is starting. Port 25565 (Internal) -> Port 8081 (WebSocket) -> Internet"
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
