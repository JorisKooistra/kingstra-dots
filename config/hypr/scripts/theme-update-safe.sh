#!/usr/bin/env bash
set -euo pipefail

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"
UPDATER_FALLBACK="$REPO_ROOT/config/shared/scripts/kingstra-theme-update.py"

resolve_updater_cmd() {
    if [[ -f "$HOME/.config/shared/scripts/kingstra-theme-update.py" ]]; then
        printf '%s\n' "$HOME/.config/shared/scripts/kingstra-theme-update.py"
        return 0
    fi

    if [[ -x "$HOME/.local/bin/kingstra-theme-update" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-theme-update"
        return 0
    fi

    if [[ -x "$HOME/.local/bin/kingstra-theme-update.py" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-theme-update.py"
        return 0
    fi

    local found=""
    found="$(command -v kingstra-theme-update 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    found="$(command -v kingstra-theme-update.py 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    if [[ -f "$UPDATER_FALLBACK" ]]; then
        printf '%s\n' "$UPDATER_FALLBACK"
        return 0
    fi

    return 1
}

UPDATER_CMD="$(resolve_updater_cmd || true)"
if [[ -z "$UPDATER_CMD" ]]; then
    notify-send "Theme" "Geen kingstra-theme-update commando gevonden" 2>/dev/null || true
    exit 1
fi

if [[ "$UPDATER_CMD" == *.py ]]; then
    exec python3 "$UPDATER_CMD" "$@"
fi

exec "$UPDATER_CMD" "$@"
