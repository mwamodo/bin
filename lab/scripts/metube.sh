#!/bin/bash
# meTube control — YouTube downloader
# Usage: ./metube.sh [command] [args...]
#
# Commands:
#   list              List download history (completed, queued, pending)
#   add <url>         Add a URL to download
#   add-best <url>    Add URL with best quality
#   queue             Show pending + queued items
#   remove <id>       Remove a download from queue
#   clear             Clear completed downloads from history

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${METUBE_URL}"

cmd="${1:-list}"
shift || true

case "$cmd" in
    list)
        echo "📥 meTube Downloads:"
        history=$(curl -s "${URL}/history")
        done_count=$(echo "$history" | jq '.done | length')
        queue_count=$(echo "$history" | jq '.queue | length')
        pending_count=$(echo "$history" | jq '.pending | length')
        echo "  ✅ Completed: $done_count | ⏳ Queue: $queue_count | 🕐 Pending: $pending_count"
        echo ""
        echo "$history" | jq -r '
            (["DONE"] as $done | ["QUEUE"] as $q | ["PENDING"] as $p |
            (.done[] | "  ✅ [\(.id)] \(.title) — \(.size / 1048576 * 100 | round / 100) MB — \(.status)") ,
            (.queue[] | "  ⏳ [\(.id)] \(.title) — \(.percent)% — \(.status)") ,
            (.pending[] | "  🕐 [\(.id)] \(.title)")
            ' 2>/dev/null | head -30
        ;;
    add)
        url="${1:-}"
        [ -z "$url" ] && { echo "Usage: $0 add <url>"; exit 1; }
        echo "📥 Adding to meTube: $url"
        result=$(curl -s -X POST "${URL}/add" \
            -H "Content-Type: application/json" \
            -d "{\"url\":\"$url\",\"quality\":\"best\"}")
        if echo "$result" | jq -e '.status == "ok"' >/dev/null 2>&1; then
            echo "✅ Added to queue"
        else
            echo "❌ Failed: $(echo "$result" | jq -r '.msg // "unknown error"')"
        fi
        ;;
    add-best)
        url="${1:-}"
        [ -z "$url" ] && { echo "Usage: $0 add-best <url>"; exit 1; }
        echo "📥 Adding to meTube (best quality): $url"
        result=$(curl -s -X POST "${URL}/add" \
            -H "Content-Type: application/json" \
            -d "{\"url\":\"$url\",\"quality\":\"best\"}")
        if echo "$result" | jq -e '.status == "ok"' >/dev/null 2>&1; then
            echo "✅ Added to queue"
        else
            echo "❌ Failed"
        fi
        ;;
    queue)
        echo "⏳ meTube Queue:"
        queue=$(curl -s "${URL}/history" | jq -r '
            (.queue[] | "  ⏳ [\(.id)] \(.title) — \(.percent)%"),
            (.pending[] | "  🕐 [\(.id)] \(.title)")
            ' 2>/dev/null)
        if [ -z "$queue" ]; then
            echo "  (queue empty)"
        else
            echo "$queue"
        fi
        ;;
    remove)
        id="${1:-}"
        [ -z "$id" ] && { echo "Usage: $0 remove <id>"; exit 1; }
        echo "🗑️ Removing $id from meTube..."
        result=$(curl -s -X POST "${URL}/remove" \
            -H "Content-Type: application/json" \
            -d "{\"id\":\"$id\"}" 2>/dev/null)
        if echo "$result" | jq -e '.status == "ok"' >/dev/null 2>&1; then
            echo "✅ Removed"
        else
            echo "❌ Failed"
        fi
        ;;
    clear)
        echo "🗑️ Clearing meTube completed history..."
        result=$(curl -s -X POST "${URL}/clear" 2>/dev/null)
        echo "✅ History cleared"
        ;;
    *)
        echo "Usage: $0 {list|add|queue|remove|clear}"
        exit 1
        ;;
esac
