#!/usr/bin/env bash
set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="$runtime_dir/kingstra-lid-lock.lock"
lock_script="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/lock.sh"

exec 9>"$lock_file"
flock -n 9 || exit 0

lock_screen() {
    if [[ -x "$lock_script" ]]; then
        "$lock_script" >/dev/null 2>&1 &
        return
    fi

    if command -v loginctl >/dev/null 2>&1; then
        loginctl lock-session >/dev/null 2>&1 || true
    fi
}

if ! command -v dbus-monitor >/dev/null 2>&1; then
    exit 0
fi

while true; do
    dbus-monitor --system \
        "type='signal',path='/org/freedesktop/login1',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'" 2>/dev/null |
    while IFS= read -r line; do
        case "$line" in
            *'string "LidClosed"'*)
                saw_lid_closed=true
                ;;
            *'boolean true'*)
                if [[ "${saw_lid_closed:-false}" == "true" ]]; then
                    saw_lid_closed=false
                    lock_screen
                fi
                ;;
            *'boolean false'*)
                if [[ "${saw_lid_closed:-false}" == "true" ]]; then
                    saw_lid_closed=false
                fi
                ;;
        esac
    done
    sleep 2
done
