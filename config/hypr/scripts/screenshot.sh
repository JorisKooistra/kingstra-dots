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
if ! mkdir -p "$SCREENSHOT_DIR"; then
    notify-send -u critical -i dialog-error "Screenshot" "Map kan niet worden aangemaakt: $SCREENSHOT_DIR"
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
    notify-send -u critical -i dialog-error "Screenshot" "$1 ontbreekt; installeer het pakket en probeer opnieuw."
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
        notify-send -u critical -i dialog-error "Screenshot" "Volledig scherm vastleggen is mislukt"
        exit 1
    fi
else
    # Gebied-selectie via slurp
    command -v slurp >/dev/null 2>&1 || missing_tool "slurp"
    SELECTION="$(slurp -d 2>/dev/null)" || exit 0 # bewust stil bij annuleren
    if [[ -z "$SELECTION" ]] || ! grim -g "$SELECTION" "$OUTPUT_FILE"; then
        notify-send -u critical -i dialog-error "Screenshot" "Geselecteerd gebied vastleggen is mislukt"
        exit 1
    fi
fi

[[ -f "$OUTPUT_FILE" ]] || exit 1

# Bestemming
case "$DEST" in
    clipboard)
        if copy_image; then
            notify-send -i camera-photo "Screenshot" "Gekopieerd naar klembord" -t 2000
        else
            notify-send -u normal -i camera-photo "Screenshot" "wl-copy ontbreekt; screenshot is niet gekopieerd" -t 3000
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
            notify-send -i camera-photo "Screenshot" "Opgeslagen: $OUTPUT_FILE" -t 2000
        else
            # Satty niet gevonden — gewoon opslaan
            if copy_image; then
                notify-send -i camera-photo "Screenshot" "Satty niet gevonden; opgeslagen en gekopieerd" -t 3000
            else
                notify-send -u normal -i camera-photo "Screenshot" "Satty en wl-copy niet gevonden; opgeslagen" -t 3500
            fi
        fi
        ;;

    save|*)
        if copy_image; then
            notify-send -i camera-photo "Screenshot" "Opgeslagen en gekopieerd: $(basename "$OUTPUT_FILE")" -t 2200
        else
            notify-send -u normal -i camera-photo "Screenshot" "Opgeslagen: $(basename "$OUTPUT_FILE")" -t 2200
        fi
        ;;
esac
