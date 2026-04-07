#!/usr/bin/env bash
# =============================================================================
# wallpaper-init.sh — Minimale wallpaper-init (fase 3)
# =============================================================================
# Fase 9 vervangt dit script door de volledige wallpaper-orchestratorlaag.
# Dit script zorgt alleen dat er een werkende wallpaper is op eerste start.
# =============================================================================

WALLPAPER_DIR="${KINGSTRA_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"

# Wacht even zodat hyprpaper tijd heeft om te starten
sleep 0.5

_set_wallpaper() {
    local file="$1"
    if command -v hyprpaper &>/dev/null; then
        hyprctl hyprpaper preload "$file" 2>/dev/null || true
        hyprctl hyprpaper wallpaper ",$file"   2>/dev/null || true
    fi
}

# Herstel laatste wallpaper als die er was
if [[ -f "$STATE_FILE" ]]; then
    last="$(cat "$STATE_FILE")"
    if [[ -f "$last" ]]; then
        _set_wallpaper "$last"
        exit 0
    fi
fi

# Kies een willekeurige wallpaper uit de map
if [[ -d "$WALLPAPER_DIR" ]]; then
    file="$(find "$WALLPAPER_DIR" -maxdepth 2 -type f \
        \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
        2>/dev/null | shuf -n 1)"

    if [[ -n "$file" ]]; then
        mkdir -p "$(dirname "$STATE_FILE")"
        echo "$file" > "$STATE_FILE"
        _set_wallpaper "$file"
        exit 0
    fi
fi

# Geen wallpaper gevonden — log een waarschuwing
echo "[kingstra] Geen wallpapers gevonden in $WALLPAPER_DIR" >&2
echo "[kingstra] Maak de map aan en voeg .jpg/.png/.webp bestanden toe." >&2
