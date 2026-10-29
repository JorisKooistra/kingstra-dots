#!/usr/bin/env bash
# Vangt typen die alleen werken als hun map een qmldir heeft.
# Quickshell maakt die qmldir alleen voor mappen die een gescand bestand
# importeert (import "../map"); een bestand dat via een LazyLoader-pad wordt
# geladen ziet de andere bestanden in zijn eigen map dan niet als type.
# (2026-10: desktop/DesktopWidgets.qml gebruikte VinylStage uit desktop/ →
# "VinylStage is not a type", klok en mediakaart weg.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QS="$ROOT/config/quickshell"

python3 - "$QS" <<'PY'
import os, re, sys
qs = os.path.realpath(sys.argv[1])
files = []
for d, _, names in os.walk(qs):
    files += [os.path.join(d, n) for n in names if n.endswith(".qml")]
imported = {qs}
for f in files:
    for m in re.finditer(r'^import\s+"([^"]+)"', open(f, encoding="utf-8").read(), re.M):
        target = os.path.realpath(os.path.join(os.path.dirname(f), m.group(1)))
        if os.path.isdir(target):
            imported.add(target)
fail = False
for f in files:
    d = os.path.realpath(os.path.dirname(f))
    if d in imported:
        continue
    local = {n[:-4] for n in os.listdir(d) if n.endswith(".qml") and n[0].isupper()}
    text = open(f, encoding="utf-8").read()
    own = os.path.basename(f)[:-4]
    for t in sorted(local - {own}):
        if re.search(r'(^|[\s:])' + t + r'\s*\{', text, re.M):
            print(f"FOUT: {os.path.relpath(f, qs)} gebruikt {t} uit dezelfde map, maar geen bestand importeert die map")
            fail = True
sys.exit(1 if fail else 0)
PY
echo "ok: geen typen uit mappen zonder qmldir"
