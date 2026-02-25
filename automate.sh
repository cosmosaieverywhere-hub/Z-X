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


# --- 3. START SERVEO WITH PERMANENT SUBDOMAIN ---
# CHANGE THIS to something unique like 'zx-survival-2026'
SUBDOMAIN="zx-survival" 

echo "🌐 Requesting Permanent IP: $SUBDOMAIN.serveo.net"

start_serveo() {
    # -o ServerAliveInterval=60 keeps the connection from idling
    # -R $SUBDOMAIN:80:localhost:25565 maps your server to the subdomain
    ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -R "$SUBDOMAIN":80:localhost:25565 serveo.net >> serveo.log 2>&1 &
    SERVEO_PID=$!
}

start_serveo

# --- WATCHDOG ---
(
    while true; do
        sleep 30
        # If the tunnel dies, restart it immediately
        if ! ps -p $SERVEO_PID > /dev/null; then
            echo "⚠️ Tunnel disconnected. Reconnecting..."
            start_serveo
        fi
    done
) &

echo "✅ Server IP: wss://$SUBDOMAIN.serveo.net"

# --- 4. WAIT & ANNOUNCE ---
echo "⏳ Waiting for Localtunnel to stabilize..."
sleep 10
IP="wss://$SUBDOMAIN.loca.lt"


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
