#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell"
CACHE_FILE="$CACHE_DIR/package_updates_count"
COUNT_SCRIPT="${HOME}/.config/quickshell/package_updates.sh"

echo "=============================================="
echo " Kingstra Update Runner (yay)"
echo "=============================================="
echo

if ! command -v yay >/dev/null 2>&1; then
    echo "Fout: 'yay' niet gevonden op dit systeem."
    echo "Installeer yay of gebruik handmatig pacman."
    echo
    read -r -p "Druk Enter om te sluiten..." _
    exit 1
fi

echo "Start: yay -Syu"
echo

set +e
yay -Syu
update_exit=$?
set -e

mkdir -p "$CACHE_DIR"
rm -f "$CACHE_FILE"
"$COUNT_SCRIPT" >/dev/null 2>&1 || true

echo
if [[ $update_exit -eq 0 ]]; then
    echo "Update klaar."
else
    echo "Update beëindigd met code: $update_exit"
fi
echo
read -r -p "Druk Enter om te sluiten..." _
exit "$update_exit"
