#!/bin/bash
# shellcheck disable=SC1091,SC2034
# Diagnose stalled/slow torrents in Transmission
# Usage: ./transmission-diagnose.sh [torrent-id]
#   With no args: diagnoses all active torrents
#   With ID: deep-dive on one torrent
#
# Checks: progress, peers, trackers, ASN blocklist issues,
#         seed ratio, ETA sanity, and suggests actions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

HOST="${TRANSMISSION_HOST}"
AUTH="${TRANSMISSION_AUTH}"

# ── helpers ───────────────────────────────────────────────────────
get_session() {
    curl -s -u "$AUTH" "http://$HOST/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1
}

torrent_get() {
    local fields="$1"
    local ids="${2:-}"
    local id_json=""
    [ -n "$ids" ] && id_json='"ids":['"$ids"'],'
    curl -s -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION" \
        "http://$HOST/transmission/rpc" \
        -d "{\"method\":\"torrent-get\",\"arguments\":{${id_json}\"fields\":[$fields]}}" 2>/dev/null
}

human_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        echo "${bytes}B"
    fi
}

# ── main ──────────────────────────────────────────────────────────
SESSION=$(get_session)
if [ -z "$SESSION" ]; then
    echo "❌ Failed to get Transmission session ID"
    exit 1
fi

TARGET_ID="${1:-}"

if [ -n "$TARGET_ID" ]; then
    # Single-torrent deep dive
    echo "🔬 Deep-dive for torrent [$TARGET_ID]"
    DATA=$(torrent_get '"id","name","status","percentDone","rateDownload","rateUpload","eta","error","errorString","peersGettingFromUs","peersSendingToUs","peersConnected","totalSize","downloadedEver","uploadedEver","uploadRatio","trackerStats","activityDate","corruptEver","leftUntilDone"' "$TARGET_ID")

    echo "$DATA" | jq -r '
    .arguments.torrents[0] |
    "Name:        \(.name)",
    "Status:      \(.status)",
    "Progress:    \((.percentDone * 100) | floor)%",
    "Size:        \(.totalSize)",
    "Downloaded:  \(.downloadedEver)",
    "Left:        \(.leftUntilDone)",
    "Corrupt:     \(.corruptEver)",
    "Down:        \(.rateDownload) B/s",
    "Up:          \(.rateUpload) B/s",
    "ETA:         \(.eta)s",
    "UploadRatio: \(.uploadRatio)",
    "Peers:       connected=\(.peersConnected) sending=\(.peersSendingToUs) getting=\(.peersGettingFromUs)",
    "Error:       \(.error) \(.errorString)",
    "Activity:    \(.activityDate)",
    "",
    "Trackers:"
    ' 2>/dev/null

    echo "$DATA" | jq -r '
    .arguments.torrents[0].trackerStats[] |
    "  \(.host) | announce=\(.lastAnnounceResult) scrape=\(.lastScrapeResult) seeders=\(.seederCount) leechers=\(.leecherCount)"
    ' 2>/dev/null
    exit 0
fi

# All active torrents summary
DATA=$(torrent_get '"id","name","status","percentDone","rateDownload","rateUpload","eta","error","errorString","peersConnected","totalSize","uploadedEver","trackerStats"')

# Status map: 0=stopped, 1=check_wait, 2=check, 3=download_wait, 4=downloading, 5=seed_wait, 6=seeding

stalled=()
fast=()
slow=()
seeding=()
errors=()

while IFS= read -r line; do
    id=$(echo "$line" | jq -r '.id')
    name=$(echo "$line" | jq -r '.name')
    status=$(echo "$line" | jq -r '.status')
    pct=$(echo "$line" | jq -r '(.percentDone * 100) | floor')
    down=$(echo "$line" | jq -r '.rateDownload')
    up=$(echo "$line" | jq -r '.rateUpload')
    eta=$(echo "$line" | jq -r '.eta')
    err=$(echo "$line" | jq -r '.error')
    err_str=$(echo "$line" | jq -r '.errorString')
    peers=$(echo "$line" | jq -r '.peersConnected')
    size=$(echo "$line" | jq -r '.totalSize')

    # Categorize
    if [ "$err" != "0" ] && [ -n "$err_str" ] && [ "$err_str" != "" ]; then
        errors+=("[$id] $name | error: $err_str")
    elif [ "$status" == "6" ] || [ "$status" == "5" ]; then
        seeding+=("[$id] $name | ratio=$(echo "$line" | jq -r '.uploadedEver / .totalSize * 100 | floor')% uploaded")
    elif [ "$status" == "4" ] || [ "$status" == "3" ]; then
        if [ "$down" -gt 1048576 ]; then
            fast+=("[$id] $name | $pct% | $(human_bytes "$down")/s | ETA ${eta}s | peers=$peers")
        elif [ "$down" -gt 0 ]; then
            slow+=("[$id] $name | $pct% | $(human_bytes "$down")/s | ETA ${eta}s | peers=$peers")
        else
            # Downloading but 0 speed
            trackers=$(echo "$line" | jq -r '[.trackerStats[].lastAnnounceResult] | join(", ")')
            seeders=$(echo "$line" | jq -r '[.trackerStats[].seederCount] | add // 0')
            stalled+=("[$id] $name | $pct% | 0 B/s | peers=$peers | seeders=$seeders | trackers: $trackers")
        fi
    elif [ "$status" == "0" ]; then
        stalled+=("[$id] $name | STOPPED | $pct%")
    fi
done < <(echo "$DATA" | jq -c '.arguments.torrents[]')

# ── output ────────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "🩺 Transmission Diagnosis"
echo "═══════════════════════════════════════════════════════════════"

if [ ${#errors[@]} -gt 0 ]; then
    echo ""
    echo "🚨 Torrents with errors:"
    printf '   %s\n' "${errors[@]}"
fi

if [ ${#stalled[@]} -gt 0 ]; then
    echo ""
    echo "🐌 Stalled / 0-speed torrents:"
    printf '   %s\n' "${stalled[@]}"
    echo ""
    echo "   → If seeders=0 and peers=0, the swarm is dead."
    echo "   → If peers>0 but down=0, you may be ASN-blocked (Safaricom AS33771 is widely filtered)."
    echo "   → Consider a Tailscale exit node or VPN for affected torrents."
fi

if [ ${#slow[@]} -gt 0 ]; then
    echo ""
    echo "🐢 Slow torrents (< 1 MB/s):"
    printf '   %s\n' "${slow[@]}"
fi

if [ ${#fast[@]} -gt 0 ]; then
    echo ""
    echo "⚡ Healthy downloads:"
    printf '   %s\n' "${fast[@]}"
fi

if [ ${#seeding[@]} -gt 0 ]; then
    echo ""
    echo "🌱 Seeding:"
    printf '   %s\n' "${seeding[@]}"
fi

if [ ${#errors[@]} -eq 0 ] && [ ${#stalled[@]} -eq 0 ] && [ ${#slow[@]} -eq 0 ] && [ ${#fast[@]} -eq 0 ] && [ ${#seeding[@]} -eq 0 ]; then
    echo ""
    echo "🍿 No active torrents found."
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "💡 Tip: Run '$0 <id>' for full tracker/peer details on one torrent."
echo "═══════════════════════════════════════════════════════════════"
