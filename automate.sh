#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f lt.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
fi

# --- 2. INSTALL TOOLS ---
echo "📥 Installing Localtunnel..."
npm install -g localtunnel --silent

# --- 3. START THE TUNNEL ---
SUBDOMAIN="zx-survival"
echo "🔗 Starting Localtunnel on Port 25565..."
# We use 'npx' to ensure it runs correctly in the runner environment
lt --port 25565 --subdomain $SUBDOMAIN > lt.log 2>&1 &
LT_PID=$!

# --- 4. BYPASS PASSWORD & IP (Crucial for Handshake) ---
echo "------------------------------------------------"
echo "🔑 LOCALTUNNEL BYPASS IP: "
curl -s https://loca.lt/mytunnelpassword
echo -e "\n(Visit https://$SUBDOMAIN.loca.lt in a browser and enter this IP to unlock)"
echo "------------------------------------------------"

# --- 5. WATCHDOG ---
(
    while true; do
        sleep 60
        if ! ps -p $LT_PID > /dev/null; then
            echo "⚠️ Tunnel died. Restarting..."
            lt --port 25565 --subdomain $SUBDOMAIN > lt.log 2>&1 &
            LT_PID=$!
        fi
        # Keeps the GitHub Action from timing out for being "idle"
        echo "⏳ Server heartbeat: $(date)"
    done
) &

# 5-hour kill switch
(
  sleep 18000
  echo "say [System] 5-hour limit reached. Saving..." > server_input
  echo "save-all" > server_input
  sleep 5
  echo "stop" > server_input
) &

# --- 6. START SERVER ---
echo "🚀 Minecraft is starting on 25565..."
echo "🏠 Join Link: wss://$SUBDOMAIN.loca.lt"
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
