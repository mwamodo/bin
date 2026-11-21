#!/bin/bash
# Print the folder of every project, sorted. The "Open Project" action in actions.lua
# (ctrl+a s) lists them in its picker.
#
# Projects are each git repo directly in ~/develop, the folders inside every other
# folder in ~/develop (laravel, worktrees, ...), the packages in ~/develop/packages/php
# and ~/develop/packages/js, and ~/bin. ~/develop/flutter and ~/develop/templates are
# skipped.
set -eu

# Print each argument that is a folder, without its trailing slash. An unmatched
# glob arrives as the pattern itself and is dropped.
folders() {
    local path
    for path in "$@"; do
        if [ -d "$path" ]; then echo "${path%/}"; fi
    done
}

projects() {
    local dir
    for dir in "$HOME"/develop/*/; do
        dir=${dir%/}
        case ${dir##*/} in
        # Skip folders that hold no projects. flutter is the Flutter SDK checkout.
        flutter | templates) ;;
        # Packages are grouped by language: packages/php/<name>, packages/js/<name>.
        packages) folders "$dir"/*/*/ ;;
        *)
            if [ -e "$dir/.git" ]; then
                echo "$dir"
            else
                folders "$dir"/*/
            fi
            ;;
        esac
    done
    echo "$HOME/bin"
}

projects | sort
