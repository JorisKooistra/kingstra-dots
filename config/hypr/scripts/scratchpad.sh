#!/usr/bin/env bash
# Kladblok: elk venster kan een scratchpad worden, zoals een Quake-terminal.
#
#   scratchpad.sh toggle   kladblok tonen of verbergen (Super+`)
#   scratchpad.sh send     actief venster naar het kladblok, of terug naar
#                          de huidige werkruimte als het er al in zit
#                          (Super+Shift+`)
#
# Vensters in het kladblok zweven gecentreerd op 70% x 65% van het scherm.
# Spotify en Discord houden hun eigen vaste scratchpads (Super+S, Super+D).
set -euo pipefail

NAME="kladblok"
hypr() { "${HYPRCTL_BIN:-hyprctl}" "$@"; }
dispatch() { hypr dispatch "$1" >/dev/null; }

case "${1:-toggle}" in
    toggle)
        dispatch "hl.dsp.workspace.toggle_special(\"$NAME\")"
        ;;
    send)
        info="$(hypr activewindow -j)"
        read -r addr ws floating mon_w mon_h < <(
            hypr monitors -j | python3 -c '
import json, sys
win = json.loads(sys.argv[1] or "{}")
mons = json.load(sys.stdin)
mon = next((m for m in mons if m.get("id") == win.get("monitor")), mons[0] if mons else {})
scale = mon.get("scale", 1) or 1
print(win.get("address", ""), win.get("workspace", {}).get("name", ""),
      str(win.get("floating", False)).lower(),
      int(mon.get("width", 1920) / scale), int(mon.get("height", 1080) / scale))
' "$info")
        [[ -n "$addr" ]] || exit 0
        win="address:$addr"

        if [[ "$ws" == "special:$NAME" ]]; then
            # Terug naar de gewone werkruimte, weer getegeld.
            target="$(hypr activeworkspace -j | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
            dispatch "hl.dsp.window.move({ workspace = \"$target\", follow = true, window = \"$win\" })"
            dispatch "hl.dsp.window.float({ action = \"disable\", window = \"$win\" })"
            exit 0
        fi

        dispatch "hl.dsp.window.move({ workspace = \"special:$NAME\", follow = false, window = \"$win\" })"
        [[ "$floating" == "true" ]] || dispatch "hl.dsp.window.float({ action = \"enable\", window = \"$win\" })"
        dispatch "hl.dsp.window.resize({ x = $(( mon_w * 70 / 100 )), y = $(( mon_h * 65 / 100 )), relative = false, window = \"$win\" })"
        dispatch "hl.dsp.window.center({ window = \"$win\" })"

        token="$(date +%s%3N)$RANDOM"
        tmp="$(mktemp /tmp/kingstra-feedback.json.XXXXXX)"
        printf '{"token":"%s","icon":"󰠮","title":"Naar het kladblok","detail":"Super+` haalt het terug","timeout":2200}\n' "$token" >"$tmp"
        mv -f "$tmp" /tmp/kingstra-feedback.json
        ;;
    *)
        echo "gebruik: scratchpad.sh toggle|send" >&2
        exit 2
        ;;
esac
