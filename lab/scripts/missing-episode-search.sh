#!/bin/bash
# Find missing episodes: cross-reference Sonarr wanted vs library vs downloads
# Usage: ./missing-episode-search.sh [--show "Show Name"] [--season N] [--missing-only]
#
# For each monitored series in Sonarr, checks:
#   - Which episodes are missing (no file on disk)
#   - Whether the episode has aired (no point looking for future eps)
#   - Whether a matching file exists in downloads/complete
#   - Suggests next actions (wait for release, search indexers, check import)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

SONARR_URL="${SONARR_URL}"
SONARR_KEY="${SONARR_API_KEY}"
TV_LIBRARY="${TV_LIBRARY_DIR:-/mnt/DRIVE_B/TV}"
DOWNLOADS_COMPLETE="${DOWNLOADS_COMPLETE:-/mnt/DRIVE_B/Downloads/complete}"

FILTER_SHOW=""
FILTER_SEASON=""
MISSING_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --show)    FILTER_SHOW="$2"; shift ;;
        --season)  FILTER_SEASON="$2"; shift ;;
        --missing-only) MISSING_ONLY=true ;;
        *) echo "Usage: $0 [--show \"Name\"] [--season N] [--missing-only]"; exit 1 ;;
    esac
    shift
done

# ── helpers ───────────────────────────────────────────────────────
api() {
    local path="$1"
    curl -s -H "X-Api-Key: $SONARR_KEY" "${SONARR_URL}${path}" 2>/dev/null | jq '.'
}

has_file_in_downloads() {
    local show_name="$1"
    local season="$2"
    local episode="$3"
    local ep_label
    ep_label=$(printf "S%02dE%02d" "$season" "$episode")

    # Search in complete downloads for show name + episode code
    local search_pattern="*${show_name}*${ep_label}*"
    if find "$DOWNLOADS_COMPLETE" -ipath "$search_pattern" -type f 2>/dev/null | grep -q .; then
        echo "yes"
        return
    fi
    # Also try just the episode code
    if find "$DOWNLOADS_COMPLETE" -ipath "*${ep_label}*" -type f 2>/dev/null | grep -q .; then
        echo "maybe"
        return
    fi
    echo "no"
}

has_file_in_library() {
    local show_name="$1"
    local season="$2"
    local episode="$3"
    local ep_label
    ep_label=$(printf "S%02dE%02d" "$season" "$episode")

    # Jellyfin library layout: /TV/<Show>/Season <N>/
    local show_dir
    show_dir=$(find "$TV_LIBRARY" -maxdepth 1 -type d -iname "*${show_name}*" -print -quit 2>/dev/null)
    if [ -z "$show_dir" ]; then
        echo "no"
        return
    fi

    local season_dir
    season_dir=$(find "$show_dir" -maxdepth 1 -type d -iname "*Season*${season}*" -print -quit 2>/dev/null)
    if [ -z "$season_dir" ]; then
        echo "no"
        return
    fi

    if find "$season_dir" -type f -iname "*${ep_label}*" 2>/dev/null | grep -q .; then
        echo "yes"
        return
    fi
    echo "no"
}

is_aired() {
    local air_date="$1"
    if [ -z "$air_date" ] || [ "$air_date" == "null" ]; then
        return 1  # No air date = unknown, assume not aired
    fi
    local air_ts now_ts
    air_ts=$(date -d "$air_date" +%s 2>/dev/null || echo 0)
    now_ts=$(date +%s)
    [ "$air_ts" -le "$now_ts" ]
}

# ── main ──────────────────────────────────────────────────────────
echo "═══════️═══════════════════════════════════════════════════════════════════════"
echo "🔍 Missing Episode Search"
echo "═══════════════════════════════════════════════════════════════════════"

# Fetch all series
SERIES_JSON=$(api "/api/v3/series")
if [ -z "$SERIES_JSON" ] || [ "$SERIES_JSON" == "null" ]; then
    echo "❌ Failed to fetch series from Sonarr"
    exit 1
