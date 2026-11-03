#!/bin/bash
# Import completed audiobooks from Transmission downloads to Audiobookshelf
# Usage: ./audiobook-import.sh [--dry-run]
#
# Scans /mnt/DRIVE_B/Downloads/complete for audiobook-looking directories
# (containing .m4b, .mp3, .aac, .ogg, .flac, .wma, .opus) and moves them
# to /mnt/DRIVE_A/Audiobooks/<Title> if not already present.
#
# Requires: .env with TRANSMISSION_HOST, TRANSMISSION_AUTH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=.env
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

DOWNLOADS_COMPLETE="${AUDIOBOOK_DOWNLOAD_DIR:-/mnt/DRIVE_B/Downloads/complete}"
LIBRARY_ROOT="${AUDIOBOOK_LIBRARY_DIR:-/mnt/DRIVE_A/Audiobooks}"
DRY_RUN=false

if [ "${1:-}" == "--dry-run" ]; then
    DRY_RUN=true
    echo "🧪 DRY RUN — no files will be moved"
fi

mkdir -p "$LIBRARY_ROOT"

# Supported audiobook extensions (case-insensitive)
AUDIO_EXTS="-iname *.m4b -o -iname *.mp3 -o -iname *.aac -o -iname *.ogg -o -iname *.flac -o -iname *.wma -o -iname *.opus -o -iname *.m4a"

found=0
imported=0
skipped=0

# Look for directories under downloads that contain audio files
while IFS= read -r -d '' dir; do
    # Check if dir contains audio files
    audio_files=$(find "$dir" -maxdepth 2 -type f \( $AUDIO_EXTS \) -print -quit 2>/dev/null)
    if [ -z "$audio_files" ]; then
        continue
    fi

    found=$((found + 1))

    # Derive title from directory name (strip common suffixes)
    basename_dir=$(basename "$dir")
    # Clean up common patterns: "Author - Title", "Title [ Audiobook ]", etc.
    title=$(echo "$basename_dir" | sed -E \
        -e 's/\[.*\]//g' \
        -e 's/\(.*\)//g' \
        -e 's/[-_]+Audiobook[-_]*//i' \
        -e 's/[-_]+MP3[-_]*//i' \
        -e 's/[-_]+M4B[-_]*//i' \
        -e 's/[-_]+Unabridged[-_]*//i' \
        -e 's/[[:space:]]+/ /g' \
        -e 's/^[[:space:]]+//g' \
        -e 's/[[:space:]]+$//g')

    dest_dir="$LIBRARY_ROOT/$title"

    if [ -d "$dest_dir" ]; then
        echo "⏭️  SKIP: '$title' already exists in library"
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "📖 WOULD IMPORT: '$title'"
        echo "   from: $dir"
        echo "   to:   $dest_dir"
    else
        echo "📖 IMPORT: '$title'"
        mv "$dir" "$dest_dir"
        # Set ownership to match library (audiobookshelf runs as user 1000 typically)
        chown -R "$(stat -c '%u:%g' "$LIBRARY_ROOT")" "$dest_dir" 2>/dev/null || true
        imported=$((imported + 1))
    fi
done < <(find "$DOWNLOADS_COMPLETE" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "📊 Summary: $found audiobook-looking dirs found"
echo "   Imported: $imported"
echo "   Skipped:  $skipped"
if [ "$DRY_RUN" = true ]; then
    echo "   (dry run — nothing moved)"
fi
echo "═══════════════════════════════════════════════════════════════"
echo "💡 After importing, trigger an Audiobookshelf library scan:"
echo "   curl -X POST http://<audiobookshelf>:13378/api/libraries/<id>/scan"
