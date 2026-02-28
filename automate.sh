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
            // Disconnect from LT after 300ms so the 2-player
