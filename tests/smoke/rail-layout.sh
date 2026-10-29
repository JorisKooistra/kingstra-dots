#!/usr/bin/env bash
# Rail-indeling: opslagscript (validatie) en de editor (slepen) offline.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
HELPER=config/quickshell/settings/rail-layout.py

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_STATE_HOME="$tmp/state"

python3 "$HELPER" status >/dev/null
python3 "$HELPER" apps '[{"id":"firefox","name":"Firefox","icon":"firefox","command":"firefox"}]' >/dev/null
python3 "$HELPER" set neon '{"main":["launcher","app:firefox","fill","clock"],"second":["workspaces"],"workspaces":5,"rail":"on"}' >/dev/null
if python3 "$HELPER" set neon '{"main":["launcher","launcher"]}' 2>/dev/null; then
    echo "fout: dubbel onderdeel werd geaccepteerd" >&2; exit 1
fi
if python3 "$HELPER" set neon '{"workspaces":11}' 2>/dev/null; then
    echo "fout: 11 werkruimtes werd geaccepteerd" >&2; exit 1
fi
python3 "$HELPER" apps '[]' | python3 -c '
import json, sys
d = json.load(sys.stdin)
assert d["themes"]["neon"]["main"] == ["launcher", "fill", "clock"], d
assert d["themes"]["neon"]["second"] == ["workspaces"], d
'
echo "ok: rail-layout.py bewaart, controleert en ruimt verwijderde apps op"

runner=/usr/lib/qt6/bin/qmltestrunner
if [[ ! -x "$runner" ]]; then
    echo "overgeslagen: qmltestrunner ontbreekt (qt6-declarative-dev-tools)"
    exit 0
fi
app="$tmp/app"
mkdir -p "$app/settings"
cp tests/smoke/rail-layout/{qmldir,ThemeConfig.qml,MatugenColors.qml,tst_rail-layout.qml} "$app/"
cp config/quickshell/RailLayout.qml "$app/"
cp config/quickshell/settings/RailLayoutPage.qml "$app/settings/"
QT_QPA_PLATFORM=offscreen "$runner" -import tests/smoke/rail-layout/stubs -input "$app/tst_rail-layout.qml" -o -,txt
