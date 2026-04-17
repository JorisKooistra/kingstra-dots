#!/usr/bin/env bash
set -euo pipefail

dispatcher="${1:-}"
target="${2:-}"

usage() {
    printf 'Usage: %s <dispatcher> <target>\n' "$0" >&2
}

if [[ -z "$dispatcher" || -z "$target" || "$dispatcher" == "-h" || "$dispatcher" == "--help" ]]; then
    usage
    exit 1
fi

if [[ "$target" == *"+"* || "$target" == *"-"* ]]; then
    hyprctl dispatch "$dispatcher" "$target"
    exit 0
fi

if [[ "$target" =~ ^[0-9]+$ ]]; then
    current_workspace="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1')"
    if ! [[ "$current_workspace" =~ ^-?[0-9]+$ ]] || (( current_workspace < 1 )); then
        current_workspace=1
    fi

    target_workspace=$(( ((current_workspace - 1) / 10) * 10 + target ))
    hyprctl dispatch "$dispatcher" "$target_workspace"
    exit 0
fi

hyprctl dispatch "$dispatcher" "$target"
