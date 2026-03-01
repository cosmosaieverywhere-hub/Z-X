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

# --- 3. START CLOUDFLARE (HTTP Mode for HTTPS Link) ---
echo "📥 Setting up Cloudflared..."
if [ ! -f "./cloudflared" ]; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
    chmod +x cloudflared
fi

echo "🌐 Starting Cloudflare (Generating HTTPS Link)..."
# We tunnel the Eaglercraft port (usually 8081 if using the plugin)
./cloudflared tunnel --url http://localhost:25565 >> tunnel.log 2>&1 &

# Wait for the URL to generate
sleep 12
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" tunnel.log | head -n 1)

if [ -z "$ADDRESS" ]; then
    echo "❌ Failed to get Cloudflare URL. Printing logs:"
    cat tunnel.log
    exit 1
fi

# This is your HTTPS link
FINAL_HTTPS="$ADDRESS"
# This is the WSS link the game needs
FINAL_WSS=${ADDRESS/https/wss}

echo "✅ HTTPS Link Ready: $FINAL_HTTPS"

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
