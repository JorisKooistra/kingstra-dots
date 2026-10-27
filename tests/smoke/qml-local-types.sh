#!/usr/bin/env bash
# Vangt een lokaal QML-type dat nog gebruikt wordt terwijl het bestand weg is.
# Quickshell laadt dan het hele TopBar.qml niet en de shell blijft leeg
# (2026-10: VolumePopup.qml verwijderd, VolumeBarPopup gebruikte hem nog).
# Alleen namen die op een eigen-componentachtervoegsel eindigen worden
# gecontroleerd; Qt- en Quickshell-types vallen daar buiten.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QS="$ROOT/config/quickshell"
fail=0

while IFS= read -r -d '' file; do
    dir="$(dirname "$file")"
    # Mappen waarin dit bestand types zoekt: de eigen map plus relatieve imports.
    search=("$dir")
    while IFS= read -r rel; do
        search+=("$dir/$rel")
    done < <(sed -nE 's/^import "([^"]+)".*/\1/p' "$file")

    while IFS= read -r type; do
        grep -qE "^\s*component\s+$type\s*:" "$file" && continue
        found=0
        for d in "${search[@]}"; do
            [[ -f "$d/$type.qml" ]] && { found=1; break; }
        done
        if (( ! found )); then
            echo "FOUT: ${file#"$ROOT"/} gebruikt $type, maar $type.qml bestaat niet"
            fail=1
        fi
    done < <(grep -oE '^\s*[A-Z][A-Za-z0-9]*(Popup|Panel|Module|Pill|Widget|Drawer|Toast)\s*\{' "$file" \
                | sed -E 's/^\s*([A-Za-z0-9]+).*/\1/' | sort -u)
done < <(find "$QS" -name '*.qml' -print0)

if (( fail )); then
    exit 1
fi
echo "ok: alle lokale QML-types bestaan"
