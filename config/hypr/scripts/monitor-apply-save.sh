#!/usr/bin/env bash
set -euo pipefail

conf_file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/conf.d/10-monitors.conf"
begin_marker="# BEGIN KINGSTRA MONITOR UI"
end_marker="# END KINGSTRA MONITOR UI"

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

if [[ ! -f "$conf_file" ]]; then
    cat > "$conf_file" <<'EOF'
# =============================================================================
# 10-monitors.conf - Monitor-configuratie
# =============================================================================
# Standaard: gebruik de voorkeursmodus van elke monitor.
# =============================================================================

monitor = , preferred, auto, 1.0
EOF
fi

tmp_file="$(mktemp "${conf_file}.tmp.XXXXXX")"
trap 'rm -f "$tmp_file"' EXIT

awk -v begin="$begin_marker" -v end="$end_marker" '
    $0 == begin { skipping = 1; next }
    $0 == end { skipping = 0; next }
    !skipping { print }
' "$conf_file" > "$tmp_file"

while [[ -s "$tmp_file" && "$(tail -n 1 "$tmp_file")" == "" ]]; do
    sed -i '$d' "$tmp_file"
done

{
    printf '\n\n%s\n' "$begin_marker"
    printf '# Gegenereerd door Super+O Monitor UI. Bewerk dit blok alleen als je de UI wilt overschrijven.\n'
    for rule in "${rules[@]}"; do
        printf 'monitor = %s\n' "$rule"
    done
    printf '%s\n' "$end_marker"
} >> "$tmp_file"

mv "$tmp_file" "$conf_file"
trap - EXIT

notify "Display Update" "Opgeslagen in 10-monitors.conf"
