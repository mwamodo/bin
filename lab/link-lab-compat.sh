#!/bin/bash
# Lab host only. Run manually after cloning mwamodo/bin into ~/bin on the lab
# server. Creates untracked symlinks so old ~/bin/scripts/<name> and
# ~/bin/night-sleep-rtcwake.sh paths keep working. Never run by ./install.
set -euo pipefail

if [ "$(uname -s)" != "Linux" ]; then
    echo "Refusing: lab-only script (not Linux)" >&2
    exit 1
fi

LAB=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$LAB")
EXCLUDE="$ROOT/.git/info/exclude"

link() {
    local src="$1" dest="$2" rel="${2#"$ROOT"/}"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "Skip (real file exists): $dest" >&2
        return 0
    fi
    ln -sfn "$src" "$dest"
    grep -qxF "/$rel" "$EXCLUDE" 2>/dev/null || echo "/$rel" >> "$EXCLUDE"
}

for f in "$LAB"/scripts/*.sh "$LAB"/scripts/*.py "$LAB"/scripts/.env; do
    [ -e "$f" ] || continue
    link "$f" "$ROOT/scripts/$(basename "$f")"
done
link "$LAB/night-sleep-rtcwake.sh" "$ROOT/night-sleep-rtcwake.sh"
echo "Done. Links are listed in $EXCLUDE"
