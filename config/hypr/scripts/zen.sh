#!/usr/bin/env bash
# Zen-modus: alleen jij en het venster waar je in werkt.
#
#   - de balk en de rail verbergen zich tot je de rand aanraakt
#   - Niet storen aan (kritieke meldingen komen nog wel door)
#   - bureaubladwidgets weg
#   - vensters zonder focus worden gedimd
#
# Uitzetten zet alles terug zoals het was. Gebruik: zen.sh toggle|on|off|status
# (Super+Alt+Z, `kingstra zen`, het toetsenbordmenu onder Modus).
set -uo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
ZEN_FILE="$RUNTIME/kingstra-zen.json"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
MODE_JSON="$CONFIG_HOME/kingstra/state/mode.json"
DND_FILE="$STATE_HOME/kingstra/notification-dnd"
WIDGETS_FILE="$STATE_HOME/kingstra/desktop-widgets.json"

hypr() { "${HYPRCTL_BIN:-hyprctl}" "$@"; }

notif_command() {
    printf '%s:%s\n' "$1" "$(date +%s%N)" >/tmp/qs_notifications_command
}

feedback() {
    local token tmp
    token="$(date +%s%3N)$RANDOM"
    tmp="$(mktemp /tmp/kingstra-feedback.json.XXXXXX)" || return 0
    printf '{"token":"%s","icon":"%s","title":"%s","detail":"%s","timeout":2000}\n' "$token" "$1" "$2" "$3" >"$tmp"
    mv -f "$tmp" /tmp/kingstra-feedback.json
}

option_value() {
    hypr getoption "$1" -j 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("int", d.get("float", "")))
except Exception:
    print("")'
}

# Zet bar_autohide in mode.json; $1 = true/false.
set_autohide() {
    [[ -f "$MODE_JSON" ]] || return 0
    python3 - "$MODE_JSON" "$1" <<'PY'
import json, os, sys
path, value = sys.argv[1], sys.argv[2] == "true"
try:
    data = json.load(open(path))
except Exception:
    sys.exit(0)
data["bar_autohide"] = value
json.dump(data, open(path + ".tmp", "w"))
os.replace(path + ".tmp", path)
PY
}

json_field() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$1" "$2" 2>/dev/null
}

zen_on() {
    [[ -f "$ZEN_FILE" ]] && return 0

    local autohide=false dnd=0 widgets=true dim dim_strength
    [[ -f "$MODE_JSON" ]] && [[ "$(json_field "$MODE_JSON" bar_autohide)" == "True" ]] && autohide=true
    [[ -f "$DND_FILE" ]] && dnd="$(tr -d '[:space:]' <"$DND_FILE")"
    [[ -f "$WIDGETS_FILE" ]] && [[ "$(json_field "$WIDGETS_FILE" enabled)" == "False" ]] && widgets=false
    dim="$(option_value decoration:dim_inactive)"
    dim_strength="$(option_value decoration:dim_strength)"

    printf '{"autohide":%s,"dnd":"%s","widgets":%s,"dim":"%s","dim_strength":"%s"}\n' \
        "$autohide" "$dnd" "$widgets" "$dim" "$dim_strength" >"$ZEN_FILE"

    set_autohide true
    notif_command dnd-on
    "$HOME/.local/bin/kingstra" widgets uit >/dev/null 2>&1 \
        || "$CONFIG_HOME/shared/scripts/kingstra" widgets uit >/dev/null 2>&1 || true
    hypr eval 'hl.config({ decoration = { dim_inactive = true, dim_strength = 0.35 } })' >/dev/null 2>&1 || true
    feedback "󰚀" "Zen-modus aan" "Super+Alt+Z zet alles terug"
}

zen_off() {
    [[ -f "$ZEN_FILE" ]] || return 0
    local autohide dnd widgets dim dim_strength
    autohide="$(json_field "$ZEN_FILE" autohide)"
    dnd="$(json_field "$ZEN_FILE" dnd)"
    widgets="$(json_field "$ZEN_FILE" widgets)"
    dim="$(json_field "$ZEN_FILE" dim)"
    dim_strength="$(json_field "$ZEN_FILE" dim_strength)"

    [[ "$autohide" == "True" ]] && set_autohide true || set_autohide false
    [[ "$dnd" == "1" ]] || notif_command dnd-off
    [[ "$widgets" == "True" ]] && { "$HOME/.local/bin/kingstra" widgets aan >/dev/null 2>&1 \
        || "$CONFIG_HOME/shared/scripts/kingstra" widgets aan >/dev/null 2>&1 || true; }
    local dim_lua=false
    [[ "$dim" == "1" ]] && dim_lua=true
    [[ "$dim_strength" =~ ^[0-9.]+$ ]] || dim_strength=0.1
    hypr eval "hl.config({ decoration = { dim_inactive = $dim_lua, dim_strength = $dim_strength } })" >/dev/null 2>&1 || true
    rm -f "$ZEN_FILE"
    feedback "󰚀" "Zen-modus uit" "Alles staat weer zoals het was"
}

case "${1:-toggle}" in
    on) zen_on ;;
    off) zen_off ;;
    toggle) if [[ -f "$ZEN_FILE" ]]; then zen_off; else zen_on; fi ;;
    status) if [[ -f "$ZEN_FILE" ]]; then echo "aan"; else echo "uit"; fi ;;
    *) echo "gebruik: zen.sh toggle|on|off|status" >&2; exit 2 ;;
esac
