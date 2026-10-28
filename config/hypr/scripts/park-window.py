#!/usr/bin/env python3
"""Vensters parkeren (minimaliseren) en terughalen.

    park-window.py park [ADRES]     actief (of opgegeven) venster parkeren   Super+-
    park-window.py restore ADRES    venster terug op zijn eigen werkruimte
    park-window.py last             laatst geparkeerde venster terug          Super+Shift+-
    park-window.py list             geparkeerde vensters als JSON

Een geparkeerd venster staat op de verborgen werkruimte special:geparkeerd,
zoals een geminimaliseerd venster in de taakbalk. De oorspronkelijke
werkruimte en zweefstand worden onthouden in $XDG_RUNTIME_DIR, dus na
opnieuw inloggen begint de lijst leeg (de vensters zelf zijn dan ook weg).
"""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

SPECIAL = "special:geparkeerd"
HYPR = os.environ.get("HYPRCTL_BIN", "hyprctl")
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR") or tempfile.gettempdir())
STATE = RUNTIME / "kingstra-parked.json"
ADDRESS = re.compile(r"0x[0-9a-fA-F]+")


def hypr(*args):
    result = subprocess.run([HYPR, *args], text=True, capture_output=True, timeout=5, check=False)
    text = result.stdout.strip()
    if result.returncode or text.lower().startswith(("error", "invalid", "unknown")):
        raise RuntimeError(result.stderr.strip() or text or "Hyprland niet bereikbaar")
    return text


def query(name):
    return json.loads(hypr(name, "-j") or "null")


def dispatch(expression):
    hypr("dispatch", expression)


def lua(value):
    return json.dumps(str(value))


def load():
    try:
        data = json.loads(STATE.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def store(data):
    fd, tmp = tempfile.mkstemp(prefix="kingstra-parked.", dir=str(RUNTIME))
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream)
        os.replace(tmp, STATE)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def feedback(title, detail):
    # Zelfde kanaal als het kladblok: het eiland toont een korte melding.
    payload = {"token": f"{time.time_ns()}", "icon": "󰘕", "title": title, "detail": detail, "timeout": 2200}
    path = Path("/tmp/kingstra-feedback.json")
    fd, tmp = tempfile.mkstemp(prefix="kingstra-feedback.json.", dir="/tmp")
    with os.fdopen(fd, "w") as stream:
        json.dump(payload, stream)
    os.replace(tmp, path)


def parked_clients():
    """Geparkeerde vensters die nog bestaan, nieuwste eerst."""
    data = load()
    clients = [c for c in query("clients") or [] if (c.get("workspace") or {}).get("name") == SPECIAL]
    live = {c.get("address") for c in clients}
    pruned = {a: v for a, v in data.items() if a in live}
    if pruned != data:
        store(pruned)
    rows = []
    for c in clients:
        info = pruned.get(c.get("address"), {})
        rows.append({
            "address": c.get("address", ""),
            "title": c.get("title") or "Zonder titel",
            "className": c.get("class") or c.get("initialClass") or "App",
            "workspace": info.get("workspace", ""),
            "parkedAt": info.get("parkedAt", 0),
        })
    rows.sort(key=lambda r: r["parkedAt"], reverse=True)
    return rows


def park(address=None):
    if address is None:
        window = query("activewindow") or {}
    else:
        window = next((c for c in query("clients") or [] if c.get("address") == address), {})
    address = window.get("address", "")
    ws = window.get("workspace") or {}
    if not ADDRESS.fullmatch(address) or ws.get("name") == SPECIAL:
        return False
    # Gewone werkruimtes op nummer; benoemde als name:…; specials (kladblok,
    # spotify) bewaren we niet: die gaan bij terughalen naar de huidige.
    name = str(ws.get("name") or "")
    if re.fullmatch(r"[1-9]\d*", name):
        workspace = name
    elif name.startswith("special:"):
        workspace = ""
    elif name:
        workspace = "name:" + name
    else:
        return False
    data = load()
    data[address] = {"workspace": workspace, "floating": bool(window.get("floating")),
                     "parkedAt": time.time()}
    store(data)
    dispatch("hl.dsp.window.move({ workspace = %s, follow = false, window = %s })"
             % (lua(SPECIAL), lua("address:" + address)))
    count = len(data)
    feedback("Venster geparkeerd", "Super+Shift+- haalt het terug" if count == 1 else f"{count} geparkeerd · Super+W toont ze")
    return True


def restore(address):
    if not ADDRESS.fullmatch(address or ""):
        raise ValueError("Ongeldig venster")
    data = load()
    info = data.pop(address, {})
    target = info.get("workspace", "")
    # Bestaat de werkruimte niet meer (bijvoorbeeld een andere special),
    # dan komt het venster op de werkruimte waar je nu bent.
    if not target or target.startswith("special:"):
        target = str((query("activeworkspace") or {}).get("id", "1"))
    store(data)
    dispatch("hl.dsp.window.move({ workspace = %s, follow = true, window = %s })"
             % (lua(target), lua("address:" + address)))
    dispatch("hl.dsp.focus({ window = %s })" % lua("address:" + address))
    return True


def main(args):
    command = args[0] if args else "list"
    if command == "park":
        park(args[1] if len(args) > 1 else None)
    elif command == "restore":
        restore(args[1] if len(args) > 1 else "")
    elif command == "last":
        rows = parked_clients()
        if rows:
            restore(rows[0]["address"])
    elif command == "list":
        print(json.dumps(parked_clients()))
    else:
        raise ValueError("Onbekende actie: " + command)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
