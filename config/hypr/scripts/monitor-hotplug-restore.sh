#!/usr/bin/env bash
set -u

conf_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf.d/10-monitors.conf"
begin_marker="# BEGIN KINGSTRA MONITOR UI"
end_marker="# END KINGSTRA MONITOR UI"
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

saved_rules() {
    [[ -f "$conf_file" ]] || return 0

    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { in_block = 1; next }
        $0 == end { in_block = 0; next }
        in_block && /^[[:space:]]*monitor[[:space:]]*=/ {
            sub(/^[^=]*=[[:space:]]*/, "")
            sub(/[[:space:]]*#.*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if ($0 != "") print
        }
    ' "$conf_file"
}

connected_monitors() {
    hyprctl monitors -j 2>/dev/null |
        jq -r '.[].name // empty' 2>/dev/null
}

is_connected() {
    local needle="$1"
    local monitor

    for monitor in "${connected[@]}"; do
        [[ "$monitor" == "$needle" ]] && return 0
    done

    return 1
}

apply_saved_layout() {
    command -v hyprctl >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    local -a rules=()
    local -a connected=()
    mapfile -t rules < <(saved_rules)
    mapfile -t connected < <(connected_monitors)

    [[ "${#rules[@]}" -gt 0 && "${#connected[@]}" -gt 0 ]] || return 0

    local rule output
    for rule in "${rules[@]}"; do
        output="$(trim "${rule%%,*}")"
        [[ -n "$output" ]] || continue

        if is_connected "$output"; then
            if hyprctl keyword monitor "$rule" >/dev/null 2>&1; then
                log "Toegepast: $rule"
            else
                log "Kon monitorregel niet toepassen: $rule"
            fi
        fi
    done
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
