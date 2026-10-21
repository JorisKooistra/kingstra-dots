#!/usr/bin/env bash
# Dubbelklik-detectie voor de duimknop van de Logitech M720 (mouse:279).
# Vasthouden sleept een venster (bindm in binds.lua); twee keer snel drukken
# opent het overzicht, net als Super+Tab.
set -u

WINDOW_MS="${KINGSTRA_THUMB_DOUBLE_CLICK_MS:-350}"
stamp_file="${XDG_RUNTIME_DIR:-/tmp}/kingstra-thumb-click"
now_ms=$(date +%s%3N)
last_ms=$(cat "$stamp_file" 2>/dev/null || echo 0)
[[ "$last_ms" =~ ^[0-9]+$ ]] || last_ms=0

if (( now_ms - last_ms <= WINDOW_MS )); then
    # Reset zodat een derde klik niet meteen weer togglet.
    echo 0 > "$stamp_file"
    exec "$HOME/.config/hypr/scripts/overview-toggle.sh"
fi

echo "$now_ms" > "$stamp_file"
