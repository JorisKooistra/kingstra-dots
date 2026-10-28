#!/usr/bin/env bash
# Volume-, microfoon- en helderheidstoetsen.
#
# Voert de actie zelf uit (wpctl / brightnessctl) en meldt de nieuwe waarde
# aan het Kingstra-eiland via /tmp/kingstra-island.json. Staat het eiland
# uit (~/.local/state/kingstra/island.json: "osd": false) of draait de shell
# niet, dan neemt swayosd het over, zoals vroeger.
#
# Gebruik: osd.sh volume up|down|mute
#          osd.sh mic mute
#          osd.sh brightness up|down
#          osd.sh caps
set -u

kind="${1:-}"
action="${2:-}"
STEP=5
EVENT_FILE="/tmp/kingstra-island.json"
STATE_FILE="$HOME/.local/state/kingstra/island.json"

island_enabled() {
    pgrep -f "quickshell.*TopBar.qml" >/dev/null 2>&1 || return 1
    [[ -f "$STATE_FILE" ]] || return 0
    python3 - "$STATE_FILE" <<'EOF' 2>/dev/null
import json, sys
try:
    data = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
sys.exit(0 if data.get("osd", True) else 1)
EOF
}

swayosd_fallback() {
    command -v swayosd-client >/dev/null 2>&1 || return 1
    case "$kind:$action" in
        volume:up)       swayosd-client --output-volume raise ;;
        volume:down)     swayosd-client --output-volume lower ;;
        volume:mute)     swayosd-client --output-volume mute-toggle ;;
        mic:mute)        swayosd-client --input-volume mute-toggle ;;
        brightness:up)   swayosd-client --brightness raise ;;
        brightness:down) swayosd-client --brightness lower ;;
        caps:*)          swayosd-client --caps-lock ;;
        *) return 1 ;;
    esac
}

if ! island_enabled; then
    swayosd_fallback && exit 0
fi

emit() {
    # $1 kind, $2 waarde 0-100 (of -1), $3 muted/aan (true/false)
    local token tmp
    token="$(date +%s%3N)$RANDOM"
    tmp="$(mktemp "${EVENT_FILE}.XXXXXX")" || return
    printf '{"token":"%s","kind":"%s","value":%s,"muted":%s}\n' "$token" "$1" "$2" "$3" >"$tmp"
    mv -f "$tmp" "$EVENT_FILE"
}

wp_state() {
    # Zet vol (0-100) en muted (true/false) voor $1 (@DEFAULT_AUDIO_SINK@ ...)
    local line
    line="$(wpctl get-volume "$1" 2>/dev/null)"
    vol="$(awk '{printf "%d", $2 * 100 + 0.5}' <<<"$line")"
    [[ -n "$vol" ]] || vol=0
    if [[ "$line" == *MUTED* ]]; then muted=true; else muted=false; fi
}

case "$kind" in
    volume)
        sink="@DEFAULT_AUDIO_SINK@"
        case "$action" in
            up)   wpctl set-mute "$sink" 0; wpctl set-volume -l 1.0 "$sink" "${STEP}%+" ;;
            down) wpctl set-volume "$sink" "${STEP}%-" ;;
            mute) wpctl set-mute "$sink" toggle ;;
        esac
        wp_state "$sink"
        emit volume "$vol" "$muted"
        ;;
    mic)
        src="@DEFAULT_AUDIO_SOURCE@"
        wpctl set-mute "$src" toggle
        wp_state "$src"
        emit mic "$vol" "$muted"
        ;;
    brightness)
        command -v brightnessctl >/dev/null 2>&1 || { swayosd_fallback; exit 0; }
        case "$action" in
            up)   brightnessctl -q set "${STEP}%+" ;;
            down) brightnessctl -q -n 1 set "${STEP}%-" ;;
        esac
        cur="$(brightnessctl get 2>/dev/null || echo 0)"
        max="$(brightnessctl max 2>/dev/null || echo 1)"
        (( max > 0 )) || max=1
        emit brightness "$(( cur * 100 / max ))" false
        ;;
    caps)
        # Even wachten: de toets is net losgelaten en Hyprland moet de
        # nieuwe stand nog doorgeven.
        sleep 0.08
        on=false
        if hyprctl devices -j 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit(0 if any(k.get("capsLock") for k in d.get("keyboards", [])) else 1)'; then
            on=true
        fi
        emit caps -1 "$on"
        ;;
    *)
        echo "gebruik: osd.sh volume up|down|mute | mic mute | brightness up|down | caps" >&2
        exit 2
        ;;
esac
