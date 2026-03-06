#!/bin/bash

# --- 1. SETUP & SECRETS ---
mkdir -p ~/.ssh
rm -f server_input && mkfifo server_input
CONFIG_PATH="plugins/EssentialsDiscord/config.yml"

# Inject Discord Token if the config exists
if [ -f "$CONFIG_PATH" ]; then
    echo "🔐 Injecting Discord Token..."
    sed -i "s|token: \".*\"|token: \"$ESSENTIALS_DISCORD_TOKEN\"|" "$CONFIG_PATH"
else
    echo "⚠️ Warning: EssentialsDiscord config not found at $CONFIG_PATH"
fi

# --- 2. INSTALL CLOUDFLARE TUNNEL ---
echo "📥 Installing Cloudflare Tunnel..."
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# --- 3. START TUNNEL ---
echo "🌐 Starting Cloudflare Tunnel for z-x.work.gd..."
# We run this in the background WITHOUT hidden logs so you can see errors
cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" &

# --- 4. 5-HOUR AUTO-STOP TIMER ---
(
  sleep 17970
  for i in {30..1}; do
    echo "say [System] Server closing in $i seconds! World is saving..." > server_input
    sleep 1
  done
  echo "save-all" > server_input
  sleep 2
  echo "stop" > server_input
) &

# --- 5. START SERVER ---
echo "🚀 Eaglercraft Server starting on port 25565..."
echo "🔗
