#!/usr/bin/env bash
# Compatibility entrypoint for imperative dispatches while Hyprland uses the
# Lua config provider. The old `hyprctl dispatch <name> <arg>` syntax is parsed
# as Lua and fails; this helper translates the small legacy surface Kingstra
# uses to typed hl.dsp dispatchers.
set -euo pipefail

dispatcher="${1:-}"
shift || true

lua_quote() {
    local value="${1:-}"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '"%s"' "$value"
}

direction_long() {
    case "${1:-}" in
        l|left)  printf 'left' ;;
        r|right) printf 'right' ;;
        u|up)    printf 'up' ;;
        d|down)  printf 'down' ;;
        *)       printf '%s' "${1:-}" ;;
    esac
}

window_field() {
    [[ -n "${1:-}" ]] || return 0
    printf ', window = %s' "$(lua_quote "$1")"
}

expression=""
case "$dispatcher" in
    workspace)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.focus({ workspace = $(lua_quote "$1") })"
        ;;
    movetoworkspace|movetoworkspacesilent)
        [[ $# -ge 1 ]] || exit 2
        follow=true
        [[ "$dispatcher" == "movetoworkspacesilent" ]] && follow=false
        expression="hl.dsp.window.move({ workspace = $(lua_quote "$1"), follow = $follow$(window_field "${2:-}") })"
        ;;
    movefocus)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.focus({ direction = $(lua_quote "$(direction_long "$1")") })"
        ;;
    focusmonitor)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.focus({ monitor = $(lua_quote "$(direction_long "$1")") })"
        ;;
    focuswindow)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.focus({ window = $(lua_quote "$1") })"
        ;;
    togglefloating|setfloating)
        action=toggle
        [[ "$dispatcher" == "setfloating" ]] && action=set
        expression="hl.dsp.window.float({ action = $(lua_quote "$action")$(window_field "${1:-}") })"
        ;;
    dpms)
        action="${1:-toggle}"
        case "$action" in
            on|enable) action=enable ;;
            off|disable) action=disable ;;
            toggle) ;;
            *) exit 2 ;;
        esac
        expression="hl.dsp.dpms({ action = $(lua_quote "$action")"
        [[ -n "${2:-}" ]] && expression+=", monitor = $(lua_quote "$2")"
        expression+=" })"
        ;;
    submap)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.submap($(lua_quote "$1"))"
        ;;
    togglespecialworkspace)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.workspace.toggle_special($(lua_quote "$1"))"
        ;;
    movecursor)
        [[ "${1:-}" =~ ^-?[0-9]+$ && "${2:-}" =~ ^-?[0-9]+$ ]] || exit 2
        expression="hl.dsp.cursor.move({ x = $1, y = $2 })"
        ;;
    movewindowpixel)
        [[ "${1:-}" =~ ^-?[0-9]+$ && "${2:-}" =~ ^-?[0-9]+$ ]] || exit 2
        expression="hl.dsp.window.move({ x = $1, y = $2, relative = false$(window_field "${3:-}") })"
        ;;
    layoutmsg)
        [[ $# -ge 1 ]] || exit 2
        expression="hl.dsp.layout($(lua_quote "$*"))"
        ;;
    exit)
        expression="hl.dsp.exit()"
        ;;
    *)
        printf 'Niet-ondersteunde Hyprland-dispatcher: %s\n' "$dispatcher" >&2
        exit 2
        ;;
esac

if [[ "${HYPR_DISPATCH_PRINT_ONLY:-false}" == "true" ]]; then
    printf '%s\n' "$expression"
    exit 0
fi

exec "${HYPRCTL_BIN:-hyprctl}" dispatch "$expression"
