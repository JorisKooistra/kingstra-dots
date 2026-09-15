#!/usr/bin/env bash
set -u

state_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/monitors-local.lua"
tablet_state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kingstra/tablet-mode"
log_prefix="[kingstra-monitor-hotplug]"

log() {
    printf '%s %s\n' "$log_prefix" "$*" |
        systemd-cat --identifier=kingstra-monitor-hotplug 2>/dev/null ||
        printf '%s %s\n' "$log_prefix" "$*" >&2
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

tablet_mode_active() {
    [[ -f "$tablet_state_file" ]]
}

is_internal_monitor() {
    [[ "$1" =~ ^(eDP|LVDS|DSI) ]]
}

apply_saved_layout() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    [[ -f "$state_file" ]] || return 0

    # Lua configurations are re-evaluated as a unit. This preserves monitor
    # rules that are currently disconnected and avoids the removed `keyword`
    # control path.
    if hyprctl reload >/dev/null 2>&1; then
        log "Lokale monitor-layout opnieuw geladen"
    else
        log "Lokale monitor-layout kon niet opnieuw worden geladen"
    fi
}

reload_wallpaper() {
    local -a wallpaper_cmd=()

    if command -v kingstra-wallpaper >/dev/null 2>&1; then
        wallpaper_cmd=(kingstra-wallpaper)
    elif [[ -x "$HOME/.local/bin/kingstra-wallpaper" ]]; then
        wallpaper_cmd=("$HOME/.local/bin/kingstra-wallpaper")
    elif [[ -f "$HOME/.local/bin/kingstra-wallpaper" ]]; then
        wallpaper_cmd=(bash "$HOME/.local/bin/kingstra-wallpaper")
    else
        return 0
    fi

    if command -v timeout >/dev/null 2>&1; then
        if timeout --kill-after=2 15 "${wallpaper_cmd[@]}" reload >/dev/null 2>&1; then
            log "Wallpaper herladen na monitor hotplug"
        else
            log "Wallpaper reload na monitor hotplug is niet gelukt"
        fi
    elif "${wallpaper_cmd[@]}" reload >/dev/null 2>&1; then
        log "Wallpaper herladen na monitor hotplug"
    else
        log "Wallpaper reload na monitor hotplug is niet gelukt"
    fi
}

event_socket() {
    [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || return 1
    printf '%s/hypr/%s/.socket2.sock' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "$HYPRLAND_INSTANCE_SIGNATURE"
}

main() {
    if [[ "${1:-}" == "--once" ]]; then
        apply_saved_layout
        exit 0
    fi

    command -v socat >/dev/null 2>&1 || {
        log "socat ontbreekt; monitor-hotplug herstel is niet actief"
        exit 0
    }

    local socket
    socket="$(event_socket)" || exit 0

    for _ in {1..50}; do
        [[ -S "$socket" ]] && break
        sleep 0.1
    done

    [[ -S "$socket" ]] || {
        log "Hyprland event socket niet gevonden"
        exit 0
    }

    sleep 1
    apply_saved_layout

    socat -u "UNIX-CONNECT:$socket" - 2>/dev/null |
    while IFS= read -r event; do
        case "$event" in
            monitoradded*)
                sleep 1
                apply_saved_layout
                sleep 0.5
                reload_wallpaper
                ;;
            monitorremoved*)
                sleep 1
                apply_saved_layout
                ;;
        esac
    done
}

main "$@"
