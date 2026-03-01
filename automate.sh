#!/bin/bash

# --- 1. SETUP & CONFIG ---
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"
SUBDOMAIN="zx-survival"

# --- 2. THE SECRET SAUCE: NO CONFLICTS ---
# Move Java to 25566 so the Eaglercraft Bridge can own 25565
sed -i 's/server-port=.*/server-port=25566/' server.properties
sed -i 's/online-mode=.*/online-mode=false/' server.properties

mkdir -p plugins/EaglercraftXServer
cat << EOF > plugins/EaglercraftXServer/settings.yml
server:
  address: '0.0.0.0:25565'
tls_config:
  enable_tls: false
EOF

# --- 3. GET THE BYPASS PASSWORD ---
echo "🔑 YOUR TUNNEL PASSWORD (IP) IS:"
curl -s https://loca.lt/mytunnelpassword
echo -e "\n----------------------------"

# --- 4. START LOCALTUNNEL WITH WATCHDOG ---
echo "📥 Installing/Starting Localtunnel..."
npm install -g localtunnel > /dev/null 2>&1

(
    while true; do
        lt --port 25565 --subdomain "$SUBDOMAIN" --print-requests >> tunnel.log 2>&1 &
        TUNNEL_PID=$!
        # Stay alive for 20 mins then refresh
        for i in {1..40}; do 
            sleep 30
            if ! ps -p $TUNNEL_PID > /dev/null; then break; fi
            curl -s "https://$SUBDOMAIN.loca.lt" > /dev/null
        done
        kill $TUNNEL_PID 2>/dev/null
    done
) &

# --- 5. DISCORD ANNOUNCEMENT ---
IP="wss://$SUBDOMAIN.loca.lt"
if [ ! -z "$DISCORD_WEBHOOK" ]; then
    curl -s -H "Content-Type: application/json" -X POST -d "{\"content\": \"🚀 **Server Online!**\\n🏠 **IP:** \`$IP\`\\n🔑 **Password:** (Check GitHub Logs if prompted)\"}" "$DISCORD_WEBHOOK" > /dev/null
fi

# --- 6. 5-HOUR TIMER ---
(
  sleep 18000
  echo "stop" > server_input
) &

# --- 7. START SERVER ---
echo "🚀 Starting Minecraft (Eaglercraft 25565 <-> Java 25566)..."
( tail -f server_input & ) | bash ./run.sh

# --- 8. SAVE ---
git config --global user.name "github-actions[bot]"
git add .
git reset "$CONFIG_PATH"
git pull --rebase origin main
git commit -m "Auto-Save: $(date)" || echo "No changes"
git push origin main
