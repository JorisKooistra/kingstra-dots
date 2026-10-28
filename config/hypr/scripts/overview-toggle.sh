#!/usr/bin/env bash
# The same overview key routes spatial workspaces to their two-axis map.
if python3 "$(dirname "${BASH_SOURCE[0]}")/workspace-layout.py" overview; then
    exit 0
else
    code=$?
    [[ "$code" -eq 3 ]] || exit "$code"
fi
OVERVIEW_QML="$HOME/.config/quickshell/overview/shell.qml"

if ! pgrep -f "qs.*overview/shell.qml" > /dev/null 2>&1; then
    qs --no-duplicate -p "$OVERVIEW_QML" >/dev/null 2>&1 &
    disown
    sleep 0.5
    qs ipc -p "$OVERVIEW_QML" call overview open
else
    qs ipc -p "$OVERVIEW_QML" call overview toggle
fi
