#!/bin/bash
# Remove torrent by ID
# Usage: ./transmission-remove.sh <torrent-id> [--delete-data]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

if [ -z "$1" ]; then
    echo "Usage: $0 <torrent-id> [--delete-data]"
    echo "Example: $0 5"
    echo "Example: $0 5 --delete-data  (removes torrent AND deletes files)"
    exit 1
fi

HOST="${TRANSMISSION_HOST}"
AUTH="${TRANSMISSION_AUTH}"
TORRENT_ID="$1"
DELETE_DATA=false

if [ "$2" == "--delete-data" ]; then
    DELETE_DATA=true
fi

# Get session ID
SESSION=$(curl -s -u "$AUTH" "http://$HOST/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1)

if [ -z "$SESSION" ]; then
    echo "❌ Failed to get session ID"
    exit 1
fi

# Remove torrent
RESPONSE=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
    "http://$HOST/transmission/rpc" \
    -d "{\"method\":\"torrent-remove\",\"arguments\":{\"ids\":[$TORRENT_ID],\"delete-local-data\":$DELETE_DATA}}" 2>/dev/null)

# Check result
if echo "$RESPONSE" | jq -e 'select(.result == "success")' > /dev/null 2>&1; then
    if [ "$DELETE_DATA" = true ]; then
        echo "✅ Removed torrent $TORRENT_ID and deleted files"
    else
        echo "✅ Removed torrent $TORRENT_ID (files kept)"
    fi
else
    echo "❌ Failed to remove torrent $TORRENT_ID"
    echo "$RESPONSE" | jq -r .result 2>/dev/null
fi
