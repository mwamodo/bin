#!/usr/bin/env bash
set -euo pipefail

LOG_TAG="night-sleep-rtcwake"
RTCWAKE_BIN="/usr/sbin/rtcwake"
SLEEP_MODE="mem"
WAKE_TIME="08:30"
DRY_RUN="${DRY_RUN:-0}"

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
fi

log() {
  logger -t "$LOG_TAG" "$*"
  printf '%s %s\n' "$(date '+%F %T %Z')" "$*"
}

if [[ $EUID -ne 0 ]]; then
  log "ERROR: must run as root"
  exit 1
fi

if [[ ! -x "$RTCWAKE_BIN" ]]; then
  log "ERROR: rtcwake not found at $RTCWAKE_BIN"
  exit 1
fi

wake_epoch=$(date -d "today ${WAKE_TIME}" +%s)
now_epoch=$(date +%s)

if (( wake_epoch <= now_epoch )); then
  wake_epoch=$(date -d "tomorrow ${WAKE_TIME}" +%s)
fi

wake_human=$(date -d "@${wake_epoch}" '+%F %T %Z')
cmd=("$RTCWAKE_BIN" -m "$SLEEP_MODE" -t "$wake_epoch")

if [[ "$DRY_RUN" == "1" ]]; then
  log "DRY RUN: would schedule wake for ${wake_human} and suspend with mode=${SLEEP_MODE}"
  printf 'Command: %q ' "${cmd[@]}"
  printf '\n'
  exec "$RTCWAKE_BIN" -n -m "$SLEEP_MODE" -t "$wake_epoch"
fi

log "Scheduling wake for ${wake_human} and suspending with mode=${SLEEP_MODE}"
exec "${cmd[@]}"
