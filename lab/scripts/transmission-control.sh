#!/bin/bash
# Control torrents: pause, resume, or toggle by ID
# Usage: ./transmission-control.sh <pause|resume|toggle> [torrent-id|all]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

HOST="${TRANSMISSION_HOST}"
AUTH="${TRANSMISSION_AUTH}"

if [ -z "$1" ] || [[ ! "$1" =~ ^(pause|resume|toggle)$ ]]; then
    echo "Usage: $0 <pause|resume|toggle> [torrent-id|all]"
    echo "Examples:"
    echo "  $0 pause 5        # Pause torrent ID 5"
    echo "  $0 resume 5       # Resume torrent ID 5"
    echo "  $0 pause all      # Pause all torrents"
    echo "  $0 resume all     # Resume all torrents"
    exit 1
fi

ACTION="$1"
TARGET="${2:-}"

# Get session ID
SESSION=$(curl -s -u "$AUTH" "http://$HOST/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1)

if [ -z "$SESSION" ]; then
    echo "❌ Failed to get session ID"
    exit 1
fi

# Determine method and target
if [ "$TARGET" == "all" ]; then
    if [ "$ACTION" == "pause" ]; then
        METHOD="torrent-stop"
    else
        METHOD="torrent-start"
    fi
    JSON="{\"method\":\"$METHOD\",\"arguments\":{}}"
    echo "⏸️  Pausing all torrents..."
    [ "$ACTION" == "resume" ] && echo "▶️  Resuming all torrents..."
elif [ -n "$TARGET" ]; then
    if [ "$ACTION" == "pause" ]; then
        METHOD="torrent-stop"
    elif [ "$ACTION" == "resume" ]; then
        METHOD="torrent-start"
    else
        # Toggle - check current status first
        STATUS=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
            "http://$HOST/transmission/rpc" \
            -d "{\"method\":\"torrent-get\",\"arguments\":{\"ids\":[$TARGET],\"fields\":[\"status\"]}}" 2>/dev/null | \
            jq -r '.arguments.torrents[0].status')
        if [ "$STATUS" == "0" ]; then
            METHOD="torrent-start"
            ACTION="resume"
            echo "▶️  Resuming torrent $TARGET..."
        else
            METHOD="torrent-stop"
            ACTION="pause"
            echo "⏸️  Pausing torrent $TARGET..."
        fi
        JSON="{\"method\":\"$METHOD\",\"arguments\":{\"ids\":[$TARGET]}}"
        curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
            "http://$HOST/transmission/rpc" -d "$JSON" > /dev/null
        echo "✅ Done"
        exit 0
    fi
    JSON="{\"method\":\"$METHOD\",\"arguments\":{\"ids\":[$TARGET]}}"
    [ "$ACTION" == "pause" ] && echo "⏸️  Pausing torrent $TARGET..."
    [ "$ACTION" == "resume" ] && echo "▶️  Resuming torrent $TARGET..."
else
    echo "❌ Please specify a torrent ID or 'all'"
    exit 1
fi

# Execute
RESPONSE=$(curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
    "http://$HOST/transmission/rpc" -d "$JSON")

if echo "$RESPONSE" | jq -e 'select(.result == "success")' > /dev/null 2>&1; then
    echo "✅ Done"
else
    echo "❌ Failed"
    echo "$RESPONSE" | jq -r '.result' 2>/dev/null
fi
