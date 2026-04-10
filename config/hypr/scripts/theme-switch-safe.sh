#!/usr/bin/env bash
set -euo pipefail

SCRIPT_REALPATH="$(readlink -f "${BASH_SOURCE[0]}")"
REPO_ROOT="$(cd "$(dirname "$SCRIPT_REALPATH")/../../.." && pwd)"

SWITCH_FALLBACK="$REPO_ROOT/config/shared/scripts/kingstra-theme-switch"
READER_FALLBACK="$REPO_ROOT/config/shared/scripts/kingstra-theme-read.py"
ACTIVE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/active-theme"
THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/themes"
THEME_JSON="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/theme.json"

resolve_switch_cmd() {
    if [[ -x "$SWITCH_FALLBACK" ]]; then
        printf '%s\n' "$SWITCH_FALLBACK"
        return 0
    fi

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

    return 1
}

resolve_reader_cmd() {
    if [[ -f "$READER_FALLBACK" ]]; then
        printf '%s\n' "$READER_FALLBACK"
        return 0
    fi

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

    return 1
}

SWITCH_CMD="$(resolve_switch_cmd || true)"
if [[ -z "$SWITCH_CMD" ]]; then
    notify-send "Theme" "Geen kingstra-theme-switch commando gevonden" 2>/dev/null || true
    exit 1
fi

if [[ "${1:-}" == "--current" ]]; then
    # UI source of truth: theme.json reflects what Quickshell actually renders now.
    if command -v jq >/dev/null 2>&1 && [[ -f "$THEME_JSON" ]]; then
        current="$(jq -r '.theme // empty' "$THEME_JSON" 2>/dev/null || true)"
        if [[ -n "$current" ]]; then
            printf '%s\n' "$current"
            exit 0
        fi
    fi

    current="$("$SWITCH_CMD" --current 2>/dev/null || true)"

    if [[ -z "$current" ]]; then
        current="$(cat "$ACTIVE_FILE" 2>/dev/null || true)"
    fi

    printf '%s\n' "${current:-}"
    exit 0
fi

if [[ "${1:-}" == "--list" ]]; then
    if [[ ! -d "$THEMES_DIR" ]]; then
        echo "[]"
        exit 0
    fi

    READER_CMD="$(resolve_reader_cmd || true)"
    if [[ -n "$READER_CMD" ]]; then
        if [[ "$READER_CMD" == *.py ]]; then
            python3 "$READER_CMD" --list "$THEMES_DIR" 2>/dev/null || echo "[]"
            exit 0
        fi
        "$READER_CMD" --list "$THEMES_DIR" 2>/dev/null || echo "[]"
        exit 0
    fi
    echo "[]"
    exit 0
fi

THEME_NAME="${1:?Usage: theme-switch-safe.sh [--current|--list|<theme>]}"
exec "$SWITCH_CMD" "$THEME_NAME"
