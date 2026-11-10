#!/usr/bin/env python3
"""Telefoon koppelen via KDE Connect, voor het paneel Telefoon.

  phone.py status            JSON met apparaten (naam, bereikbaar, batterij)
  phone.py ring <id>         telefoon laten afgaan ("zoek mijn telefoon")
  phone.py ping <id>         testbericht
  phone.py clipboard <id>    klembord van de pc naar de telefoon
  phone.py share <id> [pad]  bestand sturen (zonder pad: kiezer)
  phone.py pair <id>         koppelen aanvragen
  phone.py app               KDE Connect-instellingen openen

Alles via je eigen netwerk; niets via internet. Meldingen van de telefoon
komen vanzelf in het meldingencentrum, want kdeconnectd stuurt ze als gewone
meldingen. De dienst start pas als iets hem nodig heeft (D-Bus).
"""
import json
import re
import shutil
import subprocess
import sys

BUS = "org.kde.kdeconnect"
ID_RE = re.compile(r"^[A-Za-z0-9_\-]+$")


def run(cmd, timeout=8):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return r.returncode, r.stdout
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def prop(path, iface, name):
    code, out = run(["busctl", "--user", "get-property", BUS, path, iface, name], timeout=3)
    if code != 0:
        return None
    parts = out.strip().split(" ", 1)
    if len(parts) != 2:
        return None
    kind, value = parts
    if kind == "b":
        return value == "true"
    if kind in ("i", "u", "x"):
        try:
            return int(value)
        except ValueError:
            return None
    if kind == "s":
        try:
            return json.loads(value)
        except ValueError:
            return value.strip('"')
    return value


def ids(flag):
    code, out = run(["kdeconnect-cli", flag, "--id-name-only"], timeout=8)
    found = []
    for line in out.splitlines():
        parts = line.strip().split(" ", 1)
        if parts and ID_RE.match(parts[0]):
            found.append((parts[0], parts[1] if len(parts) > 1 else parts[0]))
    return found


def status():
    if not shutil.which("kdeconnect-cli"):
        return {"installed": False, "devices": []}
    reachable = {i for i, _ in ids("-a")}
    devices = []
    for dev_id, name in ids("-l"):
        base = f"/modules/kdeconnect/devices/{dev_id}"
        paired = prop(base, "org.kde.kdeconnect.device", "isPaired")
        if paired is None:
            paired = prop(base, "org.kde.kdeconnect.device", "isTrusted")
        dev = {
            "id": dev_id,
            "name": name,
            "reachable": dev_id in reachable,
            "paired": bool(paired),
            "type": prop(base, "org.kde.kdeconnect.device", "type") or "phone",
            "battery": -1,
            "charging": False,
        }
        if dev["reachable"]:
            charge = prop(base + "/battery", "org.kde.kdeconnect.device.battery", "charge")
            if isinstance(charge, int):
                dev["battery"] = charge
                dev["charging"] = bool(prop(base + "/battery", "org.kde.kdeconnect.device.battery", "isCharging"))
        devices.append(dev)
    devices.sort(key=lambda d: (not d["reachable"], not d["paired"], d["name"].lower()))
    return {"installed": True, "devices": devices}


def pick_file():
    for cmd in (["zenity", "--file-selection", "--title=Bestand naar telefoon"],
                ["kdialog", "--getopenfilename", "."]):
        if shutil.which(cmd[0]):
            code, out = run(cmd, timeout=600)
            return out.strip() if code == 0 else ""
    return ""


def main(args):
    if not args or args[0] == "status":
        print(json.dumps(status()))
        return 0
    action = args[0]
    if action == "app":
        for cmd in (["kdeconnect-app"], ["kdeconnect-settings"]):
            if shutil.which(cmd[0]):
                subprocess.Popen(cmd, start_new_session=True)
                return 0
        return 1
    if len(args) < 2 or not ID_RE.match(args[1]):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    dev = args[1]
    if action == "ring":
        return run(["kdeconnect-cli", "-d", dev, "--ring"])[0]
    if action == "ping":
        return run(["kdeconnect-cli", "-d", dev, "--ping-msg", "Hallo van je pc"])[0]
    if action == "pair":
        return run(["kdeconnect-cli", "-d", dev, "--pair"])[0]
    if action == "clipboard":
        code, _ = run(["kdeconnect-cli", "-d", dev, "--send-clipboard"])
        if code != 0:
            code, _ = run(["busctl", "--user", "call", BUS, f"/modules/kdeconnect/devices/{dev}/clipboard",
                           "org.kde.kdeconnect.device.clipboard", "sendClipboard"])
        return code
    if action == "share":
        path = args[2] if len(args) > 2 else pick_file()
        if not path:
            return 1
        return run(["kdeconnect-cli", "-d", dev, "--share", path], timeout=30)[0]
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
