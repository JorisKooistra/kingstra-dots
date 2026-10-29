#!/usr/bin/env python3
"""Rail-indeling per thema: volgorde, tweede rail, werkruimtes en eigen apps.

Bewaard in ~/.local/state/kingstra/rail-layout.json. De shell (RailLayout.qml)
leest het bestand; schrijven loopt via dit script, zodat elke wijziging
gecontroleerd en atomisch landt.

  rail-layout.py status
  rail-layout.py set <thema> <json>   # {"main": [...], "second": [...], "workspaces": 8, "rail": "on"}
  rail-layout.py reset <thema>
  rail-layout.py apps <json>          # [{"id": "...", "name": "...", "icon": "...", "command": "..."}]
"""
import fcntl
import json
import os
from pathlib import Path
import re
import sys
import tempfile

STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "kingstra"
FILE = STATE / "rail-layout.json"
THEMES = {"organic", "neon", "paper", "mono", "mono-accent"}
# Houd gelijk met RailLayout.qml (known/repeatable).
ITEMS = {"launcher", "workspaces", "specials", "overview", "notifications", "system", "updates",
         "games", "pins", "more", "tray", "audio", "status", "clock", "power", "settings"}
REPEATABLE = {"gap", "fill"}
APP_ID = re.compile(r"^[a-z0-9][a-z0-9-]{0,31}$")


def load():
    try:
        data = json.loads(FILE.read_text())
    except FileNotFoundError:
        data = {}
    if not isinstance(data, dict):
        raise ValueError("Ongeldige rail-indeling; het bestand is niet overschreven")
    data.setdefault("version", 1)
    if not isinstance(data.get("themes"), dict):
        data["themes"] = {}
    if not isinstance(data.get("apps"), list):
        data["apps"] = []
    return data


def app_ids(data):
    return {a["id"] for a in data["apps"] if isinstance(a, dict) and "id" in a}


def check_list(value, apps, seen):
    if not isinstance(value, list) or len(value) > 64:
        raise ValueError("Ongeldige railvolgorde")
    for item in value:
        if not isinstance(item, str):
            raise ValueError("Ongeldige railvolgorde")
        if item in REPEATABLE:
            continue
        if item.startswith("app:"):
            if item[4:] not in apps:
                raise ValueError("Onbekende app: " + item[4:])
        elif item not in ITEMS:
            raise ValueError("Onbekend railonderdeel: " + item)
        if item in seen:
            raise ValueError("Onderdeel staat twee keer in de rail: " + item)
        seen.add(item)


def check_theme(value, apps):
    if not isinstance(value, dict):
        raise ValueError("Indeling verwacht")
    out = {}
    seen = set()
    for side in ("main", "second", "hidden"):
        if side in value:
            check_list(value[side], apps, seen)
            out[side] = value[side]
    if "workspaces" in value:
        count = value["workspaces"]
        if type(count) is not int or not 1 <= count <= 10:
            raise ValueError("Aantal werkruimtes moet tussen 1 en 10 liggen")
        out["workspaces"] = count
    if "rail" in value:
        if value["rail"] not in ("theme", "on", "off"):
            raise ValueError("Rail: theme, on of off")
        if value["rail"] != "theme":
            out["rail"] = value["rail"]
    return out


def check_apps(value):
    if not isinstance(value, list) or len(value) > 32:
        raise ValueError("Ongeldige applijst")
    out, seen = [], set()
    for app in value:
        if not isinstance(app, dict):
            raise ValueError("Ongeldige app")
        entry = {k: str(app.get(k, "")).strip() for k in ("id", "name", "icon", "command")}
        if not APP_ID.match(entry["id"]) or entry["id"] in seen:
            raise ValueError("Ongeldige app-id: " + entry["id"])
        if not entry["command"] or len(entry["command"]) > 512:
            raise ValueError("Een app heeft een commando nodig")
        if not entry["name"]:
            entry["name"] = entry["id"]
        entry["name"] = entry["name"][:40]
        entry["icon"] = entry["icon"][:8]
        seen.add(entry["id"])
        out.append(entry)
    return out


def drop_apps(data, keep):
    """Haal verwijderde apps ook uit elke opgeslagen indeling."""
    for layout in data["themes"].values():
        for side in ("main", "second", "hidden"):
            if isinstance(layout.get(side), list):
                layout[side] = [i for i in layout[side] if not i.startswith("app:") or i[4:] in keep]


def change(data, command, args):
    if command == "set":
        theme, raw = args
        if theme not in THEMES:
            raise ValueError("Onbekend thema")
        data["themes"][theme] = check_theme(json.loads(raw), app_ids(data))
    elif command == "reset":
        theme = args[0]
        if theme not in THEMES:
            raise ValueError("Onbekend thema")
        data["themes"].pop(theme, None)
    elif command == "apps":
        data["apps"] = check_apps(json.loads(args[0]))
        drop_apps(data, app_ids(data))
    else:
        raise ValueError("Onbekende railactie")


def mutate(command, args):
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "rail-layout.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = load()
        change(data, command, args)
        fd, temporary = tempfile.mkstemp(prefix="rail-layout.", dir=STATE)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(data, stream, indent=2, ensure_ascii=False)
                stream.write("\n")
            os.replace(temporary, FILE)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    return data


if __name__ == "__main__":
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else "status"
        data = load() if command == "status" else mutate(command, sys.argv[2:])
        print(json.dumps(data, ensure_ascii=False))
    except (OSError, ValueError, IndexError, TypeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
