#!/usr/bin/env bash
set -u

RAW_DIR="${1:-}"
case "$RAW_DIR" in
    l|left)  DIR_SHORT="l"; DIR_LONG="left"  ;;
    r|right) DIR_SHORT="r"; DIR_LONG="right" ;;
    u|up)    DIR_SHORT="u"; DIR_LONG="up"    ;;
    d|down)  DIR_SHORT="d"; DIR_LONG="down"  ;;
    *)
        exit 1
        ;;
esac

# Fast path when JSON helpers are not available.
if ! command -v jq >/dev/null 2>&1; then
    hyprctl dispatch movefocus "$DIR_SHORT" >/dev/null 2>&1 || true
    hyprctl dispatch focusmonitor "$DIR_SHORT" >/dev/null 2>&1 || \
        hyprctl dispatch focusmonitor "$DIR_LONG" >/dev/null 2>&1 || true
    exit 0
fi

OLD_ADDR="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // ""')"
OLD_MON="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)"

hyprctl dispatch movefocus "$DIR_SHORT" >/dev/null 2>&1 || true

NEW_ADDR="$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // ""')"
if [[ -n "$OLD_ADDR" && -n "$NEW_ADDR" && "$NEW_ADDR" != "$OLD_ADDR" ]]; then
    exit 0
fi

hyprctl dispatch focusmonitor "$DIR_SHORT" >/dev/null 2>&1 || \
    hyprctl dispatch focusmonitor "$DIR_LONG" >/dev/null 2>&1 || true

NEW_MON="$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused==true) | .name' | head -n1)"

if [[ -z "$OLD_MON" || -z "$NEW_MON" || "$OLD_MON" == "$NEW_MON" ]]; then
    exit 0
fi

WS_ID="$(hyprctl monitors -j 2>/dev/null | jq -r --arg mon "$NEW_MON" '.[] | select(.name == $mon) | .activeWorkspace.id // ""' | head -n1)"
if [[ ! "$WS_ID" =~ ^-?[0-9]+$ ]]; then
    exit 0
fi

TARGET_ADDR="$(hyprctl clients -j 2>/dev/null | jq -r --argjson ws "$WS_ID" '.[] | select((.workspace.id == $ws) and (.hidden != true)) | .address' | head -n1)"
if [[ -n "$TARGET_ADDR" && "$TARGET_ADDR" != "null" ]]; then
    hyprctl dispatch focuswindow "address:$TARGET_ADDR" >/dev/null 2>&1 || true
fi

exit 0
