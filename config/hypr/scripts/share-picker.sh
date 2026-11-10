#!/usr/bin/env bash
# Kiezer voor scherm delen (custom_picker_binary van xdg-desktop-portal-hyprland).
# XDPH start dit als een app wil delen en leest één regel "[SELECTION]…" van
# stdout. Wij zetten de keuzes klaar in /tmp/kingstra-share-request.json, openen
# het paneel "share" in de shell en wachten op het antwoord. Draait de shell
# niet, dan valt dit terug op de gewone hyprland-share-picker.
set -uo pipefail

REQ=/tmp/kingstra-share-request.json
ANS=/tmp/kingstra-share-answer
SCRIPTS="$HOME/.config/hypr/scripts"

fallback() {
    if command -v hyprland-share-picker >/dev/null 2>&1; then
        exec hyprland-share-picker "$@"
    fi
    exit 1
}

pgrep -f 'quickshell.*TopBar.qml' >/dev/null 2>&1 || fallback "$@"

allow_token=false
for arg in "$@"; do [[ "$arg" == "--allow-token" ]] && allow_token=true; done

python3 - "$REQ.tmp" <<'PY' || fallback "$@"
import json, os, subprocess, sys

def split(value, sep):
    return [p for p in value.split(sep) if p]

windows = []
for entry in split(os.environ.get("XDPH_WINDOW_SHARING_LIST", ""), "[HA>]"):
    try:
        handle, rest = entry.split("[HC>]", 1)
        cls, rest = rest.split("[HT>]", 1)
        title, addr = rest.split("[HE>]", 1)
    except ValueError:
        continue
    try:
        address = "0x%x" % int(addr) if addr.strip() not in ("", "0") else ""
    except ValueError:
        address = ""
    windows.append({"handle": handle.strip(), "className": cls, "title": title, "address": address})

workspaces = []
mode = ""
v2 = os.environ.get("XDPH_WORKSPACE_SHARING_LIST_V2", "")
if v2:
    mode = "id"
    rest = v2
    while rest:
        try:
            length, rest = rest.split(":", 1)
            n = int(length)
            name, rest = rest[:n], rest[n + 1:]
            wid, rest = rest.split(";", 1)
            workspaces.append({"key": "workspace-id:" + wid, "name": name})
        except ValueError:
            break
else:
    legacy = split(os.environ.get("XDPH_WORKSPACE_SHARING_LIST", ""), "[HN>]")
    if legacy:
        mode = "name"
        workspaces = [{"key": "workspace:" + n, "name": n} for n in legacy]

# Alleen gewone werkruimtes; speciale (kladblok, geparkeerd) horen er niet bij.
workspaces = [w for w in workspaces if not w["name"].startswith("special")]
workspaces.sort(key=lambda w: (not w["name"].isdigit(), int(w["name"]) if w["name"].isdigit() else 0, w["name"]))

screens = []
try:
    out = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=3).stdout
    for m in json.loads(out or "[]"):
        screens.append({"name": m.get("name", ""), "description": m.get("description", ""),
                        "width": m.get("width", 0), "height": m.get("height", 0),
                        "focused": bool(m.get("focused"))})
except (OSError, ValueError, subprocess.SubprocessError):
    pass

with open(sys.argv[1], "w") as fh:
    json.dump({"screens": screens, "workspaces": workspaces, "workspaceMode": mode,
               "windows": windows, "time": int(__import__("time").time() * 1000)}, fh)
PY
mv -f "$REQ.tmp" "$REQ"
rm -f "$ANS"

bash "$SCRIPTS/qs_manager.sh" open share >/dev/null 2>&1

# Wachten op het paneel (max. 2 minuten). Annuleren schrijft "cancel".
for _ in $(seq 1 1200); do
    [[ -s "$ANS" ]] && break
    sleep 0.1
done
answer=$(cat "$ANS" 2>/dev/null)
rm -f "$ANS" "$REQ"

case "$answer" in
    screen:*|window:*|workspace:*|workspace-id:*|region:*)
        flags=""
        $allow_token && flags="r"
        printf '[SELECTION]%s/%s\n' "$flags" "$answer"
        ;;
    *)
        exit 0
        ;;
esac
