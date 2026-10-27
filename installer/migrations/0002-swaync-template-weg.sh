#!/usr/bin/env bash
# Het swaync-kleurtemplate is uit de repo verdwenen. Haal het blok
# [templates.swaync] uit de lokale Matugen-config, anders struikelt Matugen
# over een ontbrekend template. Een kopie van de oude config blijft staan.

migration_run() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
    [[ -f "$conf" ]] || return 0
    grep -q '^\[templates\.swaync\]' "$conf" || return 0

    cp -p "$conf" "$conf.voor-swaync-migratie" || return 1
    # Verwijder de kop en de regels eronder tot de volgende sectie of lege regel.
    awk '
        /^\[templates\.swaync\]/ { skip = 1; next }
        skip && (/^\[/ || /^[[:space:]]*$/) { skip = 0 }
        !skip { print }
    ' "$conf.voor-swaync-migratie" > "$conf.tmp" && mv "$conf.tmp" "$conf" || return 1
    log_ok "swaync-template uit Matugen-config gehaald"
}
