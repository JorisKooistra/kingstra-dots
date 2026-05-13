#!/usr/bin/env bash
set -euo pipefail

conf_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/workspaces.conf"
workspace_count=10

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$@" >/dev/null 2>&1 || true
    fi
}

usage() {
    printf 'Usage: %s {list|save} [N=MONITOR ...]\n' "${0##*/}" >&2
}

monitor_json() {
    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local raw
        raw="$(hyprctl monitors -j 2>/dev/null || true)"
        if jq -e . >/dev/null 2>&1 <<< "$raw"; then
            printf '%s\n' "$raw"
        else
            printf '[]\n'
        fi
    else
        printf '[]'
    fi
}

print_existing_assignments() {
    [[ -f "$conf_file" ]] || return 0

    awk '
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*workspace[[:space:]]*=/ {
            line = $0
            sub(/^[^=]*=[[:space:]]*/, "", line)
            split(line, parts, ",")
            ws = parts[1]
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", ws)
            mon = ""
            for (i = 2; i <= length(parts); i++) {
                field = parts[i]
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", field)
                if (field ~ /^monitor:/) {
                    sub(/^monitor:[[:space:]]*/, "", field)
                    mon = field
                }
            }
            if (ws ~ /^[0-9]+$/ && mon != "") print ws "\t" mon
        }
    ' "$conf_file"
}

list_assignments() {
    local monitors assignments
    monitors="$(monitor_json)"
    assignments="$(print_existing_assignments || true)"

    jq -n \
        --argjson monitors "$monitors" \
        --arg assignments "$assignments" \
        --argjson count "$workspace_count" '
        def lines_or_empty: if . == "" then [] else split("\n") end;
        ($assignments | lines_or_empty | map(split("\t")) | map(select(length >= 2))) as $pairs
        | ($pairs | reduce .[] as $pair ({}; .[$pair[0]] = $pair[1])) as $assignmentMap
        | {
            monitors: ($monitors | map(.name) | map(select(. != null and . != ""))),
            workspaces: [
                range(1; $count + 1) as $ws
                | { id: $ws, monitor: ($assignmentMap[($ws | tostring)] // "") }
            ]
        }
    '
}

save_assignments() {
    shift
    mkdir -p "$(dirname "$conf_file")"

    declare -A assignments=()
    local arg ws monitor
    for arg in "$@"; do
        ws="${arg%%=*}"
        monitor="${arg#*=}"
        [[ "$ws" =~ ^[0-9]+$ ]] || continue
        (( ws >= 1 && ws <= workspace_count )) || continue
        assignments["$ws"]="$monitor"
    done

    local tmp_file
    tmp_file="$(mktemp "${conf_file}.tmp.XXXXXX")"
    trap 'rm -f "$tmp_file"' EXIT

    {
        printf '# =============================================================================\n'
        printf '# workspaces.conf - Lokale workspace-monitor toewijzingen\n'
        printf '# =============================================================================\n'
        printf '# Gegenereerd door Settings > Display. Dit bestand is user-state en staat in .gitignore.\n'
        printf '# Lege workspaces blijven vrij.\n'
        printf '# =============================================================================\n\n'
        for (( ws = 1; ws <= workspace_count; ws++ )); do
            monitor="${assignments[$ws]:-}"
            [[ -n "$monitor" ]] || continue
            monitor="${monitor//$'\r'/}"
            monitor="${monitor//$'\n'/}"
            printf 'workspace = %s, monitor:%s\n' "$ws" "$monitor"
        done
    } >> "$tmp_file"

    mv "$tmp_file" "$conf_file"
    trap - EXIT

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi

    notify "Display Update" "Workspace-monitor toewijzingen opgeslagen in workspaces.conf"
}

case "${1:-}" in
    list)
        list_assignments
        ;;
    save)
        save_assignments "$@"
        ;;
    *)
        usage
        exit 2
        ;;
esac
