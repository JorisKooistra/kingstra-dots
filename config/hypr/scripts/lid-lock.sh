#!/usr/bin/env bash
set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="$runtime_dir/kingstra-lid-lock.lock"
lock_script="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/scripts/lock.sh"

exec 9>"$lock_file"
flock -n 9 || exit 0

lock_screen() {
    if command -v loginctl >/dev/null 2>&1; then
        loginctl lock-session >/dev/null 2>&1 || true
        sleep 0.2
    fi

    if [[ -x "$lock_script" ]]; then
        "$lock_script" >/dev/null 2>&1 &
        return
    fi
}

lid_state() {
    local state_file
    for state_file in /proc/acpi/button/lid/*/state; do
        [[ -r "$state_file" ]] || continue
        if grep -qi "closed" "$state_file" 2>/dev/null; then
            printf 'closed\n'
            return 0
        fi
    done
    printf 'open\n'
}

poll_lid_state() {
    local last_state="open"
    local current_state

    while true; do
        current_state="$(lid_state)"
        if [[ "$current_state" == "closed" && "$last_state" != "closed" ]]; then
            lock_screen
        fi
        last_state="$current_state"
        sleep 1
    done
}

poll_lid_state &
poll_pid=$!
trap 'kill "$poll_pid" 2>/dev/null || true' EXIT

if ! command -v dbus-monitor >/dev/null 2>&1; then
    wait "$poll_pid"
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
