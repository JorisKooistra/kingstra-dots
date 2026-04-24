#!/usr/bin/env bash
set -euo pipefail

touch_detect_script="${HOME}/.config/shared/scripts/kingstra-touch-detect"
tablet_state_file="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kingstra/tablet-mode"

have_monitors_json() {
    command -v hyprctl >/dev/null 2>&1 &&
    command -v jq >/dev/null 2>&1
}

print_summary() {
    if ! have_monitors_json; then
        printf 'hyprctl of jq niet beschikbaar\n'
        return 0
    fi

    hyprctl monitors -j 2>/dev/null | jq -r '
        if length == 0 then
            "Geen monitoren gevonden"
        else
            ([ "Monitoren: " + (length | tostring) ]
             + ([ .[] | select(.focused == true) | "Focus: " + .name ] | .[0:1])) | join("  •  ")
        end
    ' 2>/dev/null || printf 'Monitorstatus niet beschikbaar\n'
}

print_layout() {
    if ! have_monitors_json; then
        printf 'Layoutdetails niet beschikbaar\n'
        return 0
    fi

    hyprctl monitors -j 2>/dev/null | jq -r '
        if length == 0 then
            "Geen monitoren gevonden"
        else
            map(
                (if .focused then "● " else "○ " end)
                + .name
                + "  "
                + ((.width // 0) | tostring)
                + "x"
                + ((.height // 0) | tostring)
                + " @ "
                + (((.refreshRate // 0) | round) | tostring)
                + "Hz  scale "
                + ((.scale // 1) | tostring)
                + "  pos "
                + ((.x // 0) | tostring)
                + "x"
                + ((.y // 0) | tostring)
                + (if (.transform // 0) != 0 then
                      "  rotatie " + ((.transform // 0) | tostring)
                   else
                      ""
                   end)
            ) | join("\n")
        end
    ' 2>/dev/null || printf 'Display-layout niet beschikbaar\n'
}

print_touch() {
    local tablet_mode="uit"
    [[ -f "$tablet_state_file" ]] && tablet_mode="aan"

    if [[ -x "$touch_detect_script" ]] && command -v jq >/dev/null 2>&1; then
        "$touch_detect_script" --json 2>/dev/null | jq -r --arg tablet "$tablet_mode" '
            if .is_touchscreen then
                "Touchscreen: " + ((.touchscreen_count // 0) | tostring)
                + "  •  bron " + (.source // "onbekend")
                + "  •  tabletmodus " + $tablet
            else
                "Geen touchscreen  •  tabletmodus " + $tablet
            end
        ' 2>/dev/null && return 0
    fi

    printf 'Touch-profiel niet beschikbaar  •  tabletmodus %s\n' "$tablet_mode"
}

print_brightness() {
    if ! command -v brightnessctl >/dev/null 2>&1; then
        printf 'brightnessctl niet beschikbaar\n'
        return 0
    fi

    brightnessctl -m 2>/dev/null | awk -F, 'NR == 1 { print "Helderheid: " $4 }'
}

case "${1:-summary}" in
    summary)
        print_summary
        ;;
    layout)
        print_layout
        ;;
    touch)
        print_touch
        ;;
    brightness)
        print_brightness
        ;;
    *)
        printf 'Gebruik: %s {summary|layout|touch|brightness}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
