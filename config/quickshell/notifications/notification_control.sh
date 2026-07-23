#!/usr/bin/env bash
set -uo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
COMMAND_FILE="/tmp/qs_notifications_command"

send_command() {
    printf '%s:%s\n' "$1" "$RANDOM" > "$COMMAND_FILE"
}

case "${1:-toggle}" in
    toggle|open)
        "$CONFIG_HOME/hypr/scripts/qs_manager.sh" toggle notifications
        ;;
    clear)
        send_command "clear"
        ;;
    dnd|dnd-toggle)
        send_command "dnd-toggle"
        ;;
    dnd-on)
        send_command "dnd-on"
        ;;
    dnd-off)
        send_command "dnd-off"
        ;;
    *)
        printf 'Gebruik: %s [toggle|clear|dnd|dnd-on|dnd-off]\n' "$0" >&2
        exit 2
        ;;
esac
