#!/usr/bin/env bash
set -euo pipefail

conf_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors.conf"

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

mkdir -p "$(dirname "$conf_file")"

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

if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
    for rule in "${rules[@]}"; do
        if ! hyprctl keyword monitor "$rule" >/dev/null; then
            notify "Display Update" "Toepassen mislukt; configuratie niet opgeslagen"
            exit 1
        fi
    done
fi

tmp_file="$(mktemp "${conf_file}.tmp.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

{
    printf '# =============================================================================\n'
    printf '# monitors.conf - Lokale monitor-layout\n'
    printf '# =============================================================================\n'
    printf '# Gegenereerd door Super+O Monitor UI. Dit bestand is user-state en staat in .gitignore.\n'
    printf '# =============================================================================\n\n'
    for rule in "${rules[@]}"; do
        printf 'monitor = %s\n' "$rule"
    done
} >> "$tmp_file"

mv "$tmp_file" "$conf_file"
trap - EXIT

notify "Display Update" "Opgeslagen in monitors.conf"
