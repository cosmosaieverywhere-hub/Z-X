#!/bin/bash

# --- 1. SETUP & CLEANUP ---
mkdir -p ~/.ssh
rm -f tunnel.log
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
pkill -f "ssh.*serveo.net" || true

# --- 2. DISCORD TOKEN INJECTION ---
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s|token: \".*\"|token: \"$ESSENTIALS_DISCORD_TOKEN\"|" "$CONFIG_PATH"
fi

# --- 3. FORCE EAGLERCRAFT TO 25565 ---
echo "⚙️ Setting Eaglercraft Bridge to Port 25565..."
mkdir -p plugins/EaglercraftXServer
cat << EOF > plugins/EaglercraftXServer/settings.yml
server:
  address: '0.0.0.0:25565'
  server_icon: 'server-icon.gif'
tls_config:
  enable_tls: false
EOF

# --- 4. START THE NO-WARNING TUNNEL (Serveo) ---
# We tunnel 25565 directly. Serveo has NO password pages!
echo "🌐 Starting Serveo Tunnel on port 25565..."
(
    while true; do
        # We request the 'zx-survival' name on port 80 (standard web port)
        ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 \
            -R zx-survival:80:localhost:25565 serveo.net >> tunnel.log 2>&1
        sleep 5 
    done
) &

# --- 5. WAIT & GET THE LINK ---
sleep 15
ADDRESS=$(grep -oE "https://[a-zA-Z0-9.-]+\.serveo\.net" tunnel.log | head -n 1)

if [ -n "$ADDRESS" ]; then
    IP=${ADDRESS/https/wss}
    echo "✅ PERFECT IP READY: $IP"
    if [ ! -z "$DISCORD_WEBHOOK" ]; then
        curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🔥 **Server Online!**\\n💎 **Join:** \`$IP\`\\n🚀 **No Password/Warning Page!**\"}" "$DISCORD_WEBHOOK" > /dev/null
    fi
else
    echo "⚠️ Serveo is assigning a link, please wait..."
    cat tunnel.log
fi

# --- 6. 5-HOUR TIMER ---
(
  sleep 18000
  echo "stop" > server_input
) &

# --- 7. START SERVER ---
echo "🚀 Minecraft is starting on 25565..."
( tail -f server_input & ) | bash ./run.sh

# --- 8. SAVE & PUSH ---
git config --global user.name "github-actions[bot]"
git add .
git reset "$CONFIG_PATH"
git pull --rebase origin main
git commit -m "Auto-Save: $(date)" || echo "No changes"
git push origin main
