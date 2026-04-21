#!/usr/bin/env bash
# =============================================================================
# wallpaper-init.sh — Wallpaper-initialisatie bij Hyprland-start
# =============================================================================
# Dit script wordt aangeroepen vanuit 70-autostart.conf.
# Delegeert aan de kingstra-wallpaper orchestrator (fase 9).
# Vóór fase 9 (of als orchestrator ontbreekt) valt het terug op minimale logica.
# =============================================================================
set -euo pipefail

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"
WALLPAPER_DIR="${KINGSTRA_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

# Wacht even zodat wallpaper-daemons / IPC volledig opgestart zijn
sleep 1.2

# ---------------------------------------------------------------------------
# Pad 1 — Gebruik de kingstra-wallpaper orchestrator als die beschikbaar is
# ---------------------------------------------------------------------------
if command -v kingstra-wallpaper &>/dev/null; then
    if kingstra-wallpaper reload; then
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Pad 2 — Fallback: minimale awww-aanroep zonder orchestrator
# ---------------------------------------------------------------------------
_set_wallpaper() {
    local file="$1"
    if command -v awww &>/dev/null; then
        if ! pgrep -x awww-daemon >/dev/null 2>&1 && command -v awww-daemon >/dev/null 2>&1; then
            awww-daemon >/dev/null 2>&1 &
            sleep 0.5
        fi
        awww img "$file" >/dev/null 2>&1 || true
    fi
}

# Herstel laatste wallpaper als die er is
if [[ -f "$STATE_FILE" ]]; then
    last="$(cat "$STATE_FILE")"
    if [[ -f "$last" ]]; then
        _set_wallpaper "$last"
        exit 0
    fi
fi

# Kies een willekeurig afbeelding uit de map
if [[ -d "$WALLPAPER_DIR" ]]; then
    file="$(find "$WALLPAPER_DIR" -maxdepth 3 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        2>/dev/null | shuf -n 1)"

    if [[ -n "$file" ]]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "$file" > "$STATE_FILE"
        _set_wallpaper "$file"
        exit 0
    fi
fi

echo "[kingstra] Geen wallpapers gevonden in $WALLPAPER_DIR" >&2
echo "[kingstra] Maak de map aan en voeg .jpg/.png/.webp bestanden toe." >&2
exit 0
