#!/bin/bash

# --- 1. SETUP & SECRETS ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token if the config exists
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s/token: \".*\"/token: \"$ESSENTIALS_DISCORD_TOKEN\"/" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found at $CONFIG_PATH"
fi

# --- 2. START BOOSTED LOCALTUNNEL ---
SUBDOMAIN="zx-survival"
echo "📥 Creating High-Concurrency Tunnel Booster..."
npm install localtunnel --silent

# Create the JS Booster file - POINTING TO MC PORT 25565
cat <<EOF > lt-booster.js
const localtunnel = require('localtunnel');
(async () => {
    const tunnel = await localtunnel({ 
        port: 25565, 
        subdomain: '$SUBDOMAIN',
        local_host: '127.0.0.1'
    });
    console.log('✅ Tunnel Live: ' + tunnel.url);
    tunnel.on('close', () => { process.exit(1); });
})();
EOF

# Function to start the tunnel
start_booster() {
    node lt-booster.js >> tunnel.log 2>&1 &
    LT_PID=$!
}

start_booster

# --- 3. BYPASS & WATCHDOG ---
(
    while true; do
        sleep 45
        if ! ps -p $LT_PID > /dev/null; then
            echo "⚠️ Tunnel process died. Restarting..."
            start_booster
        fi
    done
) &

# Get the bypass password (you need this for the first-time browser visit)
echo "-----------------------------------------------------"
echo "🔑 LOCALTUNNEL BYPASS PASSWORD (IP):"
curl -s https://loca.lt/mytunnelpassword
echo -e "\n-----------------------------------------------------"
echo "✅ Join Link: wss://$SUBDOMAIN.loca.lt"
echo "-----------------------------------------------------"

# --- 4. 5-HOUR AUTO-STOP TIMER ---
(
  sleep 17970
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! Saving world..." > server_input
    sleep 1
  done
  echo "save-all" > server_input
  sleep 2
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
echo "🚀 Eaglercraft Server starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 6. CLEANUP & SAVE ---
echo "🔕 Server stopped. Cleaning up..."
pkill -P $$ 

echo "💾 Saving world data and pushing to GitHub..."
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

git add .
# Don't save the secret token back to the repo
git reset "$CONFIG_PATH"

git commit -m "Automated backup: $(date)" || echo "No changes to commit"
git pull --rebase origin main
git push origin main

echo "✅ 5-hour session complete. Data saved."
