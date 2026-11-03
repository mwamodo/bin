#!/bin/bash
# shellcheck disable=SC1091,SC2012
# Jellyfin health check — playback, transcode, devices, recent errors
# Usage: ./jellyfin-health.sh [command]
#
# Commands:
#   sessions      Active sessions + transcode info (default)
#   devices       Known devices + last activity
#   transcodes    Current transcode jobs
#   logs [lines]  Recent server log warnings/errors
#   full          All of the above

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${JELLYFIN_URL}"
KEY="${JELLYFIN_API_KEY}"

cmd="${1:-sessions}"

api() {
    curl -s "${URL}/${1}" -H "X-MediaBrowser-Token: ${KEY}" 2>/dev/null | jq -r "${2:-.}"
}

case "$cmd" in
    sessions)
        echo "🎬 Active Sessions:"
        sessions=$(api "Sessions" '.[] | select(.NowPlayingItem != null)')
        if [ -z "$sessions" ]; then
            echo "  🍿 No one is watching"
            exit 0
        fi
        echo "$sessions" | jq -r '
            "  \(.UserName) on \(.DeviceName) (\(.Client) \(.ApplicationVersion // ""))",
            "    → \(.NowPlayingItem.SeriesName // .NowPlayingItem.Name)\(if .NowPlayingItem.SeriesName then " — " + .NowPlayingItem.Name else "" end)",
            "    Position: \((.PlayState.PositionTicks // 0) / 10000000 / 60 | floor)m / \((.NowPlayingItem.RunTimeTicks // 0) / 10000000 / 60 | floor)m",
            "    Paused:   \(if .PlayState.IsPaused then "YES" else "no" end)",
            "    Transcode:\(if .TranscodingInfo then " YES (\(.TranscodingInfo.TranscodeReasons | join(", ")))" else " no (direct)" end)",
            if .TranscodingInfo then
                "      Video: \(.TranscodingInfo.VideoCodec // "—") @ \(.TranscodingInfo.CompletionPercentage // 0 | floor)%",
                "      Audio: \(.TranscodingInfo.AudioCodec // "—")",
                "      Speed: \(.TranscodingInfo.TranscodeSpeed // 0)x",
                "      Drop:  \(.TranscodingInfo.DroppedFrames // 0) dropped"
            else empty end,
            ""
        '
        ;;

    devices)
        echo "📱 Known Devices:"
        api "Devices" '.Items[] | "  \(.Name) — last seen: \(.DateLastActivity // "never") — user: \(.LastUserName // "—")"' 2>/dev/null \
            | head -20 || echo "  (failed to fetch devices)"
        ;;

    transcodes)
        echo "🔧 Active Transcodes:"
        # Jellyfin doesn't expose a direct transcode endpoint; we infer from Sessions
        sessions=$(api "Sessions" '.[] | select(.TranscodingInfo != null)')
        if [ -z "$sessions" ]; then
            echo "  No active transcodes"
            exit 0
        fi
        echo "$sessions" | jq -r '
            "  \(.UserName) — \(.NowPlayingItem.Name // "?")",
            "    Reason:   \(.TranscodingInfo.TranscodeReasons | join(", "))",
            "    Video:    \(.TranscodingInfo.VideoCodec) \(.TranscodingInfo.Width // "?")x\(.TranscodingInfo.Height // "?")",
            "    Bitrate:  \((.TranscodingInfo.Bitrate // 0) / 1000 | floor) kbps",
            "    Speed:    \(.TranscodingInfo.TranscodeSpeed)x",
            "    Complete: \(.TranscodingInfo.CompletionPercentage // 0 | floor)%",
            "    Drop:     \(.TranscodingInfo.DroppedFrames // 0) frames",
            ""
        '
        ;;

    logs)
        lines="${2:-50}"
        echo "📝 Recent log entries (last $lines):"
        # Jellyfin log path varies by install; try common locations
        log_path=""
        for dir in /var/log/jellyfin /DATA/AppData/jellyfin/config/log "$HOME/.local/share/jellyfin/log"; do
            [ -d "$dir" ] || continue
            latest=$(ls -t "$dir"/*.log 2>/dev/null | head -1) || true
            if [ -n "$latest" ] && [ -f "$latest" ]; then
                log_path="$latest"
                break
            fi
        done
        if [ -z "$log_path" ]; then
            echo "  ⚠️  Could not find Jellyfin log files"
            exit 1
        fi
        echo "  (reading $log_path)"
        tail -n "$lines" "$log_path" | grep -iE "(warn|error|fail|transcode|playback|critical)" || echo "  (no warnings/errors in last $lines lines)"
        ;;

    full)
        "$0" sessions
        echo ""
        "$0" devices
        echo ""
        "$0" transcodes
        echo ""
        "$0" logs 30
        ;;

    *)
        echo "Usage: $0 {sessions|devices|transcodes|logs|full}"
        exit 1
        ;;
esac
