#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspaces/g2ray}"
TRAFFIC_API_URL="${TRAFFIC_API_URL:-}"
TRAFFIC_TOKEN="${TRAFFIC_TOKEN:-}"
TRAFFIC_INTERVAL="${TRAFFIC_INTERVAL:-10}"
XRAY_INBOUND_TAG="${XRAY_INBOUND_TAG:-vless-in}"

WORKSPACE_NAME="${CODESPACE_NAME:-$(hostname)}"

if [ -z "$TRAFFIC_API_URL" ] || [ -z "$TRAFFIC_TOKEN" ]; then
  echo "ERROR: Set TRAFFIC_API_URL and TRAFFIC_TOKEN before running this script."
  exit 1
fi

cd "$PROJECT_DIR"
chmod +x "$PROJECT_DIR/usage-agent.sh"

cat > "$PROJECT_DIR/.traffic.env" <<ENV
TRAFFIC_API_URL="$TRAFFIC_API_URL"
TRAFFIC_TOKEN="$TRAFFIC_TOKEN"
TRAFFIC_INTERVAL="$TRAFFIC_INTERVAL"
XRAY_INBOUND_TAG="$XRAY_INBOUND_TAG"
TRAFFIC_WORKSPACE="$WORKSPACE_NAME"
ENV

pkill -f "$PROJECT_DIR/usage-agent.sh" 2>/dev/null || true

nohup "$PROJECT_DIR/usage-agent.sh" >/tmp/g2ray-traffic-agent.out 2>&1 &
echo $! > /tmp/g2ray-traffic-agent.pid

echo "✅ Traffic agent installed for workspace: $WORKSPACE_NAME"
echo "📄 Log: /tmp/g2ray-traffic-agent.log"
