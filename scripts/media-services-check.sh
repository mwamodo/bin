#!/bin/bash
# shellcheck disable=SC1091
# Verify all media services are reachable and responding
# Usage: ./media-services-check.sh [--json]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

JSON_MODE=false
[ "${1:-}" == "--json" ] && JSON_MODE=true

# Service definitions: name, URL, health endpoint, token header name, token value env var
declare -a SERVICES=(
    "Jellyfin|${JELLYFIN_URL}|System/Info|X-MediaBrowser-Token|JELLYFIN_API_KEY"
    "Sonarr|${SONARR_URL}|api/v3/system/status|X-Api-Key|SONARR_API_KEY"
    "Prowlarr|${PROWLARR_URL}|api/v1/system/status|X-Api-Key|PROWLARR_API_KEY"
    "FlareSolverr|${FLARESOLVERR_URL:-http://localhost:8191}|health||"
    "Immich|${IMMICH_URL:-http://localhost:2283}|api/server/ping||"
    "Transmission|http://${TRANSMISSION_HOST}|transmission/rpc||TRANSMISSION_AUTH"
)

results=()
all_ok=true

for svc in "${SERVICES[@]}"; do
    IFS='|' read -r name url endpoint header env_var <<< "$svc"

    # Skip if essential env var is missing
    if [ -n "$env_var" ]; then
        token="${!env_var:-}"
        if [ -z "$token" ]; then
            results+=("$name|MISSING_ENV|⚠️  $name: env $env_var not set")
            all_ok=false
            continue
        fi
    fi

    # Build curl args
    curl_args=(-s -o /dev/null -w "%{http_code}|%{time_total}" --max-time 8)
    if [ -n "$header" ] && [ -n "${token:-}" ]; then
        curl_args+=(-H "$header: $token")
    fi
    if [ "$name" == "Transmission" ]; then
        # Transmission needs session handshake + POST
        session=$(curl -s -u "$token" "$url/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1)
        if [ -z "$session" ]; then
            results+=("$name|FAIL|❌ $name: no session (wrong auth?)")
            all_ok=false
            continue
        fi
        resp=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" --max-time 8 \
            -u "$token" -H "X-Transmission-Session-Id: $session" \
            -H "Content-Type: application/json" \
            -d '{"method":"session-get"}' \
            "$url/transmission/rpc" 2>/dev/null || echo "000|0")
    else
        full_url="$url/$endpoint"
        resp=$(curl "${curl_args[@]}" "$full_url" 2>/dev/null || echo "000|0")
    fi
    http_code=$(echo "$resp" | cut -d'|' -f1)
    time_ms=$(echo "$resp" | cut -d'|' -f2)
    time_ms=$(python3 -c "print(f'{float('$time_ms')*1000:.0f}')" 2>/dev/null || echo "?")

    if [ "$http_code" == "200" ] || [ "$http_code" == "401" ] || [ "$http_code" == "403" ]; then
        # 401/403 means the service is alive but we might lack auth (service without a configured token)
        results+=("$name|OK|✅ $name: up (${time_ms}ms)")
    else
        results+=("$name|FAIL|❌ $name: HTTP $http_code (${time_ms}ms)")
        all_ok=false
    fi
done

# ── output ────────────────────────────────────────────────────────
if [ "$JSON_MODE" = true ]; then
    printf '%s\n' "${results[@]}" | awk -F'|' 'BEGIN{print "{"} {if(NR>1)print ","; printf "  \"%s\": {\"status\": \"%s\", \"message\": \"%s\"}", $1, $2, $3} END{print "\n}"}'
else
    echo "═══════════════════════════════════════════════════════════════"
    echo "🩺 Media Services Health Check"
    echo "═══════════════════════════════════════════════════════════════"
    printf '%s\n' "${results[@]}" | cut -d'|' -f3-
    echo "═══════════════════════════════════════════════════════════════"
    if [ "$all_ok" = true ]; then
        echo "✅ All services responding"
    else
        echo "⚠️  Some services are down or misconfigured"
    fi
fi
