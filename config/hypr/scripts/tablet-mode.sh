#!/usr/bin/env bash
set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}/kingstra"
state_file="$runtime_dir/tablet-mode"
lock_file="$runtime_dir/tablet-mode.lock"

tablet_transform="${KINGSTRA_TABLET_TRANSFORM:-2}"
normal_transform="${KINGSTRA_TABLET_NORMAL_TRANSFORM:-0}"

mkdir -p "$runtime_dir"

exec 9>"$lock_file"
flock -w 3 9 || exit 0

usage() {
    cat <<'EOF'
Usage: tablet-mode.sh on|off|toggle

Environment overrides:
  KINGSTRA_TABLET_MONITOR       Monitor to rotate, for example eDP-1.
  KINGSTRA_TABLET_TRANSFORM     Tablet transform. Default: 2 (180 degrees).
  KINGSTRA_TABLET_KEYBOARD_CMD  On-screen keyboard command.
  KINGSTRA_TABLET_KEYBOARD_HEIGHT
                                wvkbd landscape height. Default: 260.
EOF
}

resolve_monitor() {
    if [[ -n "${KINGSTRA_TABLET_MONITOR:-}" ]]; then
        printf '%s\n' "$KINGSTRA_TABLET_MONITOR"
        return 0
    fi

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local monitor
        monitor="$(
            hyprctl monitors -j 2>/dev/null | jq -r '
                ([.[] | select(.name | test("^(eDP|LVDS|DSI)")) | .name][0]
                 // .[0].name
                 // empty)
            ' 2>/dev/null || true
        )"
        if [[ -n "$monitor" && "$monitor" != "null" ]]; then
            printf '%s\n' "$monitor"
            return 0
        fi
    fi

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl monitors all 2>/dev/null | awk '
            /^Monitor / {
                name=$2
                sub(/\(.*/, "", name)
                if (name ~ /^(eDP|LVDS|DSI)/) {
                    print name
                    found=1
                    exit
                }
                if (first == "") {
                    first=name
                }
            }
            END {
                if (!found && first != "") {
                    print first
                }
            }
        '
    fi
}

monitor_rule() {
    local monitor="$1"
    local transform="$2"

    if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        local rule
        rule="$(
            hyprctl monitors -j 2>/dev/null | jq -r \
                --arg monitor "$monitor" \
                --arg transform "$transform" '
                .[]
                | select(.name == $monitor)
                | "\(.name), preferred, \(.x)x\(.y), \(.scale), transform, \($transform)"
            ' 2>/dev/null | head -n 1 || true
        )"
        if [[ -n "$rule" && "$rule" != "null" ]]; then
            printf '%s\n' "$rule"
            return 0
        fi
    fi

    printf '%s, preferred, auto, auto, transform, %s\n' "$monitor" "$transform"
}

apply_monitor_transform() {
    local monitor="$1"
    local transform="$2"
    local rule

    if [[ -z "$monitor" ]] || ! command -v hyprctl >/dev/null 2>&1; then
        return 0
    fi

    rule="$(monitor_rule "$monitor" "$transform")"
    hyprctl keyword monitor "$rule" >/dev/null 2>&1 || true
}

apply_touch_transform() {
    local monitor="$1"
    local transform="$2"

    if ! command -v hyprctl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        return 0
    fi

    hyprctl devices -j 2>/dev/null | jq -r '.touch[]?.name // empty' 2>/dev/null |
    while IFS= read -r device; do
        [[ -n "$device" ]] || continue
        hyprctl keyword "device[$device]:transform" "$transform" >/dev/null 2>&1 || true
        if [[ -n "$monitor" ]]; then
            hyprctl keyword "device[$device]:output" "$monitor" >/dev/null 2>&1 || true
        fi
    done
}

keyboard_command() {
    if [[ -n "${KINGSTRA_TABLET_KEYBOARD_CMD:-}" ]]; then
        printf '%s\n' "$KINGSTRA_TABLET_KEYBOARD_CMD"
        return 0
    fi

    local height="${KINGSTRA_TABLET_KEYBOARD_HEIGHT:-260}"
    if command -v wvkbd-mobintl >/dev/null 2>&1; then
        printf 'wvkbd-mobintl -L %s -H %s\n' "$height" "$height"
        return 0
    fi
    if command -v wvkbd >/dev/null 2>&1; then
        printf 'wvkbd -L %s -H %s\n' "$height" "$height"
        return 0
    fi

    local candidate
    for candidate in squeekboard maliit-keyboard; do
        if command -v "$candidate" >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

start_keyboard() {
    local cmd
    cmd="$(keyboard_command || true)"
    [[ -n "$cmd" ]] || return 0

    case "$cmd" in
        *wvkbd-mobintl*|*wvkbd*|*squeekboard*|*maliit-keyboard*)
            if pgrep -f "$cmd" >/dev/null 2>&1; then
                return 0
            fi
            ;;
    esac

    setsid sh -c "$cmd" 9>&- >/dev/null 2>&1 &
}

stop_keyboard() {
    pkill -x wvkbd-mobintl >/dev/null 2>&1 || true
    pkill -x wvkbd >/dev/null 2>&1 || true
    pkill -x squeekboard >/dev/null 2>&1 || true
    pkill -x maliit-keyboard >/dev/null 2>&1 || true
}

tablet_on() {
    local monitor
    monitor="$(resolve_monitor || true)"
    apply_monitor_transform "$monitor" "$tablet_transform"
    apply_touch_transform "$monitor" "$tablet_transform"
    start_keyboard
    printf 'on\n' > "$state_file"
}

tablet_off() {
    local monitor
    monitor="$(resolve_monitor || true)"
    apply_monitor_transform "$monitor" "$normal_transform"
    apply_touch_transform "$monitor" "$normal_transform"
    stop_keyboard
    rm -f "$state_file"
}

mode="${1:-toggle}"
case "$mode" in
    on)
        tablet_on
        ;;
    off)
        tablet_off
        ;;
    toggle)
        if [[ -f "$state_file" ]]; then
            tablet_off
        else
            tablet_on
        fi
        ;;
    --help|-h)
        usage
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
