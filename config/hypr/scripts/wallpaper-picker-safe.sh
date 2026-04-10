#!/usr/bin/env bash
set -u

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"
SYNC_FALLBACK="$REPO_ROOT/config/wallpaper/kingstra-skwd-wallpaper-sync"

resolve_sync_cmd() {
    if [[ -x "$HOME/.local/bin/kingstra-skwd-wallpaper-sync" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-skwd-wallpaper-sync"
        return 0
    fi

    local found=""
    found="$(command -v kingstra-skwd-wallpaper-sync 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    if [[ -x "$SYNC_FALLBACK" ]]; then
        printf '%s\n' "$SYNC_FALLBACK"
        return 0
    fi

    return 1
}

SYNC_CMD="$(resolve_sync_cmd || true)"
if [[ -n "$SYNC_CMD" ]] && "$SYNC_CMD" >/dev/null 2>&1; then
    exit 0
fi

notify-send "Wallpaper" "skwd-wall picker kon niet gestart worden" 2>/dev/null || true
exit 1
