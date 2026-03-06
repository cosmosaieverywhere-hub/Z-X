#!/bin/bash

# --- 1. SETUP & SECRETS ---
mkdir -p ~/.ssh
rm -f tunnel.log
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
# Ensure 'CLOUDFLARE_TUNNEL_TOKEN' is in GitHub Secrets
cloudflared tunnel --no-autoupdate run --token "$CLOUDFLARE_TUNNEL_TOKEN" > tunnel.log 2>&1 &

# --- 4. 5-HOUR AUTO-STOP TIMER (18000s total) ---
# 17970s sleep + 30s countdown = 18000s (5 hours)
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
echo "🔗 Permanent IP: wss://z-x.work.gd"

# Tail the pipe into bash/run script
tail -f server_input | bash ./run.sh

# --- 6. PUSH DATA BACK TO GITHUB ---
echo "💾 Saving world data and pushing to GitHub..."
git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

git add .
git reset "$CONFIG_PATH"

git commit -m "Automated backup: World state after 5-hour session"
git pull --rebase origin main
git push origin main

echo "✅ 5-hour session complete. Data saved."
