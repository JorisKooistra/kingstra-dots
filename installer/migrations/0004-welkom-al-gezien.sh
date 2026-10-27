#!/usr/bin/env bash
# Het welkomstscherm is voor verse installaties. Op een bestaande
# installatie markeren we het als gezien (kingstra welcome toont het alsnog).

migration_run() {
    local state="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra"
    mkdir -p "$state" || return 1
    [[ -f "$state/welcome-shown" ]] || date '+%Y-%m-%d %H:%M:%S' > "$state/welcome-shown"
}
