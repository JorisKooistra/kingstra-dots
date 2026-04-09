#!/usr/bin/env bash
# =============================================================================
# matugen-apply.sh — Compat wrapper rond apply-shell-state
# =============================================================================
# Gebruik: kingstra-theme-apply <pad/naar/wallpaper>
#          kingstra-theme-apply --reload   (herlaad zonder wallpaper te wisselen)
# Matugen zelf wordt uitsluitend gestart via kingstra-matugen-run.
# =============================================================================
set -euo pipefail

WALLPAPER="${1:-}"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/kingstra/last-wallpaper"
APPLY_SCRIPT="${HOME}/.local/bin/apply-shell-state"
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
# Stap 1 — Wallpaper toepassen (tenzij --reload)
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
# Stap 2 — Centrale apply uitvoeren (runner + reloads)
# ---------------------------------------------------------------------------
if [[ ! -x "$APPLY_SCRIPT" ]]; then
    _warn "apply-shell-state niet gevonden: $APPLY_SCRIPT"
    exit 1
fi

if $RELOAD_ONLY; then
    "$APPLY_SCRIPT" || true
else
    "$APPLY_SCRIPT" --wallpaper "$WALLPAPER" || true
fi

_log "Kleurapplicatie voltooid via apply-shell-state"
_notify "Thema bijgewerkt" "Kleuren gegenereerd vanuit $(basename "$WALLPAPER")"
