#!/bin/bash
# Jellyseerr control — media requests, status
# NOTE: Jellyseerr doesn't have a static API key by default.
# To use this script, generate an API key in the Jellyseerr web UI:
#   Settings → General → API Key → Generate
# Then add to ~/bin/lab/scripts/.env:
#   JELLYSEERR_URL=http://localhost:5055
#   JELLYSEERR_API_KEY=<your-key>
#
# Usage: ./jellyseerr.sh [command] [args...]
#
# Commands:
#   status            Jellyseerr version and health
#   requests          List pending media requests
#   count             Request counts (pending/approved/declined)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${JELLYSEERR_URL:-http://localhost:5055}"
KEY="${JELLYSEERR_API_KEY:-}"

api() {
    local headers=""
    [ -n "$KEY" ] && headers="-H x-api-key: ${KEY}"
    curl -s ${headers} "${URL}/api/v1/${1}" | jq -r "${2:-.}"
}

cmd="${1:-status}"
shift || true

if [ -z "$KEY" ]; then
    echo "⚠️  No JELLYSEERR_API_KEY configured."
    echo "   Generate one at ${URL}/settings/main"
    echo "   Then add: JELLYSEERR_API_KEY=<key> to ~/bin/lab/scripts/.env"
    echo ""
fi

case "$cmd" in
    status)
        echo "🔍 Jellyseerr Status:"
        api "status" '. | "  Version: \(.version), Update available: \(.updateAvailable)"' 2>/dev/null \
            || echo "❌ Failed to get status"
        ;;
    requests)
        if [ -z "$KEY" ]; then
            echo "❌ API key required for requests"
            exit 1
        fi
        echo "📋 Pending Media Requests:"
        items=$(api "request?take=20&filter=available&sort=added" \
            '.results[] | "  [\(.id)] \(.type): \(.media.tmdbId) — requested by \(.requestedBy.displayName) — status: \(.media.status)"' 2>/dev/null)
        if [ -z "$items" ]; then
            echo "  (no pending requests)"
        else
            echo "$items"
        fi
        ;;
    count)
        if [ -z "$KEY" ]; then
            echo "❌ API key required for counts"
            exit 1
        fi
        api "request/count" '. | "  Pending: \(.pending // 0), Approved: \(.approved // 0), Declined: \(.declined // 0)"' 2>/dev/null \
            || echo "❌ Failed to get counts"
        ;;
    *)
        echo "Usage: $0 {status|requests|count}"
        exit 1
        ;;
esac
