#!/usr/bin/env bash
# Miniatuur van één venster voor de werkvlakkaart.
#   werkvlak-thumb.sh <adres-hex> "<x>,<y> <b>x<h>"
# Wordt vanuit de ruimtelijke layout aangeroepen voor vensters die helemaal in
# beeld staan; de kaart toont het plaatje als het venster buiten beeld is.
set -euo pipefail

address="${1:-}"
geometry="${2:-}"
[[ "$address" =~ ^[0-9a-f]{1,16}$ ]] || exit 1
[[ "$geometry" =~ ^-?[0-9]+,-?[0-9]+\ ([0-9]+)x[0-9]+$ ]] || exit 1
width="${BASH_REMATCH[1]}"
command -v grim >/dev/null 2>&1 || exit 0

dir="${XDG_RUNTIME_DIR:-/tmp}/kingstra-thumbs"
mkdir -p "$dir"
# Klein houden: hooguit 640 pixels breed.
scale="$(awk -v w="$width" 'BEGIN { s = (w > 0) ? 640 / w : 1; if (s > 1) s = 1; printf "%.3f", s }')"
tmp="$dir/.$address.$$.jpg"
if grim -s "$scale" -t jpeg -q 75 -g "$geometry" "$tmp" 2>/dev/null; then
    mv -f "$tmp" "$dir/$address.jpg"
else
    rm -f "$tmp"
fi
# Plaatjes van vensters die al een dag niet in beeld waren opruimen.
find "$dir" -maxdepth 1 -name '*.jpg' -mmin +1440 -delete 2>/dev/null || true
