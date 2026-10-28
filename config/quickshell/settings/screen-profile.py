#!/usr/bin/env python3
"""Per-display shell preferences. Does not change global power, theme or DND."""
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "kingstra"
FILE = STATE / "screen-profiles.json"
MODULES = {"workspaces", "clock", "updates", "cpu_temp", "gpu_temp", "ram_usage", "fps",
           "network", "battery", "volume", "bluetooth", "notifications", "brightness",
           "media_controls", "game_launcher"}
PINS = {"wifi", "bt", "dnd", "power", "media"}
# Railknoppen die achter Meer kunnen (zie ShellChrome.railTucked).
OVERFLOW = {"notifications", "system", "updates", "games", "pins", "power", "settings"}


def read(path, default):
    try:
        return json.loads(path.read_text())
    except FileNotFoundError:
        return default


def load():
    data = read(FILE, {"version": 1, "screens": {}})
    if not isinstance(data, dict) or not isinstance(data.get("screens"), dict):
        raise ValueError("Ongeldige schermprofielen; het bestand is niet overschreven")
    return data


def monitor_key(monitor):
    serial = str(monitor.get("serial", "")).strip()
    if serial and serial.lower() not in ("0", "unknown", "none"):
        return "device:" + "|".join(str(monitor.get(k, "")) for k in ("make", "model", "serial"))
    # Identical displays without a serial must remain independently selectable.
    return "connector:" + str(monitor["name"])


def monitors():
    result = subprocess.run([os.environ.get("HYPRCTL_BIN", "hyprctl"), "monitors", "-j"],
                            text=True, capture_output=True, timeout=4, check=True)
    out = json.loads(result.stdout)
    for monitor in out:
        monitor["key"] = monitor_key(monitor)
    return out


def presets():
    out = {}
    for file in sorted((CONFIG / "kingstra/modes").glob("*.toml")):
        try:
            data = tomllib.loads(file.read_text())
            out[file.stem] = {"name": file.stem, "modules": data.get("modules", {}).get("list", []),
                              "bar_autohide": data.get("bar", {}).get("autohide", False)}
        except (OSError, ValueError):
            continue
    return out


def status():
    return {"profiles": load(), "monitors": monitors(), "presets": presets(),
            "fallback": read(CONFIG / "kingstra/state/mode.json", {"name": "office"})}


def find_monitor(name):
    return next((m for m in monitors() if m["name"] == name), None)


def change(data, monitor, command, args, available, fallback):
    key = monitor_key(monitor)
    if command == "anchor":
        data["mediaScreen"] = key
        return
    screen = data["screens"].setdefault(key, {"modes": {}})
    screen["lastName"] = monitor["name"]
    if command == "mode":
        mode = args[0]
        if mode == "inherit":
            screen.pop("mode", None)
        elif mode in available:
            screen["mode"] = mode
        else:
            raise ValueError("Onbekende mode")
        return
    if command == "set" and args and args[0] == "wallpaperDrift":
        # Geldt voor het scherm, los van de mode.
        value = json.loads(args[1])
        if type(value) is not bool:
            raise ValueError("Aan/uit verwacht")
        screen["wallpaperDrift"] = value
        return
    mode = screen.get("mode", fallback.get("name", "office"))
    values = screen.setdefault("modes", {})
    if command == "reset":
        values.pop(mode, None)
        return
    if command != "set":
        raise ValueError("Onbekende schermactie")
    field, raw = args
    value = json.loads(raw)
    if field in ("rail.modules", "rail.pins", "rail.overflow"):
        known = {"rail.modules": MODULES, "rail.pins": PINS, "rail.overflow": OVERFLOW}[field]
        if not isinstance(value, list) or any(v not in known for v in value) or len(set(value)) != len(value):
            raise ValueError("Ongeldige modulelijst")
    elif field in ("rail.autohide", "desktopMedia"):
        if type(value) is not bool:
            raise ValueError("Aan/uit verwacht")
    elif field == "nowPlaying":
        if value not in ("auto", "show", "hide"):
            raise ValueError("Ongeldige muziekzichtbaarheid")
    elif field == "playerStyle":
        if value not in ("theme", "vinyl", "cover"):
            raise ValueError("Ongeldige spelerstijl")
    else:
        raise ValueError("Onbekende scherminstelling")
    profile = values.setdefault(mode, {})
    if field.startswith("rail."):
        profile.setdefault("rail", {})[field.split(".")[1]] = value
    else:
        profile[field] = value


def mutate(command, name, args):
    monitor = find_monitor(name)
    if monitor is None:
        raise ValueError("Dit scherm is niet aangesloten")
    STATE.mkdir(parents=True, exist_ok=True)
    with (STATE / "screen-profiles.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = load()
        change(data, monitor, command, args, presets(),
               read(CONFIG / "kingstra/state/mode.json", {"name": "office"}))
        fd, temporary = tempfile.mkstemp(prefix="screen-profiles.", dir=STATE)
        try:
            with os.fdopen(fd, "w") as stream:
                json.dump(data, stream, indent=2)
                stream.write("\n")
            os.replace(temporary, FILE)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)


if __name__ == "__main__":
    try:
        command = sys.argv[1] if len(sys.argv) > 1 else "status"
        if command != "status":
            mutate(command, sys.argv[2], sys.argv[3:])
        print(json.dumps(status()))
    except (OSError, ValueError, IndexError, TypeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
