#!/bin/bash
# shellcheck disable=SC1091
# Sonarr control — list series, search, queue, calendar, episodes
# Usage: ./sonarr.sh [command] [args...]
#
# Commands:
#   list                   List all TV series in library
#   search <title>         Search for a series
#   episodes <series-id>   List episodes for a series
#   queue                  Show download queue
#   calendar [days]        Show upcoming episodes (default 14 days)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${SONARR_URL}"
KEY="${SONARR_API_KEY}"

api() {
    curl -s "${URL}/api/v3/${1}?apikey=${KEY}" | jq -r "${2:-.}"
}

cmd="${1:-list}"
shift || true

case "$cmd" in
    list)
        echo "📺 Sonarr Library:"
        api "series" '.[] | "  \(.title) — \(.statistics.episodeFileCount)/\(.statistics.episodeCount) eps | next: \(.nextAiring // "—") | status: \(.status)"' 2>/dev/null \
            | sort | head -50 || echo "❌ Failed to list series"
        ;;
    search)
        title="${1:-}"
        [ -z "$title" ] && { echo "Usage: $0 search <title>"; exit 1; }
        echo "🔍 Searching Sonarr for '$title':"
        api "series/lookup?term=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$title'))")" \
            '.[] | "  [\(.tvdbId)] \(.title) (\(.year)) — \(.seasons | length) seasons — \(.overview[0:80])..."' 2>/dev/null \
            | head -10 || echo "❌ Search failed"
        ;;
    episodes)
        sid="${1:-}"
        [ -z "$sid" ] && { echo "Usage: $0 episodes <series-id>"; echo "  (use 'list' to find series IDs)"; exit 1; }
        series_name=$(api "series/$sid" '.title' 2>/dev/null)
        echo "📺 Episodes: $series_name"
        api "episode?seriesId=$sid" \
            '.[] | "  S\(.seasonNumber|tostring|if length==1 then "0"+. else . end)E\(.episodeNumber|tostring|if length==1 then "0"+. else . end) — \(.title // "TBA") \(if .hasFile then "✅" elif .airDateUtc == null or .airDateUtc > now then "⏳" else "⬇️" end) \(.airDateUtc[:10] // "TBA")"' 2>/dev/null \
            | head -50 || echo "❌ Failed to list episodes"
        ;;
    queue)
        echo "📥 Sonarr Download Queue:"
        queue=$(api "queue" '.[] | "  [\(.seriesId)] \(.series.title) — S\(.episode.seasonNumber)E\(.episode.episodeNumber) \(.episode.title) — \(.status)"' 2>/dev/null)
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
        echo "📅 Sonarr Calendar ($start → $end):"
        api "calendar?start=${start}&end=${end}" \
            '.[] | "  \(.series.title) — S\(.seasonNumber)E\(.episodeNumber) \(.title) — \(.airDateUtc[:10])"' 2>/dev/null \
            | head -20 || echo "❌ Failed to get calendar"
        ;;
    *)
        echo "Usage: $0 {list|search|episodes|queue|calendar}"
        exit 1
        ;;
esac
