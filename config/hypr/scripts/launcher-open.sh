#!/usr/bin/env bash
# Open de launcher met een starttekst, bijvoorbeeld ":" voor emoji (Super+.).
# Gebruik: launcher-open.sh [tekst]
set -u
printf '%s' "${1:-}" > /tmp/kingstra-launcher-seed
exec "$HOME/.config/hypr/scripts/qs_manager.sh" open launcher
