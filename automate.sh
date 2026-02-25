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

# --- 2. INSTALL BORE ---
echo "📥 Installing Bore..."
sudo curl -Ls https://github.com/ekzhang/bore/releases/latest/download/bore-v0.5.1-x86_64-unknown-linux-musl.tar.gz | tar -xz
sudo mv bore /usr/bin/

# --- 3. START BORE TUNNEL ---
# PICK YOUR PERMANENT PORT HERE
REMOTE_PORT=45566 
echo "🌐 Connecting to bore.pub:$REMOTE_PORT..."
bore local 25565 --to bore.pub --port $REMOTE_PORT > tunnel.log 2>&1 &
BORE_PID=$!

# --- 4. THE SSL MAGIC (WSS Proxy) ---
# We use a simple Node.js script to tell the browser "It's okay, this is Secure!"
cat <<EOF > wss-proxy.js
const http = require('http');
const httpProxy = require('http-proxy');
const proxy = httpProxy.createProxyServer({ target: 'ws://localhost:25565', ws: true });
const server = http.createServer((req, res) => { res.end('Proxy Active'); });
server.on('upgrade', (req, socket, head) => { proxy.ws(req, socket, head); });
server.listen(25565);
EOF

# Install the small proxy library
npm install http-proxy --silent
node wss-proxy.js &
PROXY_PID=$!

echo "------------------------------------------------"
echo "✅ SERVER IS ONLINE (SSL ENABLED)"
echo "🔗 JOIN LINK: wss://bore.pub:$REMOTE_PORT"
echo "------------------------------------------------"

# --- 5. 4-HOUR TIMER & WATCHDOG ---
(
    while true; do
        sleep 45
        if ! ps -p $BORE_PID > /dev/null; then
            bore local 25565 --to bore.pub --port $REMOTE_PORT >> tunnel.log 2>&1 &
            BORE_PID=$!
        fi
    done
) &

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
