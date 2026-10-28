#!/usr/bin/env bash
# Native window atlas backend. Keep addresses and workspace IDs as argv data;
# no window title is ever interpolated into a shell command.
set -euo pipefail

case "${1:-list}" in
    list)
        hyprctl -j clients 2>/dev/null | jq '[
            .[]
            | select((.mapped // true) == true and (.hidden // false) == false)
            | (.workspace.name == "special:geparkeerd") as $parked
            | select((.workspace.id // -1) > 0 or $parked)
            | {
                address: (.address // ""),
                title: (.title // "Zonder titel"),
                className: (.class // .initialClass // "App"),
                workspace: (if $parked then "geparkeerd" else (.workspace.id // 0) end),
                parked: $parked,
                focused: ((.focusHistoryID // 1) == 0),
                focusOrder: (.focusHistoryID // 999999)
            }
        ] | sort_by(.parked, .focusOrder)'
        ;;
    park)
        address="${2:-}"
        [[ "$address" =~ ^0x[[:xdigit:]]+$ ]] || exit 2
        python3 "$HOME/.config/hypr/scripts/park-window.py" park "$address"
        ;;
    focus)
        address="${2:-}"
        workspace="${3:-}"
        [[ "$address" =~ ^0x[[:xdigit:]]+$ ]] || exit 2
        # Geparkeerde vensters komen terug op hun eigen werkruimte.
        if [[ "$workspace" == "geparkeerd" ]]; then
            exec python3 "$HOME/.config/hypr/scripts/park-window.py" restore "$address"
        fi
        [[ "$workspace" =~ ^[1-9][0-9]*$ ]] || exit 2
        "$HOME/.config/hypr/scripts/hypr-dispatch.sh" workspace "$workspace" >/dev/null
        "$HOME/.config/hypr/scripts/hypr-dispatch.sh" focuswindow "address:$address" >/dev/null
        ;;
    *)
        printf 'Gebruik: %s {list|focus ADDRESS WORKSPACE|park ADDRESS}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
