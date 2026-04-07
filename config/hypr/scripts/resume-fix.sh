#!/usr/bin/env bash
# =============================================================================
# resume-fix.sh — Post-suspend fixes voor Hyprland
# =============================================================================
# Triggered door kingstra-resume.service na suspend/hibernate.
# Herstelt: WiFi scan, Bluetooth scan, Quickshell, SwayNC, hyprpaper.
# =============================================================================
set -euo pipefail

LOG_PREFIX="[kingstra-resume]"
_log()  { echo "$LOG_PREFIX $*" | systemd-cat --identifier=kingstra-resume 2>/dev/null || echo "$LOG_PREFIX $*"; }

# Wacht even zodat het systeem en netwerk stabiliseren na resume
sleep 2

# ---------------------------------------------------------------------------
# 1 — WiFi rescan
# ---------------------------------------------------------------------------
if command -v nmcli &>/dev/null; then
    nmcli dev wifi rescan 2>/dev/null && _log "WiFi rescan gestart" || true
fi

# ---------------------------------------------------------------------------
# 2 — Bluetooth rescan (korte scan, dan stoppen)
# ---------------------------------------------------------------------------
if command -v bluetoothctl &>/dev/null; then
    bluetoothctl power on 2>/dev/null || true
    bluetoothctl scan on  2>/dev/null &
    sleep 5
    bluetoothctl scan off 2>/dev/null || true
    _log "Bluetooth rescan voltooid"
fi

# ---------------------------------------------------------------------------
# 3 — Hyprland DPMS herstellen (scherm kan uit zijn na resume)
# ---------------------------------------------------------------------------
if command -v hyprctl &>/dev/null; then
    hyprctl dispatch dpms on 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 4 — Quickshell herstart als hij is afgesloten
# ---------------------------------------------------------------------------
if ! pgrep -f "quickshell.*shell.qml" &>/dev/null; then
    _log "Quickshell niet actief — herstart..."
    quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/shell.qml" &
    disown
fi

# ---------------------------------------------------------------------------
# 5 — SwayNC herstart als hij is afgesloten
# ---------------------------------------------------------------------------
if ! pgrep -x swaync &>/dev/null; then
    _log "SwayNC niet actief — herstart..."
    swaync &
    disown
fi

# ---------------------------------------------------------------------------
# 6 — Hyprpaper herstellen (kan sterven na suspend)
# ---------------------------------------------------------------------------
if ! pgrep -x hyprpaper &>/dev/null; then
    _log "Hyprpaper niet actief — herstart..."
    hyprpaper &
    sleep 0.8
    if command -v kingstra-wallpaper &>/dev/null; then
        kingstra-wallpaper reload 2>/dev/null || true
    fi
fi

# ---------------------------------------------------------------------------
# 7 — Notificatie dat resume-fixes voltooid zijn (optioneel, alleen bij debug)
# ---------------------------------------------------------------------------
# notify-send --app-name="kingstra" "Resume" "Systeem hersteld na suspend" \
#     --urgency=low --expire-time=2000 2>/dev/null || true

_log "Resume-fixes voltooid"
