#!/usr/bin/env bash

PROJECT_DIR="${PROJECT_DIR:-/workspaces/g2ray}"
CONFIG_FILE="/etc/config.json"

# 1. Dynamic UUID Generation & Update Config
if grep -q "550e8400-e29b-41d4-a716-446655440000" "$CONFIG_FILE"; then
    NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "s/550e8400-e29b-41d4-a716-446655440000/$NEW_UUID/g" "$CONFIG_FILE"
    echo "Generated new dynamic UUID: $NEW_UUID"
else
    # Extract existing UUID if already changed
    NEW_UUID=$(grep -oP '(?<="id": ")[^"]+' "$CONFIG_FILE" | head -1)
fi

# 2. Generate VLESS Link
DOMAIN="${CODESPACE_NAME}-443.app.github.dev"
# Using WebSocket (ws) instead of xhttp for better compatibility and stability
VLESS_LINK="vless://${NEW_UUID}@${DOMAIN}:443?encryption=none&security=tls&type=ws&host=${DOMAIN}&path=%2F#G2Ray-${CODESPACE_NAME}"

echo -e "\n✅ **VLESS LINK:**\n\n${VLESS_LINK}\n" > /tmp/vless_link.txt

# 3. Telegram Bot Integration
# Load local .env file if it exists (for hardcoded tokens)
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

if [ -n "$TG_BOT_TOKEN" ] && [ -n "$TG_CHAT_ID" ]; then
    # Check if we already sent it to avoid spamming on restarts
    if [ ! -f /tmp/telegram_sent ]; then
        MSG="🚀 *New G2Ray Node Started!*
        
*Workspace:* \`${CODESPACE_NAME}\`
*Link:*
\`${VLESS_LINK}\`"
        
        curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TG_CHAT_ID}" \
            -d text="${MSG}" \
            -d parse_mode="Markdown" > /dev/null
            
        touch /tmp/telegram_sent
        echo "VLESS link sent to Telegram."
    fi
fi

# 4. Stop existing services cleanly
pkill -x xray 2>/dev/null || true
pkill -f "$PROJECT_DIR/watch.sh" 2>/dev/null || true
pkill -f "$PROJECT_DIR/usage-agent.sh" 2>/dev/null || true
sleep 1

# 5. Start Services
nohup sudo /usr/local/bin/xray -c "$CONFIG_FILE" > /tmp/xray.out 2>&1 &

chmod +x "$PROJECT_DIR/watch.sh"
nohup "$PROJECT_DIR/watch.sh" > /tmp/watchdog.out 2>&1 &

# Start traffic monitor agent
if [ -f "$PROJECT_DIR/usage-agent.sh" ]; then
  chmod +x "$PROJECT_DIR/usage-agent.sh"
  nohup "$PROJECT_DIR/usage-agent.sh" >/tmp/g2ray-traffic-agent.out 2>&1 &
fi

sleep 2
echo "Services status:"
ps aux | grep -E "xray|watch.sh|usage-agent.sh" | grep -v grep || true
cat /tmp/vless_link.txt
