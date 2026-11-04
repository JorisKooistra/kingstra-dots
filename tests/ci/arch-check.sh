#!/usr/bin/env bash
# Draait in een verse Arch-container (CI). Twee dingen die op de laptop en pc
# pas halverwege een update misgaan, vangen we hier vooraf:
#   1. elk pakket dat de installer kan installeren bestaat nog in de Arch-repo's
#      of de AUR (zoals whisper.cpp dat ineens whisper-cpp heette);
#   2. de installer loopt in --dry-run door alle fases, met een pc- en een
#      laptopprofiel, zonder fout.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fail=0

echo "== Pakketten bestaan nog =="
mapfile -t lines < <(python3 "$repo/tests/ci/package-names.py" "$repo")
missing=()
aur_names=()
for line in "${lines[@]}"; do
    src="${line%% *}" name="${line#* }"
    if [[ "$src" == repo ]]; then
        pacman -Si "$name" >/dev/null 2>&1 && continue
        # Een groep (bv. base-devel) of een naam die een ander pakket levert.
        pacman -Sg "$name" >/dev/null 2>&1 && continue
        pacman -Ssq "^${name}$" >/dev/null 2>&1 && continue
        aur_names+=("$name")   # misschien inmiddels in de AUR
    else
        aur_names+=("$name")
    fi
done
if ((${#aur_names[@]})); then
    query="$(printf '&arg[]=%s' "${aur_names[@]}")"
    found="$(curl -fsSL --retry 3 "https://aur.archlinux.org/rpc/v5/info?${query#&}" | python3 -c 'import json,sys; print("\n".join(r["Name"] for r in json.load(sys.stdin)["results"]))')"
    for name in "${aur_names[@]}"; do
        grep -qxF "$name" <<< "$found" || missing+=("$name")
    done
fi
if ((${#missing[@]})); then
    echo "Niet te vinden in de Arch-repo's of de AUR:"
    printf '  %s\n' "${missing[@]}"
    fail=1
else
    echo "Alle ${#lines[@]} pakketten gevonden."
fi

echo "== Installer proefdraai =="
for profile in pc laptop; do
    echo "-- profiel: $profile --"
    override="$(mktemp)"
    if [[ "$profile" == laptop ]]; then
        cat > "$override" <<'CONF'
ENABLE_POWER_PROFILES=true
ENABLE_BRIGHTNESS_CONTROL=true
ENABLE_FINGERPRINT=true
TOUCHPAD_NATURAL_SCROLL=true
CONF
    else
        cat > "$override" <<'CONF'
ENABLE_POWER_PROFILES=false
ENABLE_BRIGHTNESS_CONTROL=false
ENABLE_FINGERPRINT=false
CONF
    fi
    if ! (cd "$repo" && timeout 600 ./install.sh --dry-run --yes --override "$override") > "/tmp/install-$profile.log" 2>&1; then
        echo "Installer-proefdraai ($profile) mislukt; laatste regels:"
        tail -n 60 "/tmp/install-$profile.log"
        fail=1
    else
        grep -E 'WARN|ERROR' "/tmp/install-$profile.log" | head -20 || true
        echo "Installer-proefdraai ($profile) doorlopen."
    fi
done

exit "$fail"
