#!/usr/bin/env bash
set -euo pipefail

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"
READER_FALLBACK="$REPO_ROOT/config/shared/scripts/kingstra-theme-read.py"

resolve_reader_cmd() {
    if [[ -x "$HOME/.local/bin/kingstra-theme-read" ]]; then
        printf '%s\n' "$HOME/.local/bin/kingstra-theme-read"
        return 0
    fi

    local found=""
    found="$(command -v kingstra-theme-read 2>/dev/null || true)"
    if [[ -n "$found" ]]; then
        printf '%s\n' "$found"
        return 0
    fi

    if [[ -f "$READER_FALLBACK" ]]; then
        printf '%s\n' "$READER_FALLBACK"
        return 0
    fi

    return 1
}

READER_CMD="$(resolve_reader_cmd || true)"
if [[ -z "$READER_CMD" ]]; then
    notify-send "Theme" "Geen kingstra-theme-read commando gevonden" 2>/dev/null || true
    exit 1
fi

if [[ "$READER_CMD" == *.py ]]; then
    exec python3 "$READER_CMD" "$@"
fi

exec "$READER_CMD" "$@"
