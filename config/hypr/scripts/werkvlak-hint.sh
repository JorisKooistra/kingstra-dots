#!/usr/bin/env bash
# Eenmalige uitleg van het ruimtelijk werkvlak. spatial.lua roept dit aan
# zodra je voor het eerst op zo'n werkruimte komt; daarna onthoudt een
# vlagbestand dat het al getoond is. "--reset" laat hem nog een keer zien.
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra"
flag="$state_dir/werkvlak-hint-shown"

if [[ "${1:-}" == "--reset" ]]; then
    rm -f "$flag"
    exit 0
fi
[[ -e "$flag" ]] && exit 0
mkdir -p "$state_dir"
: > "$flag"

command -v notify-send >/dev/null 2>&1 || exit 0

if grep -qi 'touchpad' /proc/bus/input/devices 2>/dev/null; then
    body="Drie vingers: het werkvlak schuift mee met je vingers.
Knijpen: uitzoomen en weer terug.
Op een gewone werkruimte wisselen drie vingers opzij van werkruimte.
Super vasthouden toont alle toetsen."
else
    body="Super + wiel: een plek verder. Super + Ctrl + wiel: uitzoomen.
Super + Ctrl + linkermuis slepen: vrij schuiven. Super + Tab: de kaart.
Super vasthouden toont alle toetsen."
fi

notify-send -a Kingstra -i view-grid -t 20000 "Ruimtelijk werkvlak" "$body" >/dev/null 2>&1 || true
