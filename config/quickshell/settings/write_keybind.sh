#!/usr/bin/env bash
# Lua-native editor for the explicit exec() bindings in hypr/lua/binds.lua.
# It never writes a Hyprlang .conf file and reloads only after an atomic write.
set -euo pipefail

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
bind_file="$config_dir/hypr/lua/binds.lua"

die() { printf '%s\n' "$*" >&2; exit 1; }
[[ -f "$bind_file" ]] || die "Lua-bindbestand niet gevonden: $bind_file"

valid_part() {
    [[ "$1" =~ ^[[:alnum:]_:-]+$ ]]
}

normalise_binding() {
    local mods="${1//[[:space:]]/}" key="${2//[[:space:]]/}"
    [[ -n "$key" ]] || die "Key mag niet leeg zijn"
    valid_part "$key" || die "Ongeldige key"
    if [[ -n "$mods" ]]; then
        local part
        IFS='+' read -r -a mod_parts <<<"$mods"
        for part in "${mod_parts[@]}"; do
            valid_part "$part" || die "Ongeldige modifier"
        done
        printf '%s + %s' "${mods//+/ + }" "$key"
    else
        printf '%s' "$key"
    fi
}

atomic_replace() {
    local tmp backup
    tmp="$(mktemp "$bind_file.XXXXXX")"
    backup="$(mktemp "$bind_file.backup.XXXXXX")"
    cp -- "$bind_file" "$backup"
    "$@" >"$tmp"
    if ! luac -p "$tmp"; then
        rm -f -- "$tmp" "$backup"
        die "Wijziging geweigerd: gegenereerde bindings zijn geen geldige Lua"
    fi
    chmod --reference="$bind_file" "$tmp"
    mv "$tmp" "$bind_file"
    if ! hyprctl reload >/dev/null 2>&1; then
        mv "$backup" "$bind_file"
        hyprctl reload >/dev/null 2>&1 || true
        die "Hyprland kon de gewijzigde Lua-configuratie niet laden"
    fi
    rm -f -- "$backup"
}

action="${1:-}"
case "$action" in
    --update)
        [[ $# -eq 4 ]] || die "Gebruik: write_keybind.sh --update REGEL MODS KEY"
        line_no="$2"
        [[ "$line_no" =~ ^[1-9][0-9]*$ ]] || die "Ongeldig regelnummer"
        binding="$(normalise_binding "$3" "$4")"
        current="$(sed -n "${line_no}p" "$bind_file")"
        [[ "$current" =~ ^[[:space:]]*exec\( ]] || die "Alleen expliciete exec()-bindings zijn bewerkbaar"
        atomic_replace awk -v target="$line_no" -v replacement="$binding" '
            NR == target {
                sub(/exec\([^,]*,/, "exec(\"" replacement "\",")
            }
            { print }
        ' "$bind_file"
        ;;
    --add)
        [[ $# -eq 4 ]] || die "Gebruik: write_keybind.sh --add MODS KEY COMMAND"
        binding="$(normalise_binding "$2" "$3")"
        command="$4"
        [[ -n "$command" && "$command" != *$'\n'* && "$command" != *$'\r'* ]] || die "Ongeldige opdracht"
        escaped_command="${command//\\/\\\\}"
        escaped_command="${escaped_command//\"/\\\"}"
        atomic_replace awk -v binding="$binding" -v command="$escaped_command" '
            /^hl\.define_submap\(/ && !inserted {
                print "-- Custom bindings managed by Settings"
                print "exec(\"" binding "\", \"" command "\")"
                inserted = 1
            }
            { print }
            END {
                if (!inserted) {
                    print "-- Custom bindings managed by Settings"
                    print "exec(\"" binding "\", \"" command "\")"
                }
            }
        ' "$bind_file"
        ;;
    --remove)
        [[ $# -eq 2 && "$2" =~ ^[1-9][0-9]*$ ]] || die "Gebruik: write_keybind.sh --remove REGEL"
        line_no="$2"
        current="$(sed -n "${line_no}p" "$bind_file")"
        [[ "$current" =~ ^[[:space:]]*exec\( ]] || die "Alleen expliciete exec()-bindings zijn verwijderbaar"
        atomic_replace awk -v target="$line_no" 'NR != target { print }' "$bind_file"
        ;;
    *) die "Gebruik: write_keybind.sh {--update|--add|--remove} ..." ;;
esac
