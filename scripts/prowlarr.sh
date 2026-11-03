#!/bin/bash
# shellcheck disable=SC1091
# Prowlarr control — list indexers, health, search
# Usage: ./prowlarr.sh [command] [args...]
#
# Commands:
#   list            List all indexers with status
#   health          Show indexer health status
#   search <query>  Search across all indexers
#   stats           Show indexer statistics

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${PROWLARR_URL}"
KEY="${PROWLARR_API_KEY}"

api() {
    curl -s "${URL}/api/v1/${1}?apikey=${KEY}" | jq -r "${2:-.}"
}

cmd="${1:-list}"
shift || true

case "$cmd" in
    list)
        echo "🔍 Prowlarr Indexers:"
        api "indexer" '.[] | "  \(if .enable then "✅" else "❌" end) [\(.id)] \(.name) — \(.protocol) \(if .enableRss then "+RSS" else "" end) \(if .enableAutomaticSearch then "+Auto" else "" end)"' 2>/dev/null \
            || echo "❌ Failed to list indexers"
        ;;
    health)
        echo "🏥 Prowlarr Health:"
        api "health" '.[] | "  [\(.source)] \(.type): \(.message)"' 2>/dev/null \
            || echo "❌ Failed to check health"
        ;;
    search)
        query="${1:-}"
        [ -z "$query" ] && { echo "Usage: $0 search <query>"; exit 1; }
        echo "🔍 Searching Prowlarr for '$query':"
        api "search?query=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$query'))")&type=search" \
            '.[0:20][] | "  [\(.indexer)] \(.title) — \(.protocol) — \(.size / 1024 / 1024 / 1024 * 100 | round / 100) GB"' 2>/dev/null \
            || echo "❌ Search failed"
        ;;
    stats)
        echo "📊 Prowlarr Stats:"
        api "indexerstats" '.' 2>/dev/null | jq '.' || echo "❌ Failed to get stats"
        ;;
    *)
        echo "Usage: $0 {list|health|search|stats}"
        exit 1
        ;;
esac
