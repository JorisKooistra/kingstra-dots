#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/monitors-local.lua"

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$@" >/dev/null 2>&1 || true
    fi
}

usage() {
    printf 'Usage: %s "OUTPUT,MODE,POSITION,SCALE" [...]\n' "${0##*/}" >&2
}

if [[ "$#" -lt 1 ]]; then
    usage
    exit 2
fi

mkdir -p "$(dirname "$state_file")"

rules=()
for rule in "$@"; do
    rule="${rule//$'\r'/}"
    rule="${rule//$'\n'/}"

    if [[ -z "$rule" || "$rule" != *,*,*,* ]]; then
        notify "Display Update" "Monitorregel overgeslagen: ongeldig formaat"
        continue
    fi

    rules+=("$rule")
done

if [[ "${#rules[@]}" -eq 0 ]]; then
    notify "Display Update" "Geen geldige monitorregels om toe te passen"
    exit 1
fi

lua_quote() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '"%s"' "$value"
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

monitor_rule_lua() {
    local rule="$1" output mode position scale extra key value
    local -a fields=()
    IFS=',' read -r -a fields <<< "$rule"
    (( ${#fields[@]} >= 4 )) || return 1
    for key in "${!fields[@]}"; do
        fields[$key]="$(trim "${fields[$key]}")"
    done
    output="${fields[0]}"; mode="${fields[1]}"; position="${fields[2]}"; scale="${fields[3]}"
    [[ "$scale" =~ ^[0-9]+([.][0-9]+)?$ ]] || scale="$(lua_quote "$scale")"
    printf 'hl.monitor({ output = %s, mode = %s, position = %s, scale = %s' \
        "$(lua_quote "$output")" "$(lua_quote "$mode")" "$(lua_quote "$position")" "$scale"
    for (( extra = 4; extra + 1 < ${#fields[@]}; extra += 2 )); do
        key="${fields[$extra]}"; value="${fields[$((extra + 1))]}"
        case "$key" in
            transform|vrr|bitdepth)
                [[ "$value" =~ ^[0-9]+$ ]] && printf ', %s = %s' "$key" "$value"
                ;;
            cm|mirror)
                printf ', %s = %s' "$key" "$(lua_quote "$value")"
                ;;
        esac
    done
    printf ' })'
}

lua_rules=()
for rule in "${rules[@]}"; do
    lua_rules+=("$(monitor_rule_lua "$rule")")
done

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    for lua_rule in "${lua_rules[@]}"; do
        if ! hyprctl eval "$lua_rule" >/dev/null; then
            notify "Display Update" "Toepassen mislukt; configuratie niet opgeslagen"
            exit 1
        fi
    done
fi

tmp_file="$(mktemp "${state_file}.tmp.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

{
    printf '# =============================================================================\n'
    printf '# monitors-local.lua - Lokale monitor-layout\n'
    printf '# =============================================================================\n'
    printf '# Gegenereerd door Super+O Monitor UI. Dit bestand is user-state en staat in .gitignore.\n'
    printf '# =============================================================================\n\n'
    printf 'return {\n    apply = function()\n'
    for lua_rule in "${lua_rules[@]}"; do
        printf '        %s\n' "$lua_rule"
    done
    printf '    end,\n}\n'
} >> "$tmp_file"

mv "$tmp_file" "$state_file"
trap - EXIT

notify "Display Update" "Opgeslagen in monitors-local.lua"
