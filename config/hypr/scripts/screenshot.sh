#!/usr/bin/env bash
# =============================================================================
# screenshot.sh — Screenshot-logica
# =============================================================================
# Gebruik (fase 4 koppelt deze binds):
#   screenshot.sh               → gebied-selectie, opslaan + kopiëren
#   screenshot.sh --clipboard   → gebied-selectie, alleen kopiëren
#   screenshot.sh --annotate    → gebied-selectie + satty annotatie
#   screenshot.sh --full        → volledig scherm, opslaan
#   screenshot.sh --full --clipboard → volledig scherm, kopiëren
# =============================================================================

SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
FEEDBACK_FILE="/tmp/kingstra-feedback.json"

# Stuur korte, native feedback naar Quickshell. De file-route is bewust
# atomair: meerdere ShellSurface-instanties kunnen hem veilig pollen zonder
# ooit half JSON te lezen. Alleen als jq ontbreekt valt dit terug op de
# reguliere notification-server.
feedback() {
    local icon="$1"
    local title="$2"
    local detail="$3"
    local urgency="${4:-normal}"
    local timeout="${5:-2400}"
    local tmp_file

    if command -v jq >/dev/null 2>&1; then
        tmp_file="$(mktemp "${FEEDBACK_FILE}.XXXXXX")" || return 0
        if jq -n -c \
            --arg token "$(date +%s%N)-$$" \
            --arg icon "$icon" \
            --arg title "$title" \
            --arg detail "$detail" \
            --arg urgency "$urgency" \
            --argjson timeout "$timeout" \
            '{token: $token, scope: "focused", icon: $icon, title: $title, detail: $detail, urgency: $urgency, timeout: $timeout}' \
            > "$tmp_file"; then
            mv -f "$tmp_file" "$FEEDBACK_FILE"
            return 0
        fi
        rm -f "$tmp_file"
    fi

    command -v notify-send >/dev/null 2>&1 \
        && notify-send -u "$urgency" -i camera-photo "$title" "$detail" -t "$timeout" || true
}

if ! mkdir -p "$SCREENSHOT_DIR"; then
    feedback "󰅙" "Screenshot mislukt" "Map kan niet worden aangemaakt" "critical" 4500
    exit 1
fi

TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
OUTPUT_FILE="$SCREENSHOT_DIR/screenshot_${TIMESTAMP}.png"

MODE="area"
DEST="save"   # "save" | "clipboard" | "annotate"

# Argumenten verwerken
while [[ $# -gt 0 ]]; do
    case "$1" in
        --full)        MODE="full"      ;;
        --clipboard)   DEST="clipboard" ;;
        --annotate)    DEST="annotate"  ;;
        *) ;;
    esac
    shift
done

missing_tool() {
    feedback "󰅙" "Screenshot mislukt" "$1 ontbreekt" "critical" 4500
    exit 127
}

command -v grim >/dev/null 2>&1 || missing_tool "grim"

copy_image() {
    if command -v wl-copy >/dev/null 2>&1; then
        wl-copy < "$OUTPUT_FILE"
        return 0
    fi
    return 1
}

# Capture
if [[ "$MODE" == "full" ]]; then
    if ! grim "$OUTPUT_FILE"; then
        feedback "󰅙" "Screenshot mislukt" "Volledig scherm vastleggen is mislukt" "critical" 4500
        exit 1
    fi
else
    # Gebied-selectie via slurp
    command -v slurp >/dev/null 2>&1 || missing_tool "slurp"
    SELECTION="$(slurp -d 2>/dev/null)" || exit 0 # bewust stil bij annuleren
    if [[ -z "$SELECTION" ]] || ! grim -g "$SELECTION" "$OUTPUT_FILE"; then
        feedback "󰅙" "Screenshot mislukt" "Geselecteerd gebied vastleggen is mislukt" "critical" 4500
        exit 1
    fi
fi

[[ -f "$OUTPUT_FILE" ]] || exit 1

# Bestemming
case "$DEST" in
    clipboard)
        if copy_image; then
            feedback "󰄀" "Screenshot gekopieerd" "Staat op je klembord" "normal" 2200
        else
            feedback "󰅙" "Screenshot opgeslagen" "wl-copy ontbreekt" "warning" 3200
        fi
        rm -f "$OUTPUT_FILE"   # Niet opslaan bij clipboard-modus
        ;;

    annotate)
        if command -v satty &>/dev/null; then
            satty --filename "$OUTPUT_FILE" \
                  --output-filename "$OUTPUT_FILE" \
                  --early-exit \
                  --copy-command "wl-copy" \
                  2>/dev/null
            feedback "󰄀" "Screenshot opgeslagen" "$(basename "$OUTPUT_FILE")" "normal" 2400
        else
            # Satty niet gevonden — gewoon opslaan
            if copy_image; then
                feedback "󰄀" "Screenshot opgeslagen en gekopieerd" "Satty ontbreekt" "warning" 3200
            else
                feedback "󰅙" "Screenshot opgeslagen" "Satty en wl-copy ontbreken" "warning" 3600
            fi
        fi
        ;;

    save|*)
        if copy_image; then
            feedback "󰄀" "Screenshot opgeslagen en gekopieerd" "$(basename "$OUTPUT_FILE")" "normal" 2400
        else
            feedback "󰄀" "Screenshot opgeslagen" "$(basename "$OUTPUT_FILE")" "normal" 2400
        fi
        ;;
esac
