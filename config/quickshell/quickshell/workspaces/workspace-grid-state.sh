#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra"
state_file="$state_dir/workspace-grid-order.json"
action="${1:-load}"

mkdir -p "$state_dir"

case "$action" in
    load)
        if [[ -f "$state_file" ]]; then
            cat "$state_file"
        else
            printf '{}\n'
        fi
        ;;
    save)
        payload="${2:-{}}"
        tmp_file="$(mktemp "$state_file.XXXXXX")"
        printf '%s\n' "$payload" > "$tmp_file"
        mv "$tmp_file" "$state_file"
        ;;
    *)
        printf 'Usage: %s [load|save <json>]\n' "$0" >&2
        exit 1
        ;;
esac
