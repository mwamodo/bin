#!/bin/bash
# shellcheck disable=SC1091
# Jellyfin control — status, libraries, scan, search, playback
# Usage: ./jellyfin.sh [command] [args...]
#
# Commands:
#   status               Show active sessions (who's watching)
#   libraries            List all media libraries
#   scan <library-id>    Trigger a library scan
#   search <query>       Search across all libraries
#   latest [limit]       Show recently added items (default 10)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${JELLYFIN_URL}"
KEY="${JELLYFIN_API_KEY}"

api() {
    curl -s "${URL}/${1}" -H "X-MediaBrowser-Token: ${KEY}" | jq -r "${2:-.}"
}

cmd="${1:-status}"
shift || true

case "$cmd" in
    status)
        echo "🎬 Active Jellyfin Sessions:"
        sessions=$(api "Sessions" '.[] | select(.NowPlayingItem != null) | "  \(.UserName) on \(.DeviceName) → \(.NowPlayingItem.SeriesName // .NowPlayingItem.Name)\(if .NowPlayingItem.SeriesName then " — " + .NowPlayingItem.Name else "" end) [\((.PlayState.PositionTicks / 10000000 / 60 | floor))m in, \(if .PlayState.IsPaused then "paused" else "playing" end)]"' 2>/dev/null)
        if [ -z "$sessions" ]; then
            echo "  🍿 No one is watching anything right now"
        else
            echo "$sessions"
        fi
        ;;
    libraries)
        echo "📚 Jellyfin Libraries:"
        api "Library/VirtualFolders" '.[] | "  [\(.ItemId)] \(.Name) — \(.CollectionType // "mixed")"' 2>/dev/null \
            || echo "❌ Failed to list libraries"
        ;;
    scan)
        lib_id="${1:-}"
        [ -z "$lib_id" ] && { echo "Usage: $0 scan <library-id>"; echo "  (use 'libraries' to find IDs)"; exit 1; }
        echo "🔄 Scanning library $lib_id..."
        curl -s -X POST "${URL}/Library/Refresh?libraryId=${lib_id}" \
            -H "X-MediaBrowser-Token: ${KEY}" >/dev/null 2>&1
        echo "✅ Scan triggered"
        ;;
    search)
        query="${1:-}"
        [ -z "$query" ] && { echo "Usage: $0 search <query>"; exit 1; }
        q_enc=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")
        echo "🔍 Searching Jellyfin for '$query':"
        items=$(api "Items?searchTerm=${q_enc}&recursive=true&includeItemTypes=Movie,Series,Episode" \
            '.Items[] | "  [\(.Id)] \(.Type): \(.Name) (\(.ProductionYear // "?")" + (if .SeriesName then " — S\(.ParentIndexNumber)E\(.IndexNumber)" else "" end)' 2>/dev/null)
        if [ -z "$items" ]; then
            echo "  (no results)"
        else
            echo "$items" | head -20
        fi
        ;;
    latest)
        limit="${1:-10}"
        echo "🆕 Recently Added (last $limit):"
        api "Items?SortBy=DateCreated&SortOrder=Descending&recursive=true&includeItemTypes=Movie,Series,Episode&Limit=${limit}" \
            '.Items[] | "  \(.Type): \(.Name) (\(.ProductionYear // "?"))"' 2>/dev/null \
            || echo "❌ Failed"
        ;;
    *)
        echo "Usage: $0 {status|libraries|scan|search|latest}"
        exit 1
        ;;
esac
