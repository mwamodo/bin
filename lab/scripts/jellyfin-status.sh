#!/bin/bash
# Check who's watching Jellyfin on lab
# Usage: ./jellyfin-status.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

sessions=$(curl -s "${JELLYFIN_URL}/Sessions?api_key=${JELLYFIN_API_KEY}")

# Check for active playback
active=$(echo "$sessions" | jq -r '.[] | select(.NowPlayingItem != null) | "\(.UserName) on \(.DeviceName) → \(.NowPlayingItem.SeriesName // .NowPlayingItem.Name)\(if .NowPlayingItem.SeriesName then " - " + .NowPlayingItem.Name else "" end) [\((.PlayState.PositionTicks / 10000000 / 60 | floor))m in, \(if .PlayState.IsPaused then "paused" else "playing" end)]"')

if [ -z "$active" ]; then
    echo "🍿 No one is watching anything right now"
else
    echo "🎬 Active Jellyfin Sessions:"
    echo "$active"
fi
