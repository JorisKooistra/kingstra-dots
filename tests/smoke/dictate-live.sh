#!/usr/bin/env bash
# Dicteren: tik = live meetypen per zin, vasthouden = typen na loslaten.
# Nep-microfoon (spraak/stilte-patroon), nep-whisper en nep-wtype.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'pkill -f "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/rt" "$TMP/data/kingstra/whisper"
cp "$ROOT/tests/smoke/dictate-live/"* "$TMP/bin/"
sed -i "s#/tmp/claude-0/dict/typed.log#$TMP/typed.log#" "$TMP/bin/wtype"
chmod +x "$TMP/bin/"*
touch "$TMP/data/kingstra/whisper/ggml-small-q5_1.bin"
export PATH="$TMP/bin:$PATH" HOME="$TMP" XDG_RUNTIME_DIR="$TMP/rt" XDG_DATA_HOME="$TMP/data"
D="$ROOT/config/shared/scripts/kingstra-dictate"

# Live: na de eerste zin (spraak 0,5–2,0 s) moet er al getypt zijn vóór 3,5 s.
"$D" start; sleep 0.2; "$D" stop
sleep 3.3
[[ -s "$TMP/typed.log" ]] || { echo "FAIL: live typte niets tijdens het praten"; exit 1; }
"$D" start; "$D" stop
grep -q "uit" "$XDG_RUNTIME_DIR/kingstra-dictate.json" || { echo "FAIL: status niet uit"; exit 1; }

# Vasthouden: niets typen vóór loslaten, daarna alles.
rm -f "$TMP/typed.log"
"$D" start; sleep 4
[[ ! -s "$TMP/typed.log" ]] || { echo "FAIL: typte terwijl Super+H nog vast zat"; exit 1; }
"$D" stop
[[ "$(wc -l < "$TMP/typed.log")" -ge 1 ]] || { echo "FAIL: na loslaten niets getypt"; exit 1; }
echo "Dicteren live smoke test: OK"
