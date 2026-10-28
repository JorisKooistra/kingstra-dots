#!/usr/bin/env bash
# Indelingen per werkruimte, voor de snap-kiezer (Super+Z) en `kingstra indeling`.
#
# Elke indeling is een gewone Hyprland-layout, dus vensters blijven getegeld:
#   tegels    dwindle (de standaard)
#   50-50     master, hoofdvenster op de helft
#   70-30     master, hoofdvenster 70%
#   midden    master, hoofdvenster in het midden, de rest links en rechts
#   kolommen  scrolling, drie kolommen van een derde
#   scrollen  scrolling, kolommen van de helft: schuif met Super+wiel
#   focus     monocle, één venster tegelijk
#
# De keuze per werkruimte staat in ~/.local/state/kingstra/workspace-layouts.json
# en wordt bij het laden van Hyprland weer toegepast (lua/rules.lua).
#
# Gebruik: layout-tool.sh apply <indeling> [werkruimte]
#          layout-tool.sh main            actief venster wordt het hoofdvenster
#          layout-tool.sh scroll          scrollen aan/uit op deze werkruimte
#          layout-tool.sh current         JSON: {"workspace": "3", "preset": "tegels"}
#          layout-tool.sh list
set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra"
STATE_FILE="$STATE_DIR/workspace-layouts.json"
PRESETS="tegels 50-50 70-30 midden kolommen scrollen focus"

hypr() { "${HYPRCTL_BIN:-hyprctl}" "$@"; }

lua_quote() {
    local value="${1//\\/\\\\}"
    printf '"%s"' "${value//\"/\\\"}"
}

active_workspace() {
    hypr activeworkspace -j | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])'
}

saved_preset() {
    python3 - "$STATE_FILE" "$1" <<'PY'
import json, sys
try:
    print(json.load(open(sys.argv[1])).get(sys.argv[2], "tegels"))
except Exception:
    print("tegels")
PY
}

save_preset() {
    mkdir -p "$STATE_DIR"
    python3 - "$STATE_FILE" "$1" "$2" <<'PY'
import json, os, sys
path, ws, preset = sys.argv[1:4]
try:
    data = json.load(open(path))
except Exception:
    data = {}
if preset == "tegels":
    data.pop(ws, None)
else:
    data[ws] = preset
tmp = path + ".tmp"
json.dump(data, open(tmp, "w"), indent=1, sort_keys=True)
os.replace(tmp, path)
# Platte kopie voor lua/rules.lua: "werkruimte layout" per regel.
layouts = {"50-50": "master", "70-30": "master", "midden": "master",
           "kolommen": "scrolling", "scrollen": "scrolling", "focus": "monocle"}
lines = "".join(f"{w} {layouts[p]}\n" for w, p in sorted(data.items()) if p in layouts)
flat = os.path.join(os.path.dirname(path), "workspace-layouts")
open(flat + ".tmp", "w").write(lines)
os.replace(flat + ".tmp", flat)
PY
}

layout_for() {
    case "$1" in
        tegels) printf 'dwindle' ;;
        50-50|70-30|midden) printf 'master' ;;
        kolommen|scrollen) printf 'scrolling' ;;
        focus) printf 'monocle' ;;
        *) return 1 ;;
    esac
}

dispatch() {
    hypr dispatch "$1" >/dev/null 2>&1 || true
}

apply() {
    local preset="$1" ws="${2:-}" layout
    layout="$(layout_for "$preset")" || { echo "onbekende indeling: $preset ($PRESETS)" >&2; exit 2; }
    [[ -n "$ws" ]] || ws="$(active_workspace)"

    # Een werkruimteregel wisselt de layout direct; Hyprland ververst zelf.
    hypr eval "hl.workspace_rule({ workspace = $(lua_quote "$ws"), layout = $(lua_quote "$layout") })" >/dev/null
    save_preset "$ws" "$preset"

    # De verhouding binnen de layout volgt een tel later, als de nieuwe
    # layout de vensters heeft overgenomen.
    sleep 0.15
    case "$preset" in
        50-50)    dispatch 'hl.dsp.layout("orientationleft")'; dispatch 'hl.dsp.layout("mfact exact 0.5")' ;;
        70-30)    dispatch 'hl.dsp.layout("orientationleft")'; dispatch 'hl.dsp.layout("mfact exact 0.7")' ;;
        midden)   dispatch 'hl.dsp.layout("orientationcenter")'; dispatch 'hl.dsp.layout("mfact exact 0.5")' ;;
        kolommen) dispatch 'hl.dsp.layout("colresize all 0.333")' ;;
        scrollen) dispatch 'hl.dsp.layout("colresize all 0.5")' ;;
    esac
    feedback "$preset"
}

feedback() {
    local label
    case "$1" in
        tegels) label="Tegels" ;;
        50-50) label="50 | 50" ;;
        70-30) label="70 | 30" ;;
        midden) label="Midden groot" ;;
        kolommen) label="Drie kolommen" ;;
        scrollen) label="Scrollen" ;;
        focus) label="Eén tegelijk" ;;
    esac
    local token tmp
    token="$(date +%s%3N)$RANDOM"
    tmp="$(mktemp /tmp/kingstra-feedback.json.XXXXXX)" || return 0
    printf '{"token":"%s","icon":"󰕰","title":"Indeling: %s","detail":"Werkruimte %s","timeout":1800}\n' \
        "$token" "$label" "${2:-$(active_workspace)}" >"$tmp"
    mv -f "$tmp" /tmp/kingstra-feedback.json
}

case "${1:-}" in
    apply)
        [[ $# -ge 2 ]] || { echo "gebruik: layout-tool.sh apply <indeling> [werkruimte]" >&2; exit 2; }
        apply "$2" "${3:-}"
        ;;
    main)
        # Master: wissel met het hoofdvenster. Scrolling: zet de kolom vooraan.
        ws="$(active_workspace)"
        case "$(layout_for "$(saved_preset "$ws")")" in
            master) dispatch 'hl.dsp.layout("swapwithmaster")' ;;
            scrolling) dispatch 'hl.dsp.layout("promote")' ;;
        esac
        ;;
    scroll)
        ws="$(active_workspace)"
        if [[ "$(layout_for "$(saved_preset "$ws")")" == "scrolling" ]]; then
            apply tegels "$ws"
        else
            apply scrollen "$ws"
        fi
        ;;
    current)
        ws="$(active_workspace)"
        printf '{"workspace":"%s","preset":"%s"}\n' "$ws" "$(saved_preset "$ws")"
        ;;
    list)
        tr " " "\n" <<<"$PRESETS"
        ;;
    *)
        echo "gebruik: layout-tool.sh apply <indeling> [werkruimte] | main | scroll | current | list" >&2
        exit 2
        ;;
esac
