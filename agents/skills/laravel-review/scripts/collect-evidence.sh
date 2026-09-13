#!/usr/bin/env bash
# Stable entry point. Run from the reviewed repository, or pass --repo PATH.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || { echo 'ERROR: python3 is required' >&2; exit 2; }
exec python3 "$SCRIPT_DIR/collect_evidence.py" "$@"
