#!/bin/bash

# --- 1. SETUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

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

# Create the JS Booster file
cat <<EOF > lt-booster.js
const localtunnel = require('localtunnel');
(async () => {
    const tunnel = await localtunnel({ 
        port: 25565, 
        subdomain: '$SUBDOMAIN',
        local_host: '127.0.0.1',
        maxSockets: 100 
    });
    console.log('✅ Tunnel Live: ' + tunnel.url.replace('https', 'wss'));
    tunnel.on('close', () => { process.exit(1); });
})();
EOF

# Function to start the tunnel
start_booster() {
    node lt-booster.js >> tunnel.log 2>&1 &
    LT_PID=$!
}

start_booster

# --- 3. WATCHDOG ---
(
    while true; do
        sleep 45
        # Check if the process ID exists
        if ! ps -p $LT_PID > /dev/null; then
            echo "⚠️ Tunnel process died. Restarting..."
            start_booster
        fi
    done
) &

echo "✅ Join Link: wss://$SUBDOMAIN.loca.lt"

# --- 4. 4-HOUR TIMER ---
(
  sleep 18000
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds!" > server_input
    sleep 1
  done
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
echo "🚀 Server is starting..."
( tail -f server_input & ) | bash ./run.sh

# --- 6. CLEANUP & SAVE ---
echo "🔕 Server stopped. Cleaning up..."
pkill -P $$ 

echo "💾 Saving world to GitHub..."
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

git add .
git reset "$CONFIG_PATH"
git commit -m "Automated Save: $(date)" || echo "No changes to save"
git pull --rebase origin main
git push origin main
echo "✅ World saved successfully!"
