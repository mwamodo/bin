#!/bin/bash
# Pick a project with fzf and switch Rex to its session, creating the session if
# none is open. Run in a floating pane by the "Open Project" action (ctrl+a s).
#
# Projects are each git repo directly in ~/develop, the folders inside every other
# folder in ~/develop (laravel, worktrees, ...), and ~/bin. A session is labelled
# with the project's folder name, or parent/name when two projects share a name.
set -eu

projects() {
    local dir sub
    for dir in "$HOME"/develop/*/; do
        dir=${dir%/}
        if [ -e "$dir/.git" ]; then
            echo "$dir"
        else
            for sub in "$dir"/*/; do
                [ -d "$sub" ] && echo "${sub%/}"
            done
        fi
    done
    echo "$HOME/bin"
}

list=$(projects | sort)
pick=$(printf '%s\n' "$list" | sed "s|^$HOME/|~/|" | fzf --prompt 'Project: ') || exit 0
dir="$HOME/${pick#\~/}"

label=$(basename "$dir")
if [ "$(printf '%s\n' "$list" | awk -F/ -v name="$label" '$NF == name' | wc -l)" -gt 1 ]; then
    label="$(basename "$(dirname "$dir")")/$label"
fi

session=$(rex ls --json | jq -r --arg label "$label" '[.sessions[] | select(.label == $label)][0].session_id // empty')
if [ -z "$session" ]; then
    session=$(rex new "$label" -c "$dir" --json | jq -r '.session_id')
fi

# Switching the app's view is a client action, which Rex only accepts with Remote
# Control on (Settings > Rex Server).
client=$(rex api call session.list_clients "{\"session_id\":\"$REX_SESSION\"}" |
    jq -r '[.clients[] | select(.info.kind == "app")][0].client_id // empty')
if [ -z "$client" ] || ! rex -C "$client" "do" session.select session_id="$session" >/dev/null 2>&1; then
    printf '\nOpened session "%s".\nTurn on Remote Control in Rex Settings > Rex Server to switch to it automatically.\nPress Return to close.' "$label"
    read -r _
fi
