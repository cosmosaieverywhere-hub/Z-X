#!/bin/bash

# --- 1. SETUP & CLEANUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
SUBDOMAIN="zx-survival"

# Kill any lingering processes from previous runs
pkill -f "cloudflared" || true
pkill -f "node bouncer.js" || true
pkill -f "localtunnel" || true

# --- 2. DISCORD TOKEN INJECTION ---
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found."
fi

# --- 3. INSTALL CLOUDFLARE ---
if [ ! -f "./cloudflared" ]; then
    echo "📥 Installing Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
    chmod +x cloudflared
fi

# --- 4. START TUNNEL (AUTO-RESTARTING) ---
echo "🌐 Starting Cloudflare Quick Tunnel..."
(
    while true; do
        ./cloudflared tunnel --url http://localhost:25565 >> tunnel.log 2>&1
        sleep 5 
    done
) &

# --- 5. WAIT FOR URL & SETUP BOUNCER ---
echo "⏳ Waiting for Cloudflare link..."
sleep 15
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" tunnel.log | head -n 1)

if [ -n "$ADDRESS" ]; then
    FINAL_WSS=${ADDRESS/https/wss}
    echo "✅ Backend Live: $FINAL_WSS"

    # Start the Bouncer to point the Static IP to this new Cloudflare link
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

    # Start Localtunnel for the Static IP
    npx localtunnel --port 25566 --subdomain "$SUBDOMAIN" > lt.log 2>&1 &

    # Send to Discord
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online!**\\n🏠 **Static IP:** \`wss://$SUBDOMAIN.loca.lt\`\\n🔗 **Direct IP:** \`$FINAL_WSS\`\\n⏰ **Status:** Online for 5 hours.\"}" "$DISCORD_WEBHOOK"
else
    echo "❌ Failed to get Cloudflare URL. Check tunnel.log"
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
tail -f server_input | bash ./run.sh

# --- 8. SAVE & PUSH ---
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
