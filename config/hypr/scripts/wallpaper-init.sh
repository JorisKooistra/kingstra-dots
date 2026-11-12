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
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
if command -v kingstra-wallpaper &>/dev/null; then
    if kingstra-wallpaper reload; then
        exit 0
    fi
    echo "[kingstra] kingstra-wallpaper reload mislukt — terugval op skwd (video speelt dan niet)" >&2
else
    echo "[kingstra] kingstra-wallpaper niet gevonden — terugval op skwd (video speelt dan niet)" >&2
fi

# ---------------------------------------------------------------------------
# Pad 2 — Fallback: minimale skwd-aanroep zonder orchestrator
# ---------------------------------------------------------------------------
# Video → stilstaand beeld (het frame dat kingstra-wallpaper maakt). skwd en
# matugen krijgen nooit een video als foto: een mp4 als "static" liet skwd's
# magick tot 12 GB groeien en na een herstart bleef de achtergrond leeg
# (2026-11-11). Geen frame bekend → geen pad (return 1).
_kingstra_still() {
    local file="${1:-}" hash frame
    case "${file,,}" in
        *.mp4|*.webm|*.mkv|*.mov|*.avi|*.m4v) ;;
        *) printf '%s\n' "$file"; return 0 ;;
    esac
    [[ -f "$file" ]] || return 1
    hash="$(printf '%s:%s:%s' "$file" "$(stat -c '%Y' "$file" 2>/dev/null || echo 0)" "$(stat -c '%s' "$file" 2>/dev/null || echo 0)" | sha1sum | awk '{print $1}')"
    frame="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/video-frames/$hash.jpg"
    [[ -s "$frame" ]] || return 1
    printf '%s\n' "$frame"
}

_set_wallpaper() {
    local file="$1"
    if command -v skwd &>/dev/null; then
        systemctl --user start skwd-daemon.service >/dev/null 2>&1 || true
        skwd wall apply "{\"path\":\"$file\"}" >/dev/null 2>&1 || true
    fi
}

# Herstel laatste wallpaper als die er is
if [[ -f "$STATE_FILE" ]]; then
    last="$(cat "$STATE_FILE")"
    last="$(_kingstra_still "$last" || echo "")"
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
