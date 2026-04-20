#!/usr/bin/env bash
set -euo pipefail

cwd="${1:-}"
[ -n "$cwd" ] || exit 0

todos_dir="$cwd/.pi/todos"
[ -d "$todos_dir" ] || exit 0

count=$(find "$todos_dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null | wc -l | tr -d '[:space:]')
[ "$count" -gt 0 ] || exit 0

printf " %s" "$count"
