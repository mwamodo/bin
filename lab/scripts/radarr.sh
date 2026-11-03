#!/bin/bash
# Radarr control — list movies, search, queue, calendar
# Usage: ./radarr.sh [command] [args...]
#
# Commands:
#   list                 List all movies in library
#   search <title>       Search for a movie by title
#   add <tmdb-id>        Add a movie by TMDB ID (requires quality profile + root folder)
#   queue                Show download queue
#   calendar [days]      Show upcoming releases (default 14 days)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${RADARR_URL}"
KEY="${RADARR_API_KEY}"

api() {
    curl -s "${URL}/api/v3/${1}?apikey=${KEY}" | jq -r "${2:-.}"
}

cmd="${1:-list}"
shift || true

case "$cmd" in
    list)
        echo "🎬 Radarr Library:"
        api "movie" '.[] | "  \(if .hasFile then "✅" else "⬇️" end) \(.title) (\(.year)) [\(.id)]"' 2>/dev/null \
            | head -50 || echo "❌ Failed to list movies"
        ;;
    search)
        title="${1:-}"
        [ -z "$title" ] && { echo "Usage: $0 search <title>"; exit 1; }
        echo "🔍 Searching Radarr for '$title':"
        api "movie/lookup?term=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$title'))")" \
            '.[] | "  [\(.tmdbId)] \(.title) (\(.year)) — \(.overview[0:80])..."' 2>/dev/null \
            | head -10 || echo "❌ Search failed"
        ;;
    add)
        tmdb_id="${1:-}"
        [ -z "$tmdb_id" ] && { echo "Usage: $0 add <tmdb-id>"; exit 1; }
        # Look up movie first to get title
        movie=$(api "movie/lookup/tmdb?tmdbId=${tmdb_id}" '.' 2>/dev/null)
        title=$(echo "$movie" | jq -r '.title // "Unknown"')
        year=$(echo "$movie" | jq -r '.year // "?"')
        # Get quality profile and root folder
        profile_id=$(api "qualityprofile" '.[0].id' 2>/dev/null)
        root_folder=$(api "rootfolder" '.[0].path' 2>/dev/null)
        echo "📥 Adding '$title ($year)' [TMDB:$tmdb_id]..."
        result=$(curl -s -X POST "${URL}/api/v3/movie?apikey=${KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"tmdbId\":$tmdb_id,\"qualityProfileId\":$profile_id,\"rootFolderPath\":\"$root_folder\",\"monitored\":true,\"addOptions\":{\"searchForMovie\":true}}")
        if echo "$result" | jq -e '.id' >/dev/null 2>&1; then
            echo "✅ Added: $(echo "$result" | jq -r '.title')"
        else
            echo "❌ Failed to add movie"
            echo "$result" | jq -r '.message // "unknown error"' 2>/dev/null
        fi
        ;;
    queue)
        echo "📥 Radarr Download Queue:"
        queue=$(api "queue" '.[] | "  [\(.movieId)] \(.movie.title) — \(.status) (\(.sizeleft) left)"' 2>/dev/null)
        if [ -z "$queue" ]; then
            echo "  (empty)"
        else
            echo "$queue"
        fi
        ;;
    calendar)
        days="${1:-14}"
        start=$(date -u +%Y-%m-%d)
        end=$(date -u -d "+${days} days" +%Y-%m-%d)
        echo "📅 Radarr Calendar ($start → $end):"
        api "calendar?start=${start}&end=${end}" \
            '.[] | "  \(.title) (\(.year)) — \(.inCinemas[:10])"' 2>/dev/null \
            | head -20 || echo "❌ Failed to get calendar"
        ;;
    *)
        echo "Usage: $0 {list|search|add|queue|calendar}"
        exit 1
        ;;
esac
