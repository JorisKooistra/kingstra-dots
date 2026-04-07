#!/usr/bin/env bash
# =============================================================================
# write_keybind.sh — Update a single keybind in a Hyprland conf file
# =============================================================================
# Usage: write_keybind.sh <file> <line_number> <new_full_line>
FILE="${HOME}/.config/hypr/conf.d/$1"
LINE="$2"
shift 2
NEW_LINE="$*"

[[ -f "$FILE" ]] || { echo "File not found: $FILE" >&2; exit 1; }

sed -i "${LINE}s|.*|${NEW_LINE}|" "$FILE"

# Reload Hyprland config
hyprctl reload 2>/dev/null

notify-send "Settings" "Keybind updated — config reloaded" 2>/dev/null
