#!/bin/bash
# shellcheck disable=SC1091
# Remove all completed torrents (keeps the downloaded files)

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

# Get completed torrents (100% done)
COMPLETED=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
    "http://$HOST/transmission/rpc" \
    -d '{"method":"torrent-get","arguments":{"fields":["id","name","percentDone"]}}' 2>/dev/null | \
    jq -r '.arguments.torrents[] | select(.percentDone == 1) | "\(.id)|\(.name)"')

if [ -z "$COMPLETED" ]; then
    echo "✅ No completed torrents to remove"
    exit 0
fi

# Remove each completed torrent (keep files)
echo "🗑️  Removing completed torrents..."
echo "$COMPLETED" | while IFS='|' read -r id name; do
    RESPONSE=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
        "http://$HOST/transmission/rpc" \
        -d "{\"method\":\"torrent-remove\",\"arguments\":{\"ids\":[$id],\"delete-local-data\":false}}" 2>/dev/null)
    
    if echo "$RESPONSE" | jq -e 'select(.result == "success")' > /dev/null 2>&1; then
        echo "   ✅ Removed [$id] $name"
    else
        echo "   ❌ Failed to remove [$id] $name"
    fi
done

echo "✅ Cleanup complete"
