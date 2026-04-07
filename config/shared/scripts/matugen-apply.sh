#!/usr/bin/env bash
# =============================================================================
# matugen-apply.sh — Centrale theme-apply pipeline
# =============================================================================
# Gebruik: kingstra-theme-apply <pad/naar/wallpaper>
#          kingstra-theme-apply --reload   (herlaad zonder wallpaper te wisselen)
# =============================================================================
set -euo pipefail

WALLPAPER="${1:-}"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"
LOG_PREFIX="[kingstra-theme]"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_log()  { echo "$LOG_PREFIX $*"; }
_warn() { echo "$LOG_PREFIX WARN: $*" >&2; }

_notify() {
    notify-send --icon=preferences-desktop-theme \
                --app-name="kingstra" \
                "$1" "${2:-}" \
                --urgency=low \
                --expire-time=2000 \
                2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Argumenten
# ---------------------------------------------------------------------------
RELOAD_ONLY=false
if [[ "${WALLPAPER:-}" == "--reload" ]]; then
    RELOAD_ONLY=true
    WALLPAPER="$(cat "$STATE_FILE" 2>/dev/null || echo "")"
fi

if [[ -z "$WALLPAPER" ]]; then
    _warn "Geen wallpaper opgegeven. Gebruik: kingstra-theme-apply <bestand>"
    exit 1
fi

if [[ ! -f "$WALLPAPER" ]]; then
    _warn "Wallpaper niet gevonden: $WALLPAPER"
    exit 1
fi

# ---------------------------------------------------------------------------
# Stap 1 — Matugen uitvoeren (genereert alle template-outputs)
# ---------------------------------------------------------------------------
_log "Matugen uitvoeren op: $WALLPAPER"
matugen image "$WALLPAPER" \
    --config "${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml" \
    --source-color-index "${MATUGEN_COLOR_INDEX:-0}" \
    2>/dev/null

_log "Templates gegenereerd"

# ---------------------------------------------------------------------------
# Stap 2 — Wallpaper toepassen (tenzij --reload)
# ---------------------------------------------------------------------------
if ! $RELOAD_ONLY; then
    _log "Wallpaper instellen: $WALLPAPER"
    mkdir -p "$(dirname "$STATE_FILE")"
    echo "$WALLPAPER" > "$STATE_FILE"

    # awww
    if command -v awww &>/dev/null; then
        awww img "$WALLPAPER" --transition-type random 2>/dev/null || \
        awww img "$WALLPAPER" 2>/dev/null || true
        _log "Wallpaper ingesteld via awww"
    fi
fi

# ---------------------------------------------------------------------------
# Stap 3 — Apps herladen met nieuwe kleuren
# ---------------------------------------------------------------------------

# Hyprland — colors.conf is al geschreven door matugen, reload triggert het
if command -v hyprctl &>/dev/null; then
    hyprctl reload 2>/dev/null || true
    _log "Hyprland herladen"
fi

# Quickshell — herstart (laadt colors.json opnieuw)
if pgrep -f "quickshell.*shell.qml" &>/dev/null; then
    pkill -f "quickshell.*shell.qml" 2>/dev/null || true
    sleep 0.4
    quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml" &
    disown
    _log "Quickshell herstart"
fi

# SwayNC — herstart voor nieuwe CSS
if pgrep -x swaync &>/dev/null; then
    pkill -x swaync 2>/dev/null || true
    sleep 0.2
    swaync &
    disown
    _log "SwayNC herstart"
fi

# Kitty — stuur SIGUSR1 voor config-reload (kleuren.conf is bijgewerkt)
if pgrep -x kitty &>/dev/null; then
    pkill -USR1 kitty 2>/dev/null || true
    _log "Kitty herladen"
fi

# GTK — gsettings prikkel voor thema-refresh
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" 2>/dev/null || true

# SDDM — wallpaper bijwerken in theme.conf (zodat loginscherm klopt)
SDDM_THEME_CONF="/usr/share/sddm/themes/kingstra/theme.conf"
if [[ -f "$SDDM_THEME_CONF" ]]; then
    if sudo -n sed -i "s|^background=.*|background=$WALLPAPER|" "$SDDM_THEME_CONF" 2>/dev/null; then
        _log "SDDM-wallpaper bijgewerkt"
    fi
fi

# ---------------------------------------------------------------------------
# Stap 4 — Afgerond
# ---------------------------------------------------------------------------
_log "Kleurapplicatie voltooid"
_notify "Thema bijgewerkt" "Kleuren gegenereerd vanuit $(basename "$WALLPAPER")"
