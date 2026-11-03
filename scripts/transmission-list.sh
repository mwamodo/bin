#!/bin/bash
# shellcheck disable=SC1091
# List all torrents with status, progress, and speed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

HOST="${TRANSMISSION_HOST}"
AUTH="${TRANSMISSION_AUTH}"

# Get session ID
SESSION=$(curl -s -u "$AUTH" "http://$HOST/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1)

if [ -z "$SESSION" ]; then
    echo "❌ Failed to get session ID"
    exit 1
fi

# Get torrent list
RESPONSE=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
    "http://$HOST/transmission/rpc" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","name","status","percentDone","rateDownload","rateUpload","eta","error","errorString"]}}' 2>/dev/null)

# Parse and display
echo "$RESPONSE" | jq -r '
    .arguments.torrents[] |
    if .status == 0 then "⏸️  PAUSED"
    elif .status == 4 then "⬇️  DOWNLOADING"
    elif .status == 6 then "✅ SEEDING"
    else "❓ UNKNOWN"
    end as $statusIcon |
    "\($statusIcon) [\(.id)] \(.name)\n   Progress: \((.percentDone * 100) | floor)% | Down: \((.rateDownload / 1024) | floor)KB/s | Up: \((.rateUpload / 1024) | floor)KB/s"
' 2>/dev/null || echo "❌ Failed to parse torrent list"
