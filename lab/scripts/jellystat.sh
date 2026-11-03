#!/bin/bash
# Jellystat control — viewing stats, user activity, most watched
# Usage: ./jellystat.sh [command] [args...]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

URL="${JELLYSTAT_URL}"
KEY="${JELLYSTAT_API_KEY}"
TMP=$(mktemp)
trap "rm -f $TMP" EXIT

cmd="${1:-activity}"
shift || true

case "$cmd" in
    activity)
        limit="${1:-20}"
        echo "🎬 Recent Playback Activity:"
        curl -s "${URL}/stats/getPlaybackActivity" -H "x-api-token: ${KEY}" > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
for r in d.get('results', [])[:${limit}]:
    name = r.get('SeriesName') or r.get('NowPlayingItemName') or '?'
    user = r.get('UserName', '?')
    client = r.get('Client', '?')
    print(f'  {user} \u2014 {name} \u2014 {client}')
PYEOF
        ;;
    users)
        echo "👥 Most Active Users:"
        curl -s "${URL}/stats/getMostActiveUsers" -H "x-api-token: ${KEY}" \
            -H "Content-Type: application/json" -d '{"take":10}' > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
for r in (d if isinstance(d, list) else d.get('results', [])):
    name = r.get('Name', r.get('user', '?'))
    plays = r.get('Plays', r.get('plays_count', 0))
    print(f'  {name} \u2014 {plays} plays')
PYEOF
        ;;
    top)
        echo "🏆 Most Viewed Content:"
        echo "  Movies:"
        curl -s "${URL}/stats/getMostViewedByType" -H "x-api-token: ${KEY}" \
            -H "Content-Type: application/json" -d '{"type":"Movie","take":10,"days":365}' > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
for r in (d if isinstance(d, list) else d.get('results', [])):
    print(f'    {r.get("Name",r.get("name","?"))} \u2014 {r.get("Plays",r.get("plays_count",0))} plays')
PYEOF
        echo "  TV Series:"
        curl -s "${URL}/stats/getMostViewedByType" -H "x-api-token: ${KEY}" \
            -H "Content-Type: application/json" -d '{"type":"Series","take":10,"days":365}' > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
for r in (d if isinstance(d, list) else d.get('results', [])):
    print(f'    {r.get("Name",r.get("name","?"))} \u2014 {r.get("Plays",r.get("plays_count",0))} plays')
PYEOF
        ;;
    libraries)
        echo "📚 Library Overview:"
        curl -s "${URL}/stats/getLibraryOverview" -H "x-api-token: ${KEY}" > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
items = d if isinstance(d, list) else d.get('results', [])
for lib in items:
    name = lib.get('Name', lib.get('LibraryName', '?'))
    ic = lib.get('Library_Count', lib.get('item_count', 0))
    pc = lib.get('Play_Count', lib.get('play_count', 0))
    sc = lib.get('Season_Count', 0)
    ec = lib.get('Episode_Count', 0)
    extra = ''
    if sc or ec:
        extra = f' ({sc} seasons, {ec} eps)'
    print(f'  {name}: {ic} titles{extra}')
PYEOF
        ;;
    recent)
        echo "🆕 Recently Added:"
        curl -s "${URL}/api/getRecentlyAdded" -H "x-api-token: ${KEY}" > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
items = d if isinstance(d, list) else d.get('results', [])
for r in items[:10]:
    name = r.get('Name', '?')
    year = r.get('ProductionYear', '?')
    typ = r.get('Type', '?')
    print(f'  {name} ({year}) \u2014 {typ}')
PYEOF
        ;;
    views)
        echo "📊 Views Over Time (last 30 days):"
        curl -s "${URL}/stats/getViewsOverTime" -H "x-api-token: ${KEY}" > "$TMP"
        python3 << PYEOF
import sys, json
with open('${TMP}') as f:
    d = json.load(f)
items = d if isinstance(d, list) else d.get('results', [])
for r in items[-30:]:
    date = r.get('date', '?')
    plays = r.get('total_plays', 0)
    print(f'  {date}: {plays} plays')
PYEOF
        ;;
    *)
        echo "Usage: $0 {activity|users|top|libraries|recent|views}"
        exit 1
        ;;
esac
