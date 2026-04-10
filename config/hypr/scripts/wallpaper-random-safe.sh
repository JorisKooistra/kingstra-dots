#!/usr/bin/env bash
set -u

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"
REPO_FALLBACK="$REPO_ROOT/config/wallpaper/kingstra-wallpaper"

resolve_wallpaper_cmd() {
    if [[ -x "$HOME/.local/bin/kingstra-wallpaper" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-wallpaper"
        return 0
    fi

    local found=""
    found="$(command -v kingstra-wallpaper 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    if [[ -x "$REPO_FALLBACK" ]]; then
        printf '%s\n' "$REPO_FALLBACK"
        return 0
    fi

    return 1
}

WALL_CMD="$(resolve_wallpaper_cmd || true)"
if [[ -z "$WALL_CMD" ]]; then
    notify-send "Wallpaper" "Geen kingstra-wallpaper commando gevonden" 2>/dev/null || true
    exit 1
fi

if "$WALL_CMD" random >/dev/null 2>&1; then
    exit 0
fi

notify-send "Wallpaper" "Random wallpaper mislukt (controleer skwd-wall pad)" 2>/dev/null || true
exit 1
