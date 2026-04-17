#!/usr/bin/env bash
set -euo pipefail

notify() {
    notify-send "Klembord" "$1" 2>/dev/null || true
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        notify "Ontbrekend commando: $1"
        exit 1
    }
}

need_cmd cliphist
need_cmd wl-copy

choose() {
    if command -v walker >/dev/null 2>&1; then
        walker --dmenu --placeholder "Klembord"
    elif command -v fuzzel >/dev/null 2>&1; then
        fuzzel --dmenu --prompt "Klembord> "
    elif command -v wofi >/dev/null 2>&1; then
        wofi --dmenu --prompt "Klembord"
    else
        notify "Installeer walker, fuzzel of wofi om de geschiedenis te openen."
        exit 1
    fi
}

selection="$(cliphist list 2>/dev/null | choose || true)"

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

notify "Item gekopieerd. Installeer wtype voor automatisch plakken."
