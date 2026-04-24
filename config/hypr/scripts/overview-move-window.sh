#!/usr/bin/env bash
set -euo pipefail

address="${1:-}"
target_workspace="${2:-}"
cursor_x="${3:-}"
cursor_y="${4:-}"
window_x="${5:-}"
window_y="${6:-}"
is_floating="${7:-false}"
target_address="${8:-}"

is_int() {
    [[ "${1:-}" =~ ^-?[0-9]+$ ]]
}

if [[ -z "$address" || -z "$target_workspace" ]]; then
    exit 0
fi

is_int "$cursor_x" || exit 0
is_int "$cursor_y" || exit 0

old_cursor="$(hyprctl cursorpos 2>/dev/null || true)"
old_x="${old_cursor%%,*}"
old_y="${old_cursor##*,}"
old_x="${old_x//[[:space:]]/}"
old_y="${old_y//[[:space:]]/}"

batch="keyword cursor:no_warps true"
batch+=" ; dispatch movecursor $cursor_x $cursor_y"
batch+=" ; dispatch movetoworkspacesilent $target_workspace,address:$address"
batch+=" ; dispatch focuswindow address:$address"

if [[ -n "$target_address" && "$target_address" != "$address" ]]; then
    batch+=" ; dispatch swapwindow address:$target_address"
fi

if [[ "$is_floating" == "true" ]] && is_int "$window_x" && is_int "$window_y"; then
    batch+=" ; dispatch movewindowpixel exact $window_x $window_y,address:$address"
fi

if is_int "$old_x" && is_int "$old_y"; then
    batch+=" ; dispatch movecursor $old_x $old_y"
fi

batch+=" ; keyword cursor:no_warps false"

hyprctl --batch "$batch" >/dev/null 2>&1 || true
