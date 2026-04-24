#!/usr/bin/env bash
set -euo pipefail

monitor="${1:-}"
direction="${2:-}"
workspace_count="${3:-8}"

if [[ -z "$direction" || "$direction" != "next" && "$direction" != "prev" ]]; then
    printf 'Usage: %s <monitor> <next|prev> [workspace-count]\n' "$0" >&2
    exit 1
fi

if ! [[ "$workspace_count" =~ ^[0-9]+$ ]] || (( workspace_count < 1 )); then
    workspace_count=8
fi

monitors_json="$(hyprctl monitors -j 2>/dev/null || printf '[]')"

monitor_line="$(
    jq -r --arg monitor "$monitor" '
        if $monitor != "" then
            (.[] | select(.name == $monitor) | [.name, .activeWorkspace.id] | @tsv)
        else
            empty
        end
    ' <<< "$monitors_json" | head -n 1
)"

if [[ -z "$monitor_line" ]]; then
    monitor_line="$(
        jq -r '.[] | select(.focused == true) | [.name, .activeWorkspace.id] | @tsv' \
            <<< "$monitors_json" | head -n 1
    )"
fi

[[ -n "$monitor_line" ]] || exit 0

IFS=$'\t' read -r monitor_name current_ws <<< "$monitor_line"
[[ -n "$monitor_name" ]] || exit 0
if ! [[ "$current_ws" =~ ^-?[0-9]+$ ]] || (( current_ws < 1 )); then
    current_ws=1
fi

mapfile -t blocked_workspaces < <(
    jq -r --arg monitor "$monitor_name" '
        .[]
        | select(.name != $monitor)
        | .activeWorkspace.id
        | select(type == "number")
    ' <<< "$monitors_json"
)

is_blocked_workspace() {
    local ws="$1"
    local blocked
    for blocked in "${blocked_workspaces[@]}"; do
        [[ "$blocked" == "$ws" ]] && return 0
    done
    return 1
}

step=1
[[ "$direction" == "prev" ]] && step=-1

target_ws="$current_ws"
for (( i = 0; i < workspace_count; i++ )); do
    target_ws=$((target_ws + step))
    while (( target_ws < 1 )); do target_ws=$((target_ws + workspace_count)); done
    while (( target_ws > workspace_count )); do target_ws=$((target_ws - workspace_count)); done

    if ! is_blocked_workspace "$target_ws"; then
        break
    fi
done

[[ "$target_ws" != "$current_ws" ]] || exit 0

printf 'close' > /tmp/qs_widget_state 2>/dev/null || true

qs_addr="$(hyprctl clients -j 2>/dev/null | jq -r '.[] | select(.title == "qs-master") | .address' | head -n 1)"
hide_qs_cmd=""
if [[ -n "$qs_addr" && "$qs_addr" != "null" ]]; then
    hide_qs_cmd="dispatch movetoworkspacesilent special:qs-hidden,address:$qs_addr ; dispatch setfloating address:$qs_addr ; "
fi

hyprctl --batch "${hide_qs_cmd}keyword cursor:no_warps true ; dispatch focusmonitor $monitor_name ; dispatch workspace $target_ws ; keyword cursor:no_warps false" >/dev/null 2>&1
