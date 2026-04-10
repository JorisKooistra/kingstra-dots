#!/usr/bin/env bash
set -u

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"
SWITCH_FALLBACK="$REPO_ROOT/config/shared/scripts/kingstra-theme-switch"
THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/themes"
THEMES_FALLBACK_DIR="$REPO_ROOT/config/kingstra/themes"

resolve_switch_cmd() {
    if [[ -x "$HOME/.local/bin/kingstra-theme-switch" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-theme-switch"
        return 0
    fi

    local found=""
    found="$(command -v kingstra-theme-switch 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    if [[ -x "$SWITCH_FALLBACK" ]]; then
        printf '%s\n' "$SWITCH_FALLBACK"
        return 0
    fi

    return 1
}

SWITCH_CMD="$(resolve_switch_cmd || true)"
if [[ -z "$SWITCH_CMD" ]]; then
    notify-send "Theme" "Geen kingstra-theme-switch commando gevonden" 2>/dev/null || true
    exit 1
fi

mapfile -t THEMES < <(
    {
        if command -v jq >/dev/null 2>&1; then
            "$SWITCH_CMD" --list 2>/dev/null \
                | jq -r '.[].id // empty' 2>/dev/null
        fi

        if [[ -d "$THEMES_DIR" ]]; then
            find "$THEMES_DIR" -maxdepth 1 -type f -name "*.toml" -printf "%f\n" 2>/dev/null \
                | sed 's/\.toml$//'
        elif [[ -d "$THEMES_FALLBACK_DIR" ]]; then
            find "$THEMES_FALLBACK_DIR" -maxdepth 1 -type f -name "*.toml" -printf "%f\n" 2>/dev/null \
                | sed 's/\.toml$//'
        fi
    } | awk 'NF && !seen[$0]++'
)

if (( ${#THEMES[@]} == 0 )); then
    notify-send "Theme" "Geen themes gevonden om door te schakelen" 2>/dev/null || true
    exit 1
fi

CURRENT="$("$SWITCH_CMD" --current 2>/dev/null || true)"
NEXT_INDEX=0

for i in "${!THEMES[@]}"; do
    if [[ "${THEMES[$i]}" == "$CURRENT" ]]; then
        NEXT_INDEX=$(( (i + 1) % ${#THEMES[@]} ))
        break
    fi
done

NEXT_THEME="${THEMES[$NEXT_INDEX]}"

if "$SWITCH_CMD" "$NEXT_THEME" >/dev/null 2>&1; then
    notify-send "Theme" "Thema: $NEXT_THEME" 2>/dev/null || true
    exit 0
fi

notify-send "Theme" "Thema wisselen mislukt" 2>/dev/null || true
exit 1
