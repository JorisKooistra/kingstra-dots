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
mkdir -p "$SCREENSHOT_DIR"

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

# Capture
if [[ "$MODE" == "full" ]]; then
    grim "$OUTPUT_FILE"
else
    # Gebied-selectie via slurp
    SELECTION="$(slurp -d 2>/dev/null)" || exit 0
    grim -g "$SELECTION" "$OUTPUT_FILE"
fi

[[ -f "$OUTPUT_FILE" ]] || exit 1

# Bestemming
case "$DEST" in
    clipboard)
        wl-copy < "$OUTPUT_FILE"
        notify-send -i camera-photo "Screenshot" "Gekopieerd naar klembord" -t 2000
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
            wl-copy < "$OUTPUT_FILE"
            notify-send -i camera-photo "Screenshot" "Satty niet gevonden, gekopieerd naar klembord" -t 3000
        fi
        ;;

    save|*)
        wl-copy < "$OUTPUT_FILE"   # Altijd ook kopiëren
        notify-send -i camera-photo "Screenshot" "Opgeslagen: $(basename "$OUTPUT_FILE")" -t 2000
        ;;
esac
