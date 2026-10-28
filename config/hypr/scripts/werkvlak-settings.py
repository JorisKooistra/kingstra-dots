#!/usr/bin/env python3
"""Instellingen voor scrollen en het ruimtelijk werkvlak.

    werkvlak-settings.py get                 alle waarden als JSON
    werkvlak-settings.py set SLEUTEL WAARDE  bewaren en meteen toepassen

column_width   breedte van een nieuwe kolom op een scrollstrook (0.333-1.0)
max_per_cell   hoeveel vensters als tegels op één plek staan (1-4)
snap           hoe snel slepen op een plek vastklikt (0 = nooit, 0.45 = bijna altijd)

Bewaard in ~/.config/kingstra/werkvlak.json. Hyprland leest het bestand bij het
laden (config.lua, spatial/init.lua); `set` past de draaiende sessie direct aan.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "kingstra" / "werkvlak.json"
HYPR = os.environ.get("HYPRCTL_BIN", "hyprctl")
DEFAULTS = {"column_width": 1.0, "max_per_cell": 4, "snap": 0.2}
LIMITS = {"column_width": (0.333, 1.0, float), "max_per_cell": (1, 4, int), "snap": (0.0, 0.45, float)}


def load():
    data = dict(DEFAULTS)
    try:
        saved = json.loads(CONFIG.read_text())
    except (OSError, ValueError):
        saved = {}
    if isinstance(saved, dict):
        for key, (low, high, kind) in LIMITS.items():
            try:
                data[key] = min(high, max(low, kind(saved.get(key, data[key]))))
            except (TypeError, ValueError):
                pass
    return data


def store(data):
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=CONFIG.name + ".", dir=str(CONFIG.parent))
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, indent=2)
            stream.write("\n")
        os.replace(tmp, CONFIG)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def apply_live(key, value):
    if key == "column_width":
        code = "hl.config({ scrolling = { column_width = %s } })" % value
    else:
        code = ('local c = rawget(_G, "__kingstra_spatial_config"); if c then c.%s = %s end' % (key, value))
    try:
        subprocess.run([HYPR, "eval", code], capture_output=True, timeout=5, check=False)
    except (OSError, subprocess.SubprocessError):
        pass


def main(args):
    command = args[0] if args else "get"
    if command == "get":
        print(json.dumps(load()))
        return 0
    if command == "set" and len(args) == 3:
        key, raw = args[1], args[2]
        if key not in LIMITS:
            raise ValueError("Onbekende instelling: " + key)
        low, high, kind = LIMITS[key]
        value = kind(float(raw)) if kind is int else kind(raw)
        if not low <= value <= high:
            raise ValueError("%s moet tussen %s en %s liggen" % (key, low, high))
        data = load()
        data[key] = value
        store(data)
        apply_live(key, value)
        print(json.dumps(data))
        return 0
    raise ValueError("Gebruik: werkvlak-settings.py get | set SLEUTEL WAARDE")


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError) as error:
        print("Werkvlak: " + str(error), file=sys.stderr)
        sys.exit(1)
