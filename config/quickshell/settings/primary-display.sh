#!/usr/bin/env bash
set -euo pipefail

# Bewaart welk scherm de volledige Kingstra-omlijsting draagt. Dit staat los
# van Hyprlands actuele focus: focus mag tussen schermen bewegen zonder dat de
# shell-vorm telkens verspringt.
state_file="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/state/primary-display.json"

monitors_json() {
    hyprctl monitors -j 2>/dev/null | jq -c '
        if type == "array" then
            map({name: (.name // ""), focused: (.focused // false)})
            | map(select(.name != ""))
        else [] end
    ' 2>/dev/null || printf '[]\n'
}

stored_primary() {
    jq -r '.primary // ""' "$state_file" 2>/dev/null || true
}

ensure_state_file() {
    [[ -f "$state_file" ]] && return 0
    mkdir -p "$(dirname "$state_file")"
    local tmp
    tmp="$(mktemp "${state_file}.tmp.XXXXXX")"
    printf '{\n  "primary": ""\n}\n' >"$tmp"
    mv "$tmp" "$state_file"
}

list_state() {
    local monitors stored effective
    ensure_state_file
    monitors="$(monitors_json)"
    stored="$(stored_primary)"
    effective="$(jq -r --arg selected "$stored" '
        if any(.[]; .name == $selected) then $selected
        else ([.[] | select(.focused) | .name][0] // .[0].name // "")
        end
    ' <<<"$monitors")"
    jq -n --arg primary "$stored" --arg effective "$effective" --argjson monitors "$monitors" \
        '{primary: $primary, effective: $effective, monitors: $monitors}'
}

set_primary() {
    local chosen="${1:-}" monitors valid
    monitors="$(monitors_json)"
    valid="$(jq -r --arg chosen "$chosen" 'any(.[]; .name == $chosen)' <<<"$monitors")"
    if [[ -n "$chosen" && "$valid" != "true" ]]; then
        printf 'Onbekende monitor: %s\n' "$chosen" >&2
        exit 2
    fi

    ensure_state_file
    local tmp
    tmp="$(mktemp "${state_file}.tmp.XXXXXX")"
    jq -n --arg primary "$chosen" '{primary: $primary}' >"$tmp"
    mv "$tmp" "$state_file"
    list_state
}

case "${1:-list}" in
    list) list_state ;;
    set) set_primary "${2:-}" ;;
    *)
        printf 'Gebruik: %s {list|set [MONITOR]}\n' "${0##*/}" >&2
        exit 2
        ;;
esac
