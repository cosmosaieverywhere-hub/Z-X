#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    # Replace any existing token value with the secret from GitHub
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found at $CONFIG_PATH"
fi


# --- 2. INSTALL CLOUDFLARE ---
echo "📥 Installing Cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared

# --- 3. START TUNNEL (AUTO-RESTARTING) ---
echo "🌐 Starting Cloudflare Quick Tunnel..."
(
    while true; do
        ./cloudflared tunnel --url http://localhost:25565 >> tunnel.log 2>&1
        sleep 5 # If it crashes, wait 5 seconds and restart
    done
) &

# --- 4. WAIT FOR URL & SEND TO DISCORD ---
echo "⏳ Waiting for Cloudflare to generate link..."
sleep 10
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" tunnel.log | head -n 1)

if [ -n "$ADDRESS" ]; then
    # Convert https:// to wss:// for Eaglercraft
    IP=${ADDRESS/https/wss}
    echo "✅ Server Live at: $IP"
    curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online (Cloudflare)!**\\n🔗 **IP:** \`$IP\`\\n⏰ **Status:** Online for 4 hours.\"}" "$DISCORD_WEBHOOK"
else
    echo "❌ Failed to get Cloudflare URL. Printing logs:"
    cat tunnel.log
fi
# --- 4. 4-HOUR TIMER WITH 30s COUNTDOWN ---
(
  sleep 18000  # Wait until 6:59:30 PM IST   14370
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Thank you for joining the server :)" > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
tail -f server_input | bash ./run.sh

# --- 6. PUSH BACK TO GITHUB ---
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .

# 2. Specifically unstage the config file so it won't be committed
git reset "$CONFIG_PATH"

# 3. Commit and push the rest
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git push origin main
