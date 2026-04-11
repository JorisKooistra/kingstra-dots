#!/usr/bin/env bash
set -euo pipefail

selection="$({ cliphist list 2>/dev/null || true; } | walker --stdin --dmenu 2>/dev/null || true)"

[[ -n "$selection" ]] || exit 0

printf '%s' "$selection" | cliphist decode | wl-copy

# Give Walker a moment to close so the previous app is active again.
sleep 0.1

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl --quiet dispatch sendshortcut CTRL,v,activewindow && exit 0
fi

if command -v wtype >/dev/null 2>&1; then
    wtype -M ctrl -P v -p v -m ctrl && exit 0
fi

notify-send "Klembord" "Item gekopieerd. Installeer wtype voor automatisch plakken." 2>/dev/null || true
