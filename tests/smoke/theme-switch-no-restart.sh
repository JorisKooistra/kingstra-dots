#!/usr/bin/env bash
# The theme picker runs inside Quickshell. Anything on the switch path that
# restarts or kills Quickshell tears the picker down mid-switch (stappen 10.1).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

switch_path=(
    "$REPO_ROOT/config/hypr/scripts/theme-switch-safe.sh"
    "$REPO_ROOT/config/shared/scripts/kingstra-theme-switch"
    "$REPO_ROOT/config/shared/scripts/apply-shell-state"
    "$REPO_ROOT/config/shared/scripts/kingstra-matugen-run"
    "$REPO_ROOT/config/shared/scripts/kingstra-session-update"
    "$REPO_ROOT/config/shared/scripts/kingstra-state-write"
)

# Only executable lines matter; comments may explain why no restart happens.
if grep -nE '^[[:space:]]*[^#[:space:]].*(kingstra-session-start|restart-shell|(pkill|killall)[^|;&]*quickshell|quickshell[^|;&]*--?(replace|kill))' \
        "${switch_path[@]}"; then
    printf 'Theme switch path restarts Quickshell; the picker would die mid-switch\n' >&2
    exit 1
fi

# Quickshell hot-reloads when a QML/JS file it loaded changes. The switch may
# only publish runtime data (json) into the Quickshell config directory.
if grep -nE 'quickshell/[^"[:space:]]*\.(qml|js)\b' "${switch_path[@]}" \
        | grep -vE ':[[:space:]]*#'; then
    printf 'Theme switch path writes QML/JS into the Quickshell config\n' >&2
    exit 1
fi

printf 'Theme switch no-restart smoke test: OK\n'
