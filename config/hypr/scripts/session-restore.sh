#!/usr/bin/env bash
# Sessie hervatten, zoals macOS en Windows: na het inloggen komen je apps
# terug op de werkruimte waar ze stonden.
#
#   session-restore.sh run       bij het starten: eerst terugzetten, dan elke
#                                twee minuten de stand opslaan (blijft draaien)
#   session-restore.sh save      nu opslaan
#   session-restore.sh restore   nu terugzetten
#   session-restore.sh status    wat er opgeslagen is
#
# Stand: ~/.local/state/kingstra/session.json. Uitzetten met
# `kingstra sessie uit` (schrijft "restore": false naar session-settings.json).
# Apps die Kingstra zelf start (shell, Spotify/Discord-scratchpads via
# autostart, ...) en vensters zonder herkenbaar programma worden overgeslagen.
set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kingstra"
SESSION_FILE="$STATE_DIR/session.json"
SETTINGS_FILE="$STATE_DIR/session-settings.json"
INTERVAL=120
MAX_AGE_DAYS=7

hypr() { "${HYPRCTL_BIN:-hyprctl}" "$@"; }

enabled() {
    [[ -f "$SETTINGS_FILE" ]] || return 0
    python3 -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1])).get("restore", True) else 1)' "$SETTINGS_FILE" 2>/dev/null
}

save() {
    mkdir -p "$STATE_DIR"
    hypr clients -j 2>/dev/null | python3 -c '
import json, os, sys, time

SKIP_CLASSES = {"org.quickshell", "quickshell", "xdg-desktop-portal-gtk", "polkit-gnome-authentication-agent-1",
                "hyprpolkitagent", "org.kde.polkit-kde-authentication-agent-1", "", "steam_proton"}
SKIP_EXE = {"quickshell", "qs", "Hyprland", "hyprland", "bash", "sh", "zsh", "fish", "python3", "python"}

clients = json.load(sys.stdin)
apps, seen = [], set()
for c in sorted(clients, key=lambda c: c.get("focusHistoryID", 99)):
    pid = c.get("pid", -1)
    cls = c.get("class", "") or c.get("initialClass", "")
    ws = c.get("workspace", {}) or {}
    if pid <= 0 or pid in seen or cls in SKIP_CLASSES or ws.get("id", 0) <= 0:
        continue
    try:
        raw = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
        argv = [a.decode("utf-8", "replace") for a in raw if a]
    except OSError:
        continue
    if not argv or os.path.basename(argv[0]) in SKIP_EXE:
        continue
    # Flatpak-apps: start opnieuw via flatpak run, niet via de sandbox-binary.
    if os.path.exists(f"/proc/{pid}/root/.flatpak-info"):
        try:
            for line in open(f"/proc/{pid}/root/.flatpak-info"):
                if line.startswith("name="):
                    argv = ["flatpak", "run", line.split("=", 1)[1].strip()]
                    break
        except OSError:
            pass
    seen.add(pid)
    apps.append({"class": cls, "workspace": ws.get("name") or str(ws.get("id")), "argv": argv,
                 "floating": bool(c.get("floating"))})

if not apps:
    sys.exit(3)  # niets opslaan: geen vensters (bijvoorbeeld tijdens afsluiten)
print(json.dumps({"saved": int(time.time()), "apps": apps}))
' >"$SESSION_FILE.tmp" && mv -f "$SESSION_FILE.tmp" "$SESSION_FILE"
    rm -f "$SESSION_FILE.tmp"
}

restore() {
    [[ -f "$SESSION_FILE" ]] || return 0
    local running
    running="$(hypr clients -j 2>/dev/null || echo '[]')"
    python3 - "$SESSION_FILE" "$MAX_AGE_DAYS" "$running" <<'PY' | while IFS= read -r line; do
import json, shlex, sys, time
data = json.load(open(sys.argv[1]))
if time.time() - data.get("saved", 0) > int(sys.argv[2]) * 86400:
    sys.exit(0)
already = {c.get("class", "") for c in json.loads(sys.argv[3] or "[]")}
done = set()
for app in data.get("apps", []):
    key = app.get("class", "")
    if key in already or key in done:
        continue
    done.add(key)
    cmd = " ".join(shlex.quote(a) for a in app.get("argv", []))
    if not cmd:
        continue
    ws = str(app.get("workspace", "")).replace('"', "")
    # Eén regel Lua per app: start op de juiste werkruimte, zonder te springen.
    lua_cmd = cmd.replace("\\", "\\\\").replace('"', '\\"')
    print(f'hl.exec_cmd("{lua_cmd}", {{ workspace = "{ws} silent" }})')
PY
        hypr eval "$line" >/dev/null 2>&1 || true
        sleep 0.3
    done
}

case "${1:-run}" in
    run)
        if enabled; then
            # Even wachten tot autostart en de shell klaar zijn, zodat apps
            # die zelf al opstarten niet dubbel komen.
            sleep 4
            restore
        fi
        while true; do
            sleep "$INTERVAL"
            enabled && save
        done
        ;;
    save) save ;;
    restore) restore ;;
    status)
        if [[ -f "$SESSION_FILE" ]]; then
            python3 - "$SESSION_FILE" <<'PY'
import json, sys, time
d = json.load(open(sys.argv[1]))
print(f"Opgeslagen {int((time.time() - d.get('saved', 0)) / 60)} min geleden:")
for a in d.get("apps", []):
    print(f"  werkruimte {a['workspace']}: {a['class']}")
PY
        else
            echo "Nog niets opgeslagen."
        fi
        enabled && echo "Hervatten staat aan." || echo "Hervatten staat uit."
        ;;
    *)
        echo "gebruik: session-restore.sh run|save|restore|status" >&2
        exit 2
        ;;
esac
