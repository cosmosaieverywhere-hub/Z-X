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

# --- 3. START MINEKUBE (Permanent IP + No Login) ---
SUBDOMAIN="zx-survival" # This will be your permanent name

echo "📥 Installing Minekube Connect..."
curl -fsSL https://mgate.io/install.sh | bash

echo "🌐 Requesting Permanent IP: $SUBDOMAIN.play.minekube.net"

# We start it in the background. 
# The --name flag sets your permanent subdomain.
# The --port 8081 points to your EaglerProxy port.
./minekube-connect --name "$SUBDOMAIN" --port 8081 > tunnel.log 2>&1 &
TUNNEL_PID=$!

# Extract the final URL (usually wss:// if your proxy handles SSL)
echo "✅ Server IP: wss://$SUBDOMAIN.play.minekube.net"

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
