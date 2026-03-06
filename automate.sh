#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log lt.log cloudflare.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 2. INSTALL TOOLS ---
echo "📥 Installing Cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/bin/

echo "📥 Installing Localtunnel..."
npm install -g localtunnel --silent

# --- 3. START TUNNELS ---
echo "🌐 Starting Cloudflare Stability Tunnel..."
cloudflared tunnel --url tcp://localhost:25565 > cloudflare.log 2>&1 &
CF_PID=$!

echo "🔗 Starting Localtunnel Front-End..."
lt --port 25565 --subdomain zx-survival > lt.log 2>&1 &
LT_PID=$!

# --- 4. BYPASS INFO ---
sleep 5
echo "------------------------------------------------"
echo "✅ SERVER IS ONLINE"
echo "🏠 LOBBY IP: wss://zx-survival.loca.lt"
echo "🔑 BYPASS PASSWORD (IP):"
curl -s https://loca.lt/mytunnelpassword
echo -e "\n------------------------------------------------"

# --- 5. WATCHDOG ---
(
    while true; do
        sleep 60
        if ! ps -p $LT_PID > /dev/null; then
            lt --port 25565 --subdomain zx-survival >> lt.log 2>&1 &
            LT_PID=$!
        fi
        echo "⏳ Heartbeat: $(date)"
    done
) &

# --- 6. START SERVER ---
echo "🚀 Minecraft is starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 7. SAVE & PUSH ---
pkill -P $$ 
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"
git add .
git reset "$CONFIG_PATH"
git commit -m "Automated Save: $(date)" || echo "No changes"
git pull --rebase origin main
git push origin main
