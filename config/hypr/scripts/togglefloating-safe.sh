#!/usr/bin/env bash
set -u

active_json="$(hyprctl activewindow -j 2>/dev/null || true)"
[[ -n "$active_json" && "$active_json" != "null" ]] || exit 0

win_class="$(printf '%s' "$active_json" | jq -r '.class // ""' 2>/dev/null)"
win_title="$(printf '%s' "$active_json" | jq -r '.title // ""' 2>/dev/null)"
win_floating="$(printf '%s' "$active_json" | jq -r '.floating // false' 2>/dev/null)"

# Quickshell windows must stay floating.
if [[ "$win_class" == "org.quickshell" || "$win_title" == "qs-master" ]]; then
    if [[ "$win_floating" != "true" ]]; then
        hyprctl dispatch togglefloating >/dev/null 2>&1 || true
    fi
    exit 0
fi

hyprctl dispatch togglefloating >/dev/null 2>&1 || true
