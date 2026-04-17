#!/usr/bin/env bash
# =============================================================================
# write_keybind.sh — Manage keybinds in Hyprland conf files
# =============================================================================
# Usage:
#   write_keybind.sh --update <file> <line_number> <new_full_line>
#   write_keybind.sh --add    <file> <new_full_line>
#   write_keybind.sh --remove <file> <line_number>

ACTION="$1"
shift

CONF_DIR="${HOME}/.config/hypr/conf.d"

case "$ACTION" in
    --update)
        FILE="$CONF_DIR/$1"; LINE="$2"; shift 2; NEW_LINE="$*"
        [[ -f "$FILE" ]] || { echo "Bestand niet gevonden: $FILE" >&2; exit 1; }
        sed -i "${LINE}s|.*|${NEW_LINE}|" "$FILE"
        ;;
    --add)
        FILE="$CONF_DIR/$1"; shift; NEW_LINE="$*"
        [[ -f "$FILE" ]] || { echo "Bestand niet gevonden: $FILE" >&2; exit 1; }
        echo "$NEW_LINE" >> "$FILE"
        ;;
    --remove)
        FILE="$CONF_DIR/$1"; LINE="$2"
        [[ -f "$FILE" ]] || { echo "Bestand niet gevonden: $FILE" >&2; exit 1; }
        # Comment out the line instead of deleting
        sed -i "${LINE}s|^\(.*\)|# REMOVED: \1|" "$FILE"
        ;;
    *)
        # Legacy mode: write_keybind.sh <file> <line> <new_line>
        FILE="$CONF_DIR/$1"; LINE="$2"; shift 2; NEW_LINE="$*"
        [[ -f "$FILE" ]] || { echo "Bestand niet gevonden: $FILE" >&2; exit 1; }
        sed -i "${LINE}s|.*|${NEW_LINE}|" "$FILE"
        ;;
esac

# Reload Hyprland config
hyprctl reload 2>/dev/null

notify-send "Settings" "Keybind bijgewerkt — config herladen" 2>/dev/null
