#!/usr/bin/env bash
# =============================================================================
# capture.sh — opnemen, tekst uit beeld en kleur kiezen (vastleg-studio)
# =============================================================================
# Gebruik:
#   capture.sh record [area|window|full] [--audio]   opname starten, of stoppen als hij loopt
#   capture.sh record-stop
#   capture.sh ocr                                   tekst uit een gebied naar het klembord
#   capture.sh color                                 kleur onder de muis (hex) naar het klembord
#   capture.sh status                                {"recording":bool,"since":epoch,"file":...}
#
# Schermafbeeldingen zelf blijven in screenshot.sh. Tijdens een opname toont
# het eiland een rode stip (island-probe.sh ziet wf-recorder).
# =============================================================================
set -uo pipefail

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RUNTIME/kingstra-recording.json"
PID_FILE="$RUNTIME/kingstra-recording.pid"
VIDEO_DIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Opnames"

feedback() {
    local token tmp
    token="$(date +%s%3N)$RANDOM"
    tmp="$(mktemp /tmp/kingstra-feedback.json.XXXXXX)" || return 0
    jq -nc --arg token "$token" --arg icon "$1" --arg title "$2" --arg detail "$3" \
        --argjson timeout "${4:-2400}" --arg urgency "${5:-normal}" \
        '{token:$token, icon:$icon, title:$title, detail:$detail, timeout:$timeout, urgency:$urgency}' > "$tmp" \
        && mv -f "$tmp" /tmp/kingstra-feedback.json
}

need() {
    command -v "$1" >/dev/null 2>&1 && return 0
    feedback "󰅙" "$2" "$1 ontbreekt; draai kingstra update" 4000 critical
    exit 127
}

# Geometrie "x,y wxh" voor grim/wf-recorder.
geometry() {
    case "$1" in
        window)
            hyprctl activewindow -j 2>/dev/null \
                | jq -r 'select(.at != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"'
            ;;
        full)
            hyprctl monitors -j 2>/dev/null \
                | jq -r '.[] | select(.focused) | "\(.x),\(.y) \((.width / .scale) | floor)x\((.height / .scale) | floor)"'
            ;;
        *)
            need slurp "Vastleggen mislukt"
            slurp -d 2>/dev/null
            ;;
    esac
}

recording() {
    [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

record_start() {
    local target="${1:-area}" audio="${2:-}" geo file
    need wf-recorder "Opnemen mislukt"
    geo="$(geometry "$target")" || exit 0
    [[ -n "$geo" ]] || exit 0
    mkdir -p "$VIDEO_DIR"
    file="$VIDEO_DIR/opname_$(date '+%Y%m%d_%H%M%S').mp4"
    local -a args=(-g "$geo" -f "$file")
    if [[ "$audio" == "--audio" ]] && command -v pactl >/dev/null 2>&1; then
        # Geluid van de computer zelf (wat je hoort), niet de microfoon.
        args+=("--audio=$(pactl get-default-sink).monitor")
    fi
    # shellcheck disable=SC2016 # draait in de binnenste sh
    setsid -f sh -c 'echo $$ > "$1"; shift; exec wf-recorder "$@"' sh "$PID_FILE" "${args[@]}" >/dev/null 2>&1
    jq -nc --arg file "$file" --argjson since "$(date +%s)" '{recording:true, since:$since, file:$file}' > "$STATE"
    feedback "󰑋" "Opname loopt" "Nog eens opnemen (of de stop in de studio) stopt hem" 2600
}

record_stop() {
    recording || { rm -f "$PID_FILE"; return 0; }
    local pid file
    pid="$(cat "$PID_FILE")"
    file="$(jq -r '.file // empty' "$STATE" 2>/dev/null)"
    kill -INT "$pid" 2>/dev/null
    for _ in $(seq 1 40); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$PID_FILE"
    printf '{"recording":false}\n' > "$STATE"
    [[ -n "$file" && -f "$file" ]] || return 0
    # Melding met knoppen, zoals de voorbeeldkaart na een schermafbeelding.
    (
        action="$(notify-send -a "Vastleggen" -i video-x-generic \
            -A open="Afspelen" -A folder="Map openen" \
            "Opname opgeslagen" "$(basename "$file")" 2>/dev/null)"
        case "$action" in
            open) xdg-open "$file" ;;
            folder) xdg-open "$(dirname "$file")" ;;
        esac
    ) >/dev/null 2>&1 &
    disown
}

ocr() {
    need grim "Tekst kopiëren mislukt"
    need tesseract "Tekst kopiëren mislukt"
    local geo text langs="nld+eng"
    geo="$(geometry area)" || exit 0
    [[ -n "$geo" ]] || exit 0
    # Zonder Nederlandse taaldata alleen Engels.
    tesseract --list-langs 2>/dev/null | grep -qx nld || langs="eng"
    text="$(grim -g "$geo" - | tesseract stdin stdout -l "$langs" 2>/dev/null | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d')"
    if [[ -z "${text//[[:space:]]/}" ]]; then
        feedback "󰈙" "Geen tekst gevonden" "Probeer een groter of scherper stuk" 2400 warning
        return 0
    fi
    printf '%s' "$text" | wl-copy
    feedback "󰈙" "Tekst gekopieerd" "$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-70)" 2600
}

color() {
    need hyprpicker "Kleur kiezen mislukt"
    local hex
    hex="$(hyprpicker -f hex -n 2>/dev/null | tr -d '[:space:]')"
    [[ -n "$hex" ]] || exit 0
    printf '%s' "$hex" | wl-copy
    feedback "󰈊" "Kleur $hex" "Staat op je klembord" 2400
}

case "${1:-}" in
    record) if recording; then record_stop; else record_start "${2:-area}" "${3:-}"; fi ;;
    record-stop) record_stop ;;
    ocr) ocr ;;
    color) color ;;
    status)
        if recording; then cat "$STATE"; else printf '{"recording":false}\n'; fi
        ;;
    *) sed -n '3,12p' "$0"; exit 2 ;;
esac
