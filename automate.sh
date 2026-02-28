#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token
if [ -f "$CONFIG_PATH" ]; then
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 2. INSTALL TOOLS (Cloudflared & Localtunnel) ---
echo "📥 Installing Cloudflared..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/bin/

echo "📥 Installing Localtunnel..."
npm install -g localtunnel --silent

# --- 3. START THE STABLE BACKEND (Cloudflare) ---
echo "🌐 Starting Cloudflare Stability Tunnel..."
cloudflared tunnel --url https://localhost:25565 > cloudflare.log 2>&1 &
CF_PID=$!

# --- 4. START THE LOBBY FRONT-END (Localtunnel) ---
# This gives players the easy "zx-survival.loca.lt" address
echo "🔗 Starting Localtunnel Front-End..."
lt --port 25565 --subdomain zx-survival > lt.log 2>&1 &
LT_PID=$!

# Wait a moment for links to generate
sleep 5
echo "------------------------------------------------"
echo "✅ SERVER IS ONLINE"
echo "🏠 LOBBY IP: wss://zx-survival.loca.lt"
echo "⚡ STABILITY BACKEND: Check cloudflare.log for IP"
echo "------------------------------------------------"

# --- 5. WATCHDOG (Keep both tunnels alive) ---
(
    while true; do
        sleep 30
        if ! ps -p $CF_PID > /dev/null; then
            cloudflared tunnel --url tcp://localhost:25565 >> cloudflare.log 2>&1 &
            CF_PID=$!
        fi
        if ! ps -p $LT_PID > /dev/null; then
            lt --port 25565 --subdomain zx-survival >> lt.log 2>&1 &
            LT_PID=$!
        fi
    done
) &

# 4-hour kill switch (14400 seconds)
(
  sleep 18000
  echo "stop" > server_input
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
git commit -m "Save: $(date)" || echo "No changes"
git pull --rebase origin main
git push origin main
