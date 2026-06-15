#!/usr/bin/env bash
set -u

# Zet config.monitor van skwd-wall op de momenteel gefocuste monitor, zodat de
# picker op het actieve scherm opent i.p.v. op een verouderde waarde. De picker
# bindt zijn PanelWindow.screen aan dit veld (WallpaperSelector.qml) en leest het
# uit ${SKWD_CONFIG:-~/.config/skwd-wall}/config.json — hetzelfde pad als Config.qml.
# Best-effort: faalt dit, dan opent de picker gewoon op zijn vorige scherm.
_sync_skwd_monitor() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq      >/dev/null 2>&1 || return 0

    local cfg monitor current tmp
    cfg="${SKWD_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall}/config.json"
    [[ -f "$cfg" ]] || return 0

    # Eerste niet-lege regel = gefocuste monitor, met alle monitors als fallback.
    monitor="$(hyprctl monitors -j 2>/dev/null | jq -r '
        (.[] | select(.focused == true) | .name),
        (.[] | .name)
    ' | awk 'NF { print; exit }')"
    [[ -n "$monitor" ]] || return 0

    current="$(jq -r '.monitor // ""' "$cfg" 2>/dev/null || echo "")"
    [[ "$current" == "$monitor" ]] && return 0

    tmp="$(mktemp)" || return 0
    if jq --arg monitor "$monitor" '.monitor = $monitor' "$cfg" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$cfg"
    else
        rm -f "$tmp"
    fi
}

if command -v skwd >/dev/null 2>&1; then
    systemctl --user start skwd-daemon.service >/dev/null 2>&1 || true
    _sync_skwd_monitor
    if skwd wall toggle >/dev/null 2>&1; then
        exit 0
    fi
fi

if command -v kingstra-wallpaper >/dev/null 2>&1; then
    kingstra-wallpaper pick
    exit $?
fi

notify-send "Wallpaper" "Geen wallpaper-picker gevonden (skwd of kingstra-wallpaper)" 2>/dev/null || true
exit 1
