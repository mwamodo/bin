#!/bin/bash
# shellcheck disable=SC2086
# check jellyfin and suspend lab if idle
# called by Yamyulack's cron job at 02:00 (Africa/Nairobi)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# check jellyfin status
status=$("$SCRIPT_DIR/jellyfin-status.sh" 2>/dev/null)

if echo "$status" | grep -qi "no one is watching"; then
    # calculate wake time based on day
    day=$(date +%u)  # 1=Monday, 7=Sunday

    if [[ "$day" -eq 6 || "$day" -eq 7 ]]; then
        waketime="10:00"
    else
        waketime="16:30"
    fi

    # calculate wake timestamp for today
    wake_ts=$(date -d "today $waketime" +%s)
    current_ts=$(date +%s)

    # if wake time already passed (shouldn't happen at 02:00, but safety check)
    if [[ "$current_ts" -ge "$wake_ts" ]]; then
        # schedule for tomorrow
        if [[ "$day" -eq 5 || "$day" -eq 6 ]]; then
            waketime="10:00"  # tomorrow is weekend
        else
            waketime="16:30"
        fi
        wake_ts=$(date -d "tomorrow $waketime" +%s)
    fi

    echo "SLEEP:OK - suspending lab until $waketime"
    sudo rtcwake -m mem -t $wake_ts 2>/dev/null
else
    echo "SLEEP:BUSY - someone is watching"
    echo "$status"
fi
