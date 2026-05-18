#!/bin/bash

CONFIG="/etc/config.json"
XRAY="/usr/local/bin/xray"
LOG="/tmp/xray-watch.log"

start_xray() {
  echo "[$(date)] Restarting Xray..." | tee -a "$LOG"
  pkill -x xray 2>/dev/null
  sleep 2
  nohup sudo "$XRAY" -c "$CONFIG" >> "$LOG" 2>&1 &
  sleep 3
}

make_public() {
  if command -v gh >/dev/null 2>&1 && [ -n "$CODESPACE_NAME" ]; then
    # Only make it public if not already public to avoid API rate limits
    VISIBILITY=$(gh codespace ports -c "$CODESPACE_NAME" --json visibility,sourcePort -q '.[] | select(.sourcePort==443) | .visibility' 2>/dev/null)
    if [ "$VISIBILITY" != "public" ]; then
      echo "[$(date)] Setting port 443 to public..." | tee -a "$LOG"
      gh codespace ports visibility 443:public -c "$CODESPACE_NAME" >/dev/null 2>&1
    fi
  fi
}

keep_alive() {
  # Simulate activity by writing to a dummy file and making a local API call
  # This tricks the system into thinking there is ongoing active work
  echo "$(date)" > /tmp/keep_alive.txt
  if command -v curl >/dev/null 2>&1; then
      # Make a local request to the Xray API port if available
      curl -s --max-time 2 http://127.0.0.1:10085 > /dev/null 2>&1 || true
  fi
}

# Initial make public on startup
make_public

COUNTER=0
while true; do
  keep_alive

  if ! pgrep -x xray >/dev/null; then
    echo "[$(date)] Xray process not found" | tee -a "$LOG"
    start_xray
    make_public
  fi

  # Periodically check and enforce public port (every 5 minutes = 10 * 30s)
  COUNTER=$((COUNTER + 1))
  if [ "$COUNTER" -ge 10 ]; then
    make_public
    COUNTER=0
  fi

  sleep 30
done
