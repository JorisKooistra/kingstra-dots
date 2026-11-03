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

# De echte submap, niet wat deze guard denkt: na een herstart van de guard of
# een Super+Escape liep guard_active uit de pas en bleef passthrough hangen,
# zodat Super+Q en alle andere Super-toetsen niets meer deden (3 nov).
in_passthrough() {
    [[ "$(hyprctl submap 2>/dev/null | tr -d '[:space:]')" == passthrough ]]
}

reset_submap() {
    "$HOME/.config/hypr/scripts/hypr-dispatch.sh" submap reset >/dev/null 2>&1
}

handle_focus() {
    local class="${1,,}"

    if [[ "$class" =~ $CLASS_PATTERN ]]; then
        if ! $guard_active; then
            "$HOME/.config/hypr/scripts/hypr-dispatch.sh" submap passthrough >/dev/null 2>&1
            guard_active=true
        fi
    elif $guard_active || in_passthrough; then
        # Ook een handmatige passthrough vervalt zodra een gewoon venster
        # focus krijgt; anders kan hij ongemerkt blijven hangen.
        reset_submap
        guard_active=false
    fi
}

# Bij het starten: hangt passthrough nog van een vorige sessie of guard en
# heeft geen Citrix-venster focus, dan terug naar de gewone binds.
start_class="$(hyprctl activewindow -j 2>/dev/null | sed -n 's/.*"class": *"\([^"]*\)".*/\1/p' | head -n 1)"
if in_passthrough; then
    if [[ "${start_class,,}" =~ $CLASS_PATTERN ]]; then
        guard_active=true
    else
        reset_submap
    fi
fi

# activewindow>>CLASS,TITLE — alleen de class is hier relevant
socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r line; do
    case "$line" in
        activewindow\>\>*)
            data="${line#activewindow>>}"
            handle_focus "${data%%,*}"
            ;;
    esac
done
