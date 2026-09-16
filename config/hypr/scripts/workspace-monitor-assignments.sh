#!/usr/bin/env bash
set -euo pipefail

state_file="${KINGSTRA_WORKSPACE_STATE_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/workspaces.lua}"
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
    [[ -f "$state_file" ]] || return 0

    awk '
        /^[[:space:]]*#/ { next }
        /hl\.workspace_rule\(/ {
            line = $0
            ws = line
            sub(/^.*workspace[[:space:]]*=[[:space:]]*"/, "", ws)
            sub(/".*$/, "", ws)
            mon = line
            sub(/^.*monitor[[:space:]]*=[[:space:]]*"/, "", mon)
            sub(/".*$/, "", mon)
            if (ws ~ /^[0-9]+$/ && mon != "") print ws "\t" mon
        }
    ' "$state_file"
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
    mkdir -p "$(dirname "$state_file")"

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
    tmp_file="$(mktemp "${state_file}.tmp.XXXXXX")"
    trap 'rm -f "$tmp_file"' EXIT

    {
        printf '%s\n' '-- ============================================================================='
        printf '%s\n' '-- workspaces.lua - Lokale workspace-monitor toewijzingen'
        printf '%s\n' '-- ============================================================================='
        printf '%s\n' '-- Gegenereerd door Settings > Display. Dit bestand is user-state en staat in .gitignore.'
        printf '%s\n' '-- Lege workspaces blijven vrij.'
        printf '%s\n\n' '-- ============================================================================='
        printf 'return {\n    apply = function()\n'
        for (( ws = 1; ws <= workspace_count; ws++ )); do
            monitor="${assignments[$ws]:-}"
            [[ -n "$monitor" ]] || continue
            monitor="${monitor//$'\r'/}"
            monitor="${monitor//$'\n'/}"
            # Monitor names come from Hyprland's own JSON and cannot contain
            # quote characters. Escape defensively nevertheless.
            monitor="${monitor//\\/\\\\}"
            monitor="${monitor//\"/\\\"}"
            printf '        hl.workspace_rule({ workspace = "%s", monitor = "%s" })\n' "$ws" "$monitor"
        done
        printf '    end,\n}\n'
    } > "$tmp_file"

    if ! luac -p "$tmp_file"; then
        notify "Display Update" "Ongeldige Lua gegenereerd; bestaande workspacetoewijzingen blijven behouden"
        exit 1
    fi

    mv "$tmp_file" "$state_file"
    trap - EXIT

    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi

    notify "Display Update" "Workspace-monitor toewijzingen opgeslagen in workspaces.lua"
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
