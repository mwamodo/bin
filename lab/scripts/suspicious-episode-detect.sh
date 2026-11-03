#!/bin/bash
# Detect suspicious/fake episode files masquerading as video
# Usage: ./suspicious-episode-detect.sh [--path <dir>|--downloads|--library|--fix]
#
# Scans for files with video-looking names but non-video extensions:
#   .exe .bat .scr .cmd .vbs .ps1 .zip .rar .7z .tar.gz
#
# Also flags files with double extensions (e.g. .mkv.exe).
# With --fix, moves suspicious files to a quarantine dir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

DOWNLOADS_COMPLETE="${DOWNLOADS_COMPLETE:-/mnt/DRIVE_B/Downloads/complete}"
TV_LIBRARY="${TV_LIBRARY_DIR:-/mnt/DRIVE_B/TV}"
MOVIE_LIBRARY="${MOVIE_LIBRARY_DIR:-/mnt/DRIVE_A/Movies}"
QUARANTINE="${QUARANTINE_DIR:-/mnt/DRIVE_B/Downloads/quarantine}"

SCAN_PATH=""
FIX_MODE=false
MODE=""

while [ $# -gt 0 ]; do
    case "$1" in
        --path)      SCAN_PATH="$2"; shift ;;
        --downloads) MODE="downloads" ;;
        --library)   MODE="library" ;;
        --fix)       FIX_MODE=true ;;
        *) echo "Usage: $0 [--path <dir>|--downloads|--library] [--fix]"; exit 1 ;;
    esac
    shift
done

# Default to both downloads + library if no scope specified
if [ -z "$SCAN_PATH" ] && [ -z "$MODE" ]; then
    MODE="all"
fi

# ── helpers ───────────────────────────────────────────────────────
BAD_EXTS="exe|bat|scr|cmd|vbs|ps1|zip|rar|7z|tar\.gz|gz|iso|dmg|apk|msi|jar|dll|wsf|hta|com"
VIDEO_EXTS="mp4|mkv|avi|mov|wmv|flv|webm|m4v|mpg|mpeg|ts|m2ts|vob|ogv|3gp"

is_suspicious() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")

    # Direct bad extension
    if echo "$filename" | grep -qiE "\.($BAD_EXTS)$"; then
        echo "bad_ext"
        return 0
    fi

    # Double extension: video-looking name with bad inner ext
    # e.g. Show.S01E01.1080p.WEB-DL.mkv.exe
    if echo "$filename" | grep -qiE "\.($VIDEO_EXTS)\.[a-z0-9]+$"; then
        local inner_ext
        inner_ext=$(echo "$filename" | sed -E 's/.*\.([a-z0-9]+)$/#\1#/')
        # Check if the final extension is bad
        if echo "$filename" | grep -qiE "\.($BAD_EXTS)$"; then
            echo "double_ext"
            return 0
        fi
    fi

    # File with video-looking name but no known video extension
    if echo "$filename" | grep -qiE "(S[0-9]+E[0-9]+|Season|Episode|1080p|720p|WEB-DL|BluRay|HDTV)"; then
        if ! echo "$filename" | grep -qiE "\.($VIDEO_EXTS)$"; then
            # But it might be a subtitle, nfo, sample, etc.
            if echo "$filename" | grep -qiE "\.(srt|sub|ass|ssa|nfo|txt|jpg|png|sfv|md5|par2|torrent|url)$"; then
                return 1
            fi
            echo "no_video_ext"
            return 0
        fi
    fi

    return 1
}

scan_dir() {
    local dir="$1"
    local label="$2"
    local found=0

    while IFS= read -r -d '' file; do
        local reason
        reason=$(is_suspicious "$file") || true
        if [ -n "$reason" ]; then
            found=$((found + 1))
            local size
            size=$(stat -c '%s' "$file" 2>/dev/null || echo 0)
            local reason_str
            case "$reason" in
                bad_ext)     reason_str="BAD EXTENSION" ;;
                double_ext)  reason_str="DOUBLE EXTENSION" ;;
                no_video_ext) reason_str="NO VIDEO EXT" ;;
                *)           reason_str="UNKNOWN" ;;
            esac
            printf "  ⚠️  %-25s | %s | %s\n" "$reason_str" "$(basename "$file")" "$size"
        fi
    done < <(find "$dir" -type f -print0 2>/dev/null)

    return "$found"
}

# ── main ──────────────────────────────────────────────────────────
if [ "$FIX_MODE" = true ] && [ ! -d "$QUARANTINE" ]; then
    mkdir -p "$QUARANTINE"
fi

echo "═══════════════════════════════════════════════════════════════════════"
echo "🚨 Suspicious Episode Detection"
echo "═══════════════════════════════════════════════════════════════════════"

total_found=0

scan_target() {
    local path="$1"
    local label="$2"

    if [ ! -d "$path" ]; then
        echo ""
        echo "$label: directory not found ($path)"
        return
    fi

    echo ""
    echo "📁 $label ($path)"

    local found=0
    while IFS= read -r -d '' file; do
        local reason
        reason=$(is_suspicious "$file") || true
        if [ -n "$reason" ]; then
            found=$((found + 1))
            local size
            size=$(stat -c '%s' "$file" 2>/dev/null || echo 0)
            local reason_str
            case "$reason" in
                bad_ext)      reason_str="BAD EXTENSION" ;;
                double_ext)   reason_str="DOUBLE EXTENSION" ;;
                no_video_ext) reason_str="NO VIDEO EXT" ;;
                *)            reason_str="UNKNOWN" ;;
            esac
            printf "  ⚠️  %-25s | %s | %s bytes\n" "$reason_str" "$(basename "$file")" "$size"

            if [ "$FIX_MODE" = true ]; then
                local dest="$QUARANTINE/$label-$(basename "$file")"
                mv "$file" "$dest" 2>/dev/null && echo "      → moved to quarantine" || echo "      ❌ failed to quarantine"
            fi
        fi
    done < <(find "$path" -maxdepth 4 -type f -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "  ✅ No suspicious files found"
    else
        total_found=$((total_found + found))
    fi
}

# Run scans based on mode
if [ -n "$SCAN_PATH" ]; then
    scan_target "$SCAN_PATH" "Custom Path"
elif [ "$MODE" == "downloads" ] || [ "$MODE" == "all" ]; then
    scan_target "$DOWNLOADS_COMPLETE" "Downloads"
fi

if [ "$MODE" == "library" ] || [ "$MODE" == "all" ]; then
    scan_target "$TV_LIBRARY" "TV Library"
    scan_target "$MOVIE_LIBRARY" "Movie Library"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
if [ "$total_found" -eq 0 ]; then
    echo "✅ All clear — no suspicious files detected"
else
    echo "⚠️  Found $total_found suspicious file(s)"
    if [ "$FIX_MODE" = false ]; then
        echo "   Run with --fix to move suspicious files to quarantine:"
        echo "   $0 --fix"
    fi
fi
if [ "$FIX_MODE" = true ]; then
    echo "   Quarantine dir: $QUARANTINE"
fi
echo "═══════════════════════════════════════════════════════════════════════"
