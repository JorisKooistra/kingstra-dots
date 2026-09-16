#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "$test_dir"' EXIT

monitor_state="$test_dir/monitors-local.lua"
workspace_state="$test_dir/workspaces.lua"

KINGSTRA_MONITOR_STATE_FILE="$monitor_state" HYPRLAND_INSTANCE_SIGNATURE= \
    "$REPO_ROOT/config/hypr/scripts/monitor-apply-save.sh" \
    'eDP-1,1920x1080@60,0x0,1.0'

KINGSTRA_WORKSPACE_STATE_FILE="$workspace_state" HYPRLAND_INSTANCE_SIGNATURE= \
    "$REPO_ROOT/config/hypr/scripts/workspace-monitor-assignments.sh" \
    save '1=eDP-1' '2=eDP-1'

luac -p "$monitor_state"
luac -p "$workspace_state"

rg -q '^-- monitors-local\.lua' "$monitor_state"
rg -q '^-- workspaces\.lua' "$workspace_state"
rg -q 'hl\.monitor' "$monitor_state"
rg -q 'hl\.workspace_rule' "$workspace_state"

printf 'Generated display Lua smoke test: OK\n'
