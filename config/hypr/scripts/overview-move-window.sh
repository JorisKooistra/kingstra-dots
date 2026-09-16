#!/usr/bin/env bash
set -euo pipefail

address="${1:-}"
target_workspace="${2:-}"
cursor_x="${3:-}"
cursor_y="${4:-}"
window_x="${5:-}"
window_y="${6:-}"
is_floating="${7:-false}"
source_workspace="${8:-}"
target_address="${9:-}"
drop_side="${10:-}"
dispatch_cmd="$(dirname "${BASH_SOURCE[0]}")/hypr-dispatch.sh"

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

"$dispatch_cmd" movecursor "$cursor_x" "$cursor_y" >/dev/null
"$dispatch_cmd" movetoworkspacesilent special:overview-drop "address:$address" >/dev/null
"$dispatch_cmd" workspace "$target_workspace" >/dev/null
"$dispatch_cmd" movecursor "$cursor_x" "$cursor_y" >/dev/null

case "$drop_side" in
    left|right|top|bottom)
        if [[ -n "$target_address" && "$target_address" != "$address" ]]; then
            case "$drop_side" in
                left) preselect_dir="l" ;;
                right) preselect_dir="r" ;;
                top) preselect_dir="u" ;;
                bottom) preselect_dir="d" ;;
            esac
            "$dispatch_cmd" focuswindow "address:$target_address" >/dev/null
            "$dispatch_cmd" layoutmsg preselect "$preselect_dir" >/dev/null
        fi
        ;;
esac

"$dispatch_cmd" movetoworkspace "$target_workspace" "address:$address" >/dev/null
"$dispatch_cmd" focuswindow "address:$address" >/dev/null

if [[ "$is_floating" == "true" ]] && is_int "$window_x" && is_int "$window_y"; then
    "$dispatch_cmd" movewindowpixel "$window_x" "$window_y" "address:$address" >/dev/null
fi

if is_int "$old_x" && is_int "$old_y"; then
    "$dispatch_cmd" movecursor "$old_x" "$old_y" >/dev/null
fi
