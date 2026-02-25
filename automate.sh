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


# --- 2. INSTALL LOCALTUNNEL ---
echo "📥 Installing Localtunnel..."
# GitHub Actions already has Node.js/npm installed
npm install -g localtunnel

# --- 3. START TUNNEL WITH FIXED SUBDOMAIN ---
# CHANGE THIS NAME to something unique to you!
SUBDOMAIN="zx-survival" 

# --- 3. START STABLE TUNNEL WITH WATCHDOG ---
echo "🌐 Starting Localtunnel on subdomain: $SUBDOMAIN"

(
    while true; do
        # 1. Start the tunnel with local-host mapping for better stability
        lt --port 25565 --subdomain "$SUBDOMAIN" --local-host 127.0.0.1 --print-requests >> tunnel.log 2>&1 &
        TUNNEL_PID=$!
        
        # 2. Watchdog: Monitor the tunnel for the next 20 minutes before a hard refresh
        for i in {1..40}; do 
            sleep 30
            
            # Check if the process is still running
            if ! ps -p $TUNNEL_PID > /dev/null; then
                echo "⚠️ Tunnel process died. Restarting..."
                break
            fi
            
            # 3. Heartbeat: Ping the URL to prevent "Idle Timeout"
            # This keeps the 'pipe' warm and active
            curl -s "https://$SUBDOMAIN.loca.lt" > /dev/null
        done
        
        # Cleanup before restart to prevent 'Zombie' processes
        kill $TUNNEL_PID 2>/dev/null
        sleep 2
    done
) &

# --- 4. WAIT & ANNOUNCE ---
echo "⏳ Waiting for Localtunnel to stabilize..."
sleep 10
IP="wss://$SUBDOMAIN.loca.lt"


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
git pull --rebase origin main

git push origin main
