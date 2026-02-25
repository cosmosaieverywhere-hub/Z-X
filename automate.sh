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
        # Old: lt --port 25565 --subdomain "$SUBDOMAIN" --local-host 127.0.0.1
# New:
        lt --port 25565 --subdomain "$SUBDOMAIN" --local-host 0.0.0.0 --print-requests >> tunnel.log 2>&1 &
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
  sleep 3600  # Wait until 6:59:30 PM IST   14370 18000 
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Thank you for joining the server :)" > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
echo "🚀 Server is starting..."
# Running tail in the background tied to the server process
# This allows the script to continue once bash ./run.sh finishes
( tail -f server_input & ) | bash ./run.sh

# --- 6. CLEANUP & SAVE ---
echo "🔕 Server stopped. Cleaning up processes..."
# Kill the background tunnel, watchdog, and tail processes
pkill -P $$ 

echo "💾 Saving world to GitHub..."
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

# 1. Stage changes
git add .

# 2. Hide the Discord token
git reset "$CONFIG_PATH"

# 3. Commit with a timestamp
git commit -m "Automated Save: $(date)" || echo "No changes to save"

# 4. Pull latest changes (to avoid the 'rejected' error)
git pull --rebase origin main

# 5. Final Push
git push origin main
echo "✅ World saved successfully!"
