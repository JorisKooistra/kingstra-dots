#!/usr/bin/env bash
set -u

scripts_dir="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts"
lock_cmd="bash $scripts_dir/lock.sh"
tablet_cmd="$scripts_dir/tablet-mode.sh"

hyprctl_ready() {
    command -v hyprctl >/dev/null 2>&1 || return 1
    hyprctl devices >/dev/null 2>&1
}

wait_for_hyprctl() {
    local i
    for i in {1..30}; do
        hyprctl_ready && return 0
        sleep 0.2
    done
    return 1
}

switch_names_from_json() {
    command -v jq >/dev/null 2>&1 || return 1
    hyprctl devices -j 2>/dev/null | jq -r '.switches[]?.name // empty' 2>/dev/null
}

switch_names_from_text() {
    hyprctl devices 2>/dev/null | awk '
        /^Switches:/ {
            in_switches=1
            next
        }
        /^[A-Z][A-Za-z ]*:/ {
            if (in_switches) {
                exit
            }
        }
        in_switches && /^[[:space:]]+[A-Za-z0-9_.: -]+:/ {
            name=$0
            sub(/^[[:space:]]+/, "", name)
            sub(/:.*$/, "", name)
            print name
        }
    '
}

switch_names() {
    {
        switch_names_from_json || true
        switch_names_from_text || true
    } | awk 'NF && !seen[$0]++'
}

bind_switch() {
    local state="$1"
    local name="$2"
    local cmd="$3"

    [[ -n "$name" ]] || return 0
    hyprctl keyword bindl ", switch:$state:$name, exec, $cmd" >/dev/null 2>&1 || true
}

bind_known_fallbacks() {
    bind_switch on  "Lid Switch" "$lock_cmd"
    bind_switch on  "lid switch" "$lock_cmd"
    bind_switch on  "lid-switch" "$lock_cmd"

    bind_switch on  "Tablet Mode Switch" "$tablet_cmd on"
    bind_switch off "Tablet Mode Switch" "$tablet_cmd off"
    bind_switch on  "Tablet Mode" "$tablet_cmd on"
    bind_switch off "Tablet Mode" "$tablet_cmd off"
    bind_switch on  "tablet mode switch" "$tablet_cmd on"
    bind_switch off "tablet mode switch" "$tablet_cmd off"
    bind_switch on  "tablet-mode-switch" "$tablet_cmd on"
    bind_switch off "tablet-mode-switch" "$tablet_cmd off"
    bind_switch on  "Intel HID switches" "$tablet_cmd toggle"
    bind_switch off "Intel HID switches" "$tablet_cmd off"
}

main() {
    wait_for_hyprctl || exit 0

    bind_known_fallbacks

    switch_names |
    while IFS= read -r name; do
        case "$name" in
            *[Ll]id*)
                bind_switch on "$name" "$lock_cmd"
                ;;
            *[Ii]ntel\ HID\ switches*)
                bind_switch on "$name" "$tablet_cmd toggle"
                bind_switch off "$name" "$tablet_cmd off"
                ;;
            *[Tt]ablet*|*[Cc]onvertible*|*[Ff]old*)
                bind_switch on "$name" "$tablet_cmd on"
                bind_switch off "$name" "$tablet_cmd off"
                ;;
        esac
    done
}

main "$@"
