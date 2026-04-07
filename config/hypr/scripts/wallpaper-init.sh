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

# Wacht even zodat hyprpaper volledig opgestart is
sleep 0.8

# ---------------------------------------------------------------------------
# Pad 1 — Gebruik de kingstra-wallpaper orchestrator als die beschikbaar is
# ---------------------------------------------------------------------------
if command -v kingstra-wallpaper &>/dev/null; then
    kingstra-wallpaper reload
    exit 0
fi

# ---------------------------------------------------------------------------
# Pad 2 — Fallback: minimale hyprpaper aanroep zonder orchestrator
# ---------------------------------------------------------------------------
_set_wallpaper() {
    local file="$1"
    if command -v hyprctl &>/dev/null; then
        hyprctl hyprpaper preload "$file" 2>/dev/null || true
        hyprctl hyprpaper wallpaper ",$file"   2>/dev/null || true
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
