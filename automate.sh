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

# --- 3. START BOOSTED LOCALTUNNEL ---
SUBDOMAIN="zx-survival"

echo "📥 Installing/Updating Localtunnel..."
npm install -g localtunnel

# Function to start the tunnel with high-performance flags
start_tunnel() {
    # --local-host 127.0.0.1 forces LT to use a direct loopback, reducing lag
    # We use a custom host if the main one is full (optional)
    lt --port 25565 --subdomain "$SUBDOMAIN" --local-host 127.0.0.1 >> tunnel.log 2>&1 &
    LT_PID=$!
}

start_tunnel

# --- WATCHDOG (Now with 'Life Check') ---
(
    while true; do
        sleep 45
        # If the process is dead OR the URL isn't responding, restart it
        if ! ps -p $LT_PID > /dev/null || ! curl -s "https://$SUBDOMAIN.loca.lt" > /dev/null; then
            echo "⚠️ Tunnel crashed or blocked. Force restarting..."
            pkill -f localtunnel
            sleep 2
            start_tunnel
        fi
    done
) &

echo "✅ Join Link: wss://$SUBDOMAIN.loca.lt"
# --- 4. 4-HOUR TIMER WITH 30s COUNTDOWN ---
(
  sleep 18000   # Wait until 6:59:30 PM IST   14370 18000 
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
