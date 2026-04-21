#!/usr/bin/env bash
# =============================================================================
# resume-fix.sh — Post-suspend fixes voor Hyprland
# =============================================================================
# Triggered door kingstra-resume.service na suspend/hibernate.
# Herstelt: WiFi scan, Bluetooth scan, Quickshell, SwayNC, wallpaper-backend.
# =============================================================================
set -euo pipefail

LOG_PREFIX="[kingstra-resume]"
_log()  { echo "$LOG_PREFIX $*" | systemd-cat --identifier=kingstra-resume 2>/dev/null || echo "$LOG_PREFIX $*"; }
_run_timeout() {
    local seconds="$1"
    shift
    if command -v timeout &>/dev/null; then
        timeout --kill-after=2 "$seconds" "$@" 2>/dev/null || true
    else
        "$@" 2>/dev/null || true
    fi
}
_spawn_detached() {
    nohup "$@" >/dev/null 2>&1 &
}

# Wacht even zodat het systeem en netwerk stabiliseren na resume
sleep 2

# ---------------------------------------------------------------------------
# 1 — WiFi rescan
# ---------------------------------------------------------------------------
if command -v nmcli &>/dev/null; then
    _run_timeout 6 nmcli dev wifi rescan
    _log "WiFi rescan gestart"
fi

# ---------------------------------------------------------------------------
# 2 — Bluetooth rescan (korte scan, dan stoppen)
# ---------------------------------------------------------------------------
if command -v bluetoothctl &>/dev/null; then
    _run_timeout 5 bluetoothctl power on
    _run_timeout 5 bluetoothctl scan on &
    sleep 5
    _run_timeout 5 bluetoothctl scan off
    _log "Bluetooth rescan voltooid"
fi

# ---------------------------------------------------------------------------
# 3 — Hyprland DPMS herstellen (scherm kan uit zijn na resume)
# ---------------------------------------------------------------------------
if command -v hyprctl &>/dev/null; then
    _run_timeout 4 hyprctl dispatch dpms on
fi

# ---------------------------------------------------------------------------
# 4 — Quickshell herstart als hij is afgesloten
# ---------------------------------------------------------------------------
if ! pgrep -f "quickshell.*TopBar.qml" &>/dev/null; then
    _log "Quickshell TopBar niet actief — herstart..."
    _spawn_detached quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/TopBar.qml"
fi
if ! pgrep -f "quickshell.*Main.qml" &>/dev/null; then
    _log "Quickshell Main niet actief — herstart..."
    _spawn_detached quickshell -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/Main.qml"
fi
if ! pgrep -f "python3 .*focustime/focus_daemon\\.py" &>/dev/null; then
    _log "FocusTime daemon niet actief — herstart..."
    _spawn_detached python3 "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/focustime/focus_daemon.py"
fi

# ---------------------------------------------------------------------------
# 5 — SwayNC herstart als hij is afgesloten
# ---------------------------------------------------------------------------
if ! pgrep -x swaync &>/dev/null; then
    _log "SwayNC niet actief — herstart..."
    _spawn_detached swaync
fi

# ---------------------------------------------------------------------------
# 6 — Wallpaper-backend herstellen (kan sterven na suspend)
# ---------------------------------------------------------------------------
if command -v awww-daemon &>/dev/null && ! pgrep -x awww-daemon &>/dev/null; then
    _log "awww-daemon niet actief — herstart..."
    _spawn_detached awww-daemon
    sleep 0.8
    if command -v kingstra-wallpaper &>/dev/null; then
        _run_timeout 6 kingstra-wallpaper reload
    fi
fi

# ---------------------------------------------------------------------------
# 7 — Notificatie dat resume-fixes voltooid zijn (optioneel, alleen bij debug)
# ---------------------------------------------------------------------------
# notify-send --app-name="kingstra" "Resume" "Systeem hersteld na suspend" \
#     --urgency=low --expire-time=2000 2>/dev/null || true

_log "Resume-fixes voltooid"
