#!/usr/bin/env bash
# Vangt eigen QML-properties die een FINAL-property van Item overschrijven.
# Qt weigert dan het hele bestand ("Cannot override FINAL property"), en via
# ShellSurface laadt TopBar.qml niet: de shell start niet
# (2026-10: KingstraIsland had "property bool right" in een Canvas).
# De namen komen uit qquickitem.h (Qt 6.10); ze bestaan op elk Item.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FINAL='activeFocus|activeFocusOnTab|anchors|baseline|bottom|childrenRect|focus|height|horizontalCenter|layer|left|opacity|parent|right|top|transform|verticalCenter|visible|width|x|y|z'

hits="$(grep -rnE "^\s*(readonly\s+|required\s+|default\s+)*property\s+[A-Za-z_.<>]+\s+($FINAL)\s*(:|$|;)" \
    --include='*.qml' "$ROOT/config" || true)"

if [[ -n "$hits" ]]; then
    printf '%s\n' "$hits" | sed "s|^$ROOT/|FOUT: |; s|$| (FINAL-property van Item, kies een andere naam)|"
    exit 1
fi
echo "ok: geen QML-property overschrijft een FINAL-property van Item"
