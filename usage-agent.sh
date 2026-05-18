#!/usr/bin/env bash
set -u

# Sends total Xray traffic for this Codespace to the controller.
# It uses CODESPACE_NAME automatically, so no per-account name is needed.

ENV_FILE="${TRAFFIC_ENV_FILE:-/workspaces/g2ray/.traffic.env}"
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  source "$ENV_FILE"
fi

TRAFFIC_API_URL="${TRAFFIC_API_URL:-http://141.11.18.186:3010/api/traffic/push}"
TRAFFIC_TOKEN="${TRAFFIC_TOKEN:-change_me_traffic_token}"
TRAFFIC_WORKSPACE="${TRAFFIC_WORKSPACE:-${CODESPACE_NAME:-}}"
XRAY_API_SERVER="${XRAY_API_SERVER:-127.0.0.1:10085}"
XRAY_INBOUND_TAG="${XRAY_INBOUND_TAG:-vless-in}"
INTERVAL="${TRAFFIC_INTERVAL:-10}"
LOG_FILE="${TRAFFIC_LOG_FILE:-/tmp/g2ray-traffic-agent.log}"
XRAY_BIN="${XRAY_BIN:-$(command -v xray 2>/dev/null || printf '/usr/local/bin/xray')}"

read_stat() {
  local name="$1" out value
  if [ ! -x "$XRAY_BIN" ] && ! command -v "$XRAY_BIN" >/dev/null 2>&1; then
    printf '0'
    return
  fi
  out="$($XRAY_BIN api stats --server="$XRAY_API_SERVER" -name "$name" 2>/dev/null || true)"
  value="$(printf '%s' "$out" | grep -o '"value"[[:space:]]*:[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || true)"
  printf '%s' "${value:-0}"
}

log() {
  printf '[%s] %s\n' "$(date -Iseconds)" "$*" | tee -a "$LOG_FILE" >/dev/null
}

if [ -z "$TRAFFIC_WORKSPACE" ]; then
  log "ERROR: CODESPACE_NAME/TRAFFIC_WORKSPACE is empty"
  exit 1
fi

if [ "$TRAFFIC_API_URL" = "change me url" ] || [ "$TRAFFIC_TOKEN" = "chchngemetoken" ]; then
  log "ERROR: TRAFFIC_API_URL/TRAFFIC_TOKEN is not configured"
  exit 1
fi

log "traffic agent started workspace=$TRAFFIC_WORKSPACE endpoint=$TRAFFIC_API_URL interval=${INTERVAL}s inbound=$XRAY_INBOUND_TAG xray=$XRAY_BIN"

while true; do
  UP="$(read_stat "inbound>>>${XRAY_INBOUND_TAG}>>>traffic>>>uplink")"
  DOWN="$(read_stat "inbound>>>${XRAY_INBOUND_TAG}>>>traffic>>>downlink")"
  TOTAL=$((UP + DOWN))

  RESPONSE="$(curl -sS --max-time 8 -X POST "$TRAFFIC_API_URL" \
    -H "Content-Type: application/json" \
    -H "X-Traffic-Token: $TRAFFIC_TOKEN" \
    -d "{\"workspace\":\"$TRAFFIC_WORKSPACE\",\"uplink\":$UP,\"downlink\":$DOWN,\"total\":$TOTAL,\"hostname\":\"${HOSTNAME:-}\"}" 2>&1 || true)"

  case "$RESPONSE" in
    *'"ok":true'*) : ;;
    *) log "push failed workspace=$TRAFFIC_WORKSPACE up=$UP down=$DOWN response=$RESPONSE" ;;
  esac

  sleep "$INTERVAL"
done
