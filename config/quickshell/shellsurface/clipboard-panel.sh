#!/usr/bin/env bash
# Argument-safe bridge between the native Quickshell drawer and cliphist.
set -euo pipefail

feedback_file="/tmp/kingstra-feedback.json"

case "${1:-list}" in
    list)
        if ! command -v cliphist >/dev/null 2>&1; then
            printf '[]\n'
            exit 0
        fi
        cliphist list 2>/dev/null | head -n 80 | jq -Rsc 'split("\n") | map(select(length > 0))'
        ;;
    copy)
        entry="${2:-}"
        [[ -n "$entry" ]] || exit 0
        command -v cliphist >/dev/null 2>&1 || exit 1
        command -v wl-copy >/dev/null 2>&1 || exit 1
        printf '%s\n' "$entry" | cliphist decode | wl-copy

        # The native feedback toast observes this file. Write atomically so a
        # partial JSON document can never become visible.
        tmp="$(mktemp "$feedback_file.XXXXXX")"
        jq -n --arg token "$(date +%s%3N)-clipboard" \
            --arg icon "󰄀" --arg title "Klembord gekopieerd" \
            --arg body "Klaar om te plakken" --arg level "normal" \
            '{token: $token, icon: $icon, title: $title, body: $body, level: $level, timeout: 1800}' >"$tmp"
        mv "$tmp" "$feedback_file"
        ;;
    *)
        printf 'Gebruik: %s {list|copy ENTRY}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
