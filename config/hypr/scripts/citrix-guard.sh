#!/usr/bin/env bash
# =============================================================================
# citrix-guard.sh — Automatische bind-passthrough voor Citrix-vensters
# =============================================================================
# Luistert op Hyprland socket2 naar focus-wijzigingen. Zodra een Citrix-venster
# (wfica / Citrix Workspace) focus krijgt, schakelt Hyprland naar de lege
# 'passthrough' submap (zie 86-binds-passthrough.conf): Super-shortcuts worden
# dan niet meer door de compositor afgevangen, wat de bekende wfica-crash op
# de Super-toets voorkomt. Verliest het venster focus, dan komen alle binds
# automatisch terug.
#
# Handmatige escape blijft altijd werken: Super + Escape (bind in de submap).
# =============================================================================
set -u

CLASS_PATTERN='wfica|citrix'

command -v socat >/dev/null 2>&1 || exit 0
command -v hyprctl >/dev/null 2>&1 || exit 0

sock="${XDG_RUNTIME_DIR:-/run/user/$UID}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"
[[ -S "$sock" ]] || exit 0

guard_active=false

handle_focus() {
    local class="${1,,}"

    if [[ "$class" =~ $CLASS_PATTERN ]]; then
        if ! $guard_active; then
            hyprctl dispatch submap passthrough >/dev/null 2>&1
            guard_active=true
        fi
    elif $guard_active; then
        hyprctl dispatch submap reset >/dev/null 2>&1
        guard_active=false
    fi
}

# activewindow>>CLASS,TITLE — alleen de class is hier relevant
socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        activewindow\>\>*)
            data="${line#activewindow>>}"
            handle_focus "${data%%,*}"
            ;;
    esac
done