fi

total_missing=0
total_in_downloads=0
total_not_aired=0

# Build series list
while IFS=$'\t' read -r series_id series_title monitored path; do
    # Filter by show name if specified
    if [ -n "$FILTER_SHOW" ]; then
        if ! echo "$series_title" | grep -qi "$FILTER_SHOW"; then
            continue
        fi
    fi

    # Skip unmonitored series
    [ "$monitored" == "true" ] || continue

    # Fetch episodes for this series
    EPISODES_JSON=$(api "/api/v3/episode?seriesId=${series_id}")
    if [ -z "$EPISODES_JSON" ]; then
        continue
    fi

    show_has_output=false

    while IFS=$'\t' read -r ep_season ep_number ep_title ep_has_file ep_air_date ep_monitored; do
        # Filter by season if specified
        if [ -n "$FILTER_SEASON" ] && [ "$ep_season" != "$FILTER_SEASON" ]; then
            continue
        fi

        # Skip unmonitored episodes
        [ "$ep_monitored" == "true" ] || continue

        # Skip if already have the file
        [ "$ep_has_file" == "true" ] && continue

        # Check if aired
        if ! is_aired "$ep_air_date"; then
            total_not_aired=$((total_not_aired + 1))
            if [ "$MISSING_ONLY" = true ]; then
                continue  # Skip future episodes in missing-only mode
            fi
            aired_status="📅 NOT AIRED ($ep_air_date)"
        else
            aired_status="⏰ AIRED ($ep_air_date)"
        fi

        if [ "$show_has_output" = false ]; then
            echo ""
            echo "📺 $series_title"
            show_has_output=true
        fi

        ep_label=$(printf "S%02dE%02d" "$ep_season" "$ep_number")

        # Check library
        in_lib=$(has_file_in_library "$series_title" "$ep_season" "$ep_number")

        # Check downloads
        in_dl=$(has_file_in_downloads "$series_title" "$ep_season" "$ep_number")

        if [ "$in_lib" == "yes" ]; then
            # Sonarr thinks missing but file exists — import issue
            echo "  ⚠️  $ep_label — $ep_title"
            echo "      Library has file but Sonarr doesn't know it. Jellyfin may show it."
            total_missing=$((total_missing + 1))
        elif [ "$in_dl" == "yes" ]; then
            echo "  📦  $ep_label — $ep_title | $aired_status"
            echo "      → File found in downloads/complete (import pending or failed)"
            total_missing=$((total_missing + 1))
            total_in_downloads=$((total_in_downloads + 1))
        elif [ "$in_dl" == "maybe" ]; then
            echo "  ❓  $ep_label — $ep_title | $aired_status"
            echo "      → Possible match in downloads (check manually)"
            total_missing=$((total_missing + 1))
        else
            echo "  🔴  $ep_label — $ep_title | $aired_status"
            if is_aired "$ep_air_date"; then
                echo "      → Not in library or downloads. May need indexer search."
            else
                echo "      → Wait for air date."
            fi
            total_missing=$((total_missing + 1))
        fi
    done < <(echo "$EPISODES_JSON" | jq -r '.[] | [(.seasonNumber|tostring), (.episodeNumber|tostring), .title, (.hasFile|tostring), (.airDateUtc // "null"), (.monitored|tostring)] | @tsv')

done < <(echo "$SERIES_JSON" | jq -r '.[] | [(.id|tostring), .title, (.monitored|tostring), .path] | @tsv')

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "📊 Summary"
echo "   Missing episodes checked: $total_missing"
echo "   Files already in downloads: $total_in_downloads"
echo "   Not yet aired: $total_not_aired"
echo ""
echo "💡 Actions:"
echo "   • If files are in downloads but not imported: check Sonarr logs"
echo "   • If aired but missing: trigger search in Sonarr web UI"
echo "   • If not aired: wait — no legit release exists yet"
echo "═══════════════════════════════════════════════════════════════════════"
