#!/bin/bash
# shellcheck disable=SC1091,SC2034
# Audit downloads folder: orphaned files, old incomplete, space hogs
# Usage: ./downloads-audit.sh [--incomplete-only|--complete-only|--orphans|--old-days N]
#
# Checks:
#   - Orphaned files (incomplete downloads with no active torrent)
#   - Old incomplete downloads (stuck for N+ days)
#   - Space usage by category
#   - Completed items not yet imported

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

DOWNLOADS_ROOT="${DOWNLOADS_DIR:-/mnt/DRIVE_B/Downloads}"
INCOMPLETE_DIR="$DOWNLOADS_ROOT/incomplete"
COMPLETE_DIR="$DOWNLOADS_ROOT/complete"
OLD_DAYS=7
MODE="all"

while [ $# -gt 0 ]; do
    case "$1" in
        --incomplete-only) MODE="incomplete" ;;
        --complete-only)   MODE="complete" ;;
        --orphans)         MODE="orphans" ;;
        --old-days)        OLD_DAYS="$2"; shift ;;
        *) echo "Usage: $0 [--incomplete-only|--complete-only|--orphans|--old-days N]"; exit 1 ;;
    esac
    shift
done

# ── helpers ───────────────────────────────────────────────────────
human_bytes() {
    local bytes="$1"
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec-i --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B"
    else
        echo "${bytes}B"
    fi
}

get_torrent_paths() {
    local host="${TRANSMISSION_HOST}"
    local auth="${TRANSMISSION_AUTH}"
    local session
    session=$(curl -s -u "$auth" "http://$host/transmission/rpc" 2>&1 | grep -oP 'X-Transmission-Session-Id: \K[^<]+' | head -1)
    [ -z "$session" ] && { echo ""; return; }
    curl -s -u "$auth" -H "X-Transmission-Session-Id: $session" \
        "http://$host/transmission/rpc" \
        -d '{"method":"torrent-get","arguments":{"fields":["id","name","downloadDir","percentDone","status"]}}' 2>/dev/null | \
        jq -r '.arguments.torrents[] | "\(.id)|\(.name)|\(.downloadDir)|\(.percentDone)|\(.status)"'
}

# ── orphans: incomplete dirs with no matching active torrent ──────
check_orphans() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "🔍 Orphaned Incomplete Downloads"
    echo "═══════════════════════════════════════════════════════════════"

    local torrents
    torrents=$(get_torrent_paths)
    if [ -z "$torrents" ]; then
        echo "⚠️  Could not fetch torrent list from Transmission"
        return
    fi

    local found=0
    local total_size=0

    while IFS= read -r -d '' dir; do
        local basename_dir name_lower matched=false
        basename_dir=$(basename "$dir")
        name_lower=$(echo "$basename_dir" | tr '[:upper:]' '[:lower:]')

        while IFS='|' read -r tid tname tdir tpct tstatus; do
            local tname_lower
            tname_lower=$(echo "$tname" | tr '[:upper:]' '[:lower:]')
            if [ "$name_lower" == "$tname_lower" ] || [[ "$name_lower" == *"$tname_lower"* ]] || [[ "$tname_lower" == *"$name_lower"* ]]; then
                matched=true
                break
            fi
        done <<< "$torrents"

        if [ "$matched" = false ]; then
            local size
            size=$(du -sb "$dir" 2>/dev/null | cut -f1)
            total_size=$((total_size + size))
            found=$((found + 1))
            echo "  🗑️  $basename_dir ($(human_bytes "$size"))"
        fi
    done < <(find "$INCOMPLETE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "  ✅ No orphaned incomplete downloads"
    else
        echo ""
        echo "  Total orphaned: $found dirs, $(human_bytes "$total_size")"
        echo "  → Remove with: rm -rf $INCOMPLETE_DIR/<name>"
    fi
}

# ── old incomplete downloads ──────────────────────────────────────
check_old() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "⏰ Incomplete Downloads Older Than $OLD_DAYS Days"
    echo "═══════════════════════════════════════════════════════════════"

    local found=0
    local total_size=0

    while IFS= read -r -d '' dir; do
        local mtime age_days basename_dir size
        mtime=$(stat -c '%Y' "$dir" 2>/dev/null || echo 0)
        age_days=$(( ($(date +%s) - mtime) / 86400 ))
        if [ "$age_days" -ge "$OLD_DAYS" ]; then
            basename_dir=$(basename "$dir")
            size=$(du -sb "$dir" 2>/dev/null | cut -f1)
            total_size=$((total_size + size))
            found=$((found + 1))
            echo "  🐌 $basename_dir | ${age_days}d old | $(human_bytes "$size")"
        fi
    done < <(find "$INCOMPLETE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "  ✅ No old incomplete downloads"
    else
        echo ""
        echo "  Total old: $found dirs, $(human_bytes "$total_size")"
    fi
}

# ── complete but not imported ─────────────────────────────────────
check_complete() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "📦 Completed Downloads (in $COMPLETE_DIR)"
    echo "═══════════════════════════════════════════════════════════════"

    local found=0
    local total_size=0

    while IFS= read -r -d '' item; do
        local basename_item size
        basename_item=$(basename "$item")
        size=$(du -sb "$item" 2>/dev/null | cut -f1)
        total_size=$((total_size + size))
        found=$((found + 1))
        echo "  📁 $basename_item ($(human_bytes "$size"))"
    done < <(find "$COMPLETE_DIR" -mindepth 1 -maxdepth 1 -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "  ✅ Nothing in complete folder"
    else
        echo ""
        echo "  Total: $found items, $(human_bytes "$total_size")"
        echo "  → Sonarr should have imported these. If not, check *arr logs."
    fi
}

# ── space summary ─────────────────────────────────────────────────
show_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "💾 Space Usage Summary"
    echo "═══════════════════════════════════════════════════════════════"

    local inc_size comp_size total
    inc_size=$(du -sb "$INCOMPLETE_DIR" 2>/dev/null | cut -f1)
    comp_size=$(du -sb "$COMPLETE_DIR" 2>/dev/null | cut -f1)
    total=$((inc_size + comp_size))

    echo "  Incomplete: $(human_bytes "$inc_size")"
    echo "  Complete:   $(human_bytes "$comp_size")"
    echo "  Total:      $(human_bytes "$total")"

    local drive_usage drive_total drive_avail
    drive_usage=$(df -B1 "$DOWNLOADS_ROOT" 2>/dev/null | awk 'NR==2{print $3}')
    drive_total=$(df -B1 "$DOWNLOADS_ROOT" 2>/dev/null | awk 'NR==2{print $2}')
    drive_avail=$(df -B1 "$DOWNLOADS_ROOT" 2>/dev/null | awk 'NR==2{print $4}')

    if [ -n "$drive_total" ]; then
        echo ""
        echo "  Drive: $(human_bytes "$drive_total") total, $(human_bytes "$drive_avail") free ($(human_bytes "$drive_usage") used)"
    fi
}

# ── main ──────────────────────────────────────────────────────────
case "$MODE" in
    orphans)
        check_orphans
        ;;
    incomplete)
        check_old
        show_summary
        ;;
    complete)
        check_complete
        ;;
    all)
        check_orphans
        check_old
        check_complete
        show_summary
        ;;
esac

echo ""
echo "═══════════════════════════════════════════════════════════════"
