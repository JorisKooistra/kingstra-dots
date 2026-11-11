#!/usr/bin/env python3
"""Telefoon koppelen via KDE Connect, voor het paneel Telefoon.

  phone.py status               JSON met apparaten, batterij, netwerk,
                                meldingen en media (snel, via D-Bus)
  phone.py cached               laatst bekende status (direct, voor openen)
  phone.py refresh              opnieuw zoeken op het netwerk
  phone.py ring <id>            telefoon laten afgaan ("zoek mijn telefoon")
  phone.py ping <id>            testbericht
  phone.py clipboard <id>       klembord van de pc naar de telefoon
  phone.py share <id> [pad]     bestand sturen (zonder pad: kiezer)
  phone.py browse <id>          bestanden van de telefoon openen (sshfs)
  phone.py sms <id> <nr> <txt>  sms sturen
  phone.py messages <id>        berichten-app (kdeconnect-sms) openen
  phone.py media <id> <actie>   PlayPause, Next, Previous
  phone.py volume <id> <0-100>  volume van de telefoon
  phone.py dismiss <id> <nid>   melding wegvegen
  phone.py reply <id> <nid> <t> antwoorden op een melding
  phone.py pair|accept|reject|unpair <id>
  phone.py app                  KDE Connect-instellingen openen
  phone.py zuinig <id>          onderdelen uitzetten die de telefoon onnodig
                                wekken (gebeurt automatisch één keer per telefoon)

Alles via je eigen netwerk; niets via internet. De dienst start pas als iets
hem nodig heeft (D-Bus).
"""
import json
import os
import re
import shutil
import subprocess
import sys

BUS = "org.kde.kdeconnect"
ROOT = "/modules/kdeconnect"
DEV_IFACE = "org.kde.kdeconnect.device"
ID_RE = re.compile(r"^[A-Za-z0-9_\-]+$")
CACHE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "kingstra-phone.json")


def run(cmd, timeout=8):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return r.returncode, r.stdout
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def busctl(*args, timeout=3):
    code, out = run(["busctl", "--user", "--json=short", *args], timeout=timeout)
    if code != 0 or not out.strip():
        return None
    try:
        return json.loads(out)
    except ValueError:
        return None


def call(path, iface, method, sig="", *params, timeout=3):
    args = ["call", BUS, path, iface, method]
    if sig:
        args += [sig, *[str(p) for p in params]]
    res = busctl(*args, timeout=timeout)
    if res is None:
        return None
    data = res.get("data")
    return data[0] if isinstance(data, list) and len(data) == 1 else data


def plain(value):
    # busctl --json geeft varianten als {"type": "i", "data": 80}.
    if isinstance(value, dict) and "type" in value and "data" in value:
        return plain(value["data"])
    if isinstance(value, list):
        return [plain(v) for v in value]
    return value


def get_all(path, iface):
    data = call(path, "org.freedesktop.DBus.Properties", "GetAll", "s", iface)
    if not isinstance(data, dict):
        return {}
    return {k: plain(v) for k, v in data.items()}


def daemon_devices(reachable_only, paired_only):
    data = call(ROOT, "org.kde.kdeconnect.daemon", "deviceNames", "bb",
                "true" if reachable_only else "false", "true" if paired_only else "false")
    if isinstance(data, dict):
        return {k: plain(v) for k, v in data.items() if ID_RE.match(k)}
    return None


def cli_devices():
    # Terugval als de daemon-methode ontbreekt (oudere KDE Connect).
    code, out = run(["kdeconnect-cli", "-l", "--id-name-only"], timeout=8)
    found = {}
    for line in out.splitlines():
        parts = line.strip().split(" ", 1)
        if parts and ID_RE.match(parts[0]):
            found[parts[0]] = parts[1] if len(parts) > 1 else parts[0]
    return found


def notifications(base):
    ids = call(base + "/notifications", "org.kde.kdeconnect.device.notifications", "activeNotifications")
    if not isinstance(ids, list):
        return []
    items = []
    for nid in ids[-12:]:
        nid = str(nid)
        if not ID_RE.match(nid.replace(".", "_").replace(":", "_").replace("|", "_")):
            continue
        p = get_all(f"{base}/notifications/{nid}", "org.kde.kdeconnect.device.notifications.notification")
        if not p:
            continue
        icon = p.get("iconPath") or ""
        items.append({
            "id": nid,
            "app": p.get("appName") or "",
            "title": p.get("title") or "",
            "text": p.get("text") or p.get("ticker") or "",
            "icon": icon if icon and os.path.exists(icon) else "",
            "dismissable": bool(p.get("dismissable", True)),
            "replyable": bool(p.get("replyId")),
        })
    items.reverse()  # nieuwste bovenaan
    return items


def device_info(dev_id, name):
    base = f"{ROOT}/devices/{dev_id}"
    p = get_all(base, DEV_IFACE)
    reachable = bool(p.get("isReachable"))
    pair_state = p.get("pairState")
    paired = bool(p.get("isPaired", pair_state == 3))
    dev = {
        "id": dev_id,
        "name": p.get("name") or name,
        "type": p.get("type") or "phone",
        "reachable": reachable,
        "paired": paired,
        # 1 = wij vroegen koppelen aan, 2 = de telefoon vraagt het.
        "pairRequested": pair_state == 1,
        "pairIncoming": pair_state == 2,
        "verificationKey": p.get("verificationKey") or "",
        "battery": -1,
        "charging": False,
        "network": "",
        "signal": -1,
        "notifications": [],
        "media": None,
        "plugins": [],
    }
    if not (reachable and paired):
        return dev
    plugins = call(base, DEV_IFACE, "loadedPlugins")
    dev["plugins"] = [str(x).replace("kdeconnect_", "") for x in plugins] if isinstance(plugins, list) else []

    bat = get_all(base + "/battery", "org.kde.kdeconnect.device.battery")
    if isinstance(bat.get("charge"), int):
        dev["battery"] = bat["charge"]
        dev["charging"] = bool(bat.get("isCharging"))

    conn = get_all(base + "/connectivity_report", "org.kde.kdeconnect.device.connectivity_report")
    if conn:
        net = str(conn.get("cellularNetworkType") or "")
        dev["network"] = "" if net.lower() in ("unknown", "none", "") else net
        sig = conn.get("cellularNetworkStrength")
        dev["signal"] = sig if isinstance(sig, int) else -1

    dev["notifications"] = notifications(base)

    mp = get_all(base + "/mprisremote", "org.kde.kdeconnect.device.mprisremote")
    if mp and (mp.get("playerList") or mp.get("title")):
        dev["media"] = {
            "player": mp.get("player") or "",
            "title": mp.get("title") or "",
            "artist": mp.get("artist") or "",
            "album": mp.get("album") or "",
            "playing": bool(mp.get("isPlaying")),
            "volume": mp.get("volume") if isinstance(mp.get("volume"), int) else -1,
            "length": mp.get("length") or 0,
            "position": mp.get("position") or 0,
        }
    return dev


# Onderdelen die de telefoon wakker maken voor iets wat we niet gebruiken, of
# die onder Hyprland niet werken (muis/toetsenbord op afstand: geen
# RemoteDesktop-portal, alleen logspam). Meldingen, batterij, klembord (met de
# hand), bestanden, sms, media van de telefoon en zoek-mijn-telefoon blijven.
QUIET_PLUGINS = [
    "sendnotifications",   # elke pc-melding naar de telefoon
    "systemvolume",        # elke volumewijziging van de pc naar de telefoon
    "mpriscontrol",        # elke track/positie van pc-muziek naar de telefoon
    "contacts",            # contacten periodiek synchroniseren
    "runcommand",
    "screensaver_inhibit",
    "mousepad", "remotecontrol", "remotekeyboard", "presenter", "digitizer",
    "shareinputdevices", "shareinputdevicesremote",
]
TUNED_DIR = os.path.join(os.path.expanduser("~"), ".config", "kingstra", "phone")


def set_clipboard_manual(dev_id):
    # Klembord niet meer automatisch bij elke kopie naar de telefoon sturen
    # (wekt hem, en stuurt ook wachtwoorden mee). De tegel Klembord blijft.
    import configparser
    path = os.path.join(os.path.expanduser("~"), ".config", "kdeconnect", dev_id,
                        "kdeconnect_clipboard", "config")
    cfg = configparser.ConfigParser()
    cfg.optionxform = str
    try:
        cfg.read(path, encoding="utf-8")
    except configparser.Error:
        cfg = configparser.ConfigParser()
        cfg.optionxform = str
    if not cfg.has_section("General"):
        cfg.add_section("General")
    cfg.set("General", "autoShare", "false")
    cfg.set("General", "sendPassword", "false")
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            cfg.write(fh, space_around_delimiters=False)
    except OSError:
        return False
    return True


def make_quiet(dev_id):
    base = f"{ROOT}/devices/{dev_id}"
    ok_all = True
    for name in QUIET_PLUGINS:
        if call(base, DEV_IFACE, "setPluginEnabled", "sb", "kdeconnect_" + name, "false") is None:
            ok_all = False
    set_clipboard_manual(dev_id)
    call(base, DEV_IFACE, "reloadPlugins")
    return ok_all


def ensure_quiet(dev_id):
    marker = os.path.join(TUNED_DIR, dev_id + ".zuinig")
    if os.path.exists(marker):
        return
    if make_quiet(dev_id):
        try:
            os.makedirs(TUNED_DIR, exist_ok=True)
            with open(marker, "w", encoding="utf-8") as fh:
                fh.write("\n".join(QUIET_PLUGINS) + "\n")
        except OSError:
            pass


def status():
    if not shutil.which("kdeconnect-cli") and not shutil.which("kdeconnectd") \
            and not os.path.exists("/usr/lib/kdeconnectd"):
        return {"installed": False, "devices": []}
    names = daemon_devices(False, False)
    if names is None:
        names = cli_devices()
    for dev_id in names:
        p = get_all(f"{ROOT}/devices/{dev_id}", DEV_IFACE)
        if p.get("isPaired") and p.get("isReachable"):
            ensure_quiet(dev_id)
    devices = [device_info(i, n) for i, n in names.items()]
    devices.sort(key=lambda d: (not d["reachable"], not d["paired"], d["name"].lower()))
    return {"installed": True, "devices": devices,
            "sshfs": bool(shutil.which("sshfs")),
            "smsApp": bool(shutil.which("kdeconnect-sms"))}


def write_cache(data):
    try:
        tmp = CACHE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(data, fh)
        os.replace(tmp, CACHE)
    except OSError:
        pass


def read_cache():
    try:
        with open(CACHE, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return {"installed": True, "devices": [], "cached": True}
    data["cached"] = True
    return data


def pick_file():
    for cmd in (["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Bestand naar telefoon"],
                ["kdialog", "--getopenfilename", "."]):
        if shutil.which(cmd[0]):
            code, out = run(cmd, timeout=600)
            return [p for p in out.splitlines() if p.strip()] if code == 0 else []
    return []


def popen(cmd):
    try:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return 0
    except OSError:
        return 1


def main(args):
    if not args or args[0] == "status":
        data = status()
        write_cache(data)
        print(json.dumps(data))
        return 0
    action = args[0]
    if action == "cached":
        print(json.dumps(read_cache()))
        return 0
    if action == "refresh":
        call(ROOT, "org.kde.kdeconnect.daemon", "forceOnNetworkChange")
        return 0
    if action == "app":
        for cmd in (["kdeconnect-app"], ["kdeconnect-settings"]):
            if shutil.which(cmd[0]):
                return popen(cmd)
        return 1
    if len(args) < 2 or not ID_RE.match(args[1]):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    dev = args[1]
    base = f"{ROOT}/devices/{dev}"

    def ok(result):
        return 0 if result is not None else 1

    if action == "zuinig":
        return 0 if make_quiet(dev) else 1
    if action == "ring":
        return ok(call(base + "/findmyphone", "org.kde.kdeconnect.device.findmyphone", "ring")) \
            and run(["kdeconnect-cli", "-d", dev, "--ring"])[0]
    if action == "ping":
        return ok(call(base + "/ping", "org.kde.kdeconnect.device.ping", "sendPing", "s", "Hallo van je pc")) \
            and run(["kdeconnect-cli", "-d", dev, "--ping-msg", "Hallo van je pc"])[0]
    if action == "pair":
        return ok(call(base, DEV_IFACE, "requestPairing"))
    if action == "accept":
        return ok(call(base, DEV_IFACE, "acceptPairing"))
    if action == "reject":
        return ok(call(base, DEV_IFACE, "cancelPairing"))
    if action == "unpair":
        return ok(call(base, DEV_IFACE, "unpair"))
    if action == "clipboard":
        code = ok(call(base + "/clipboard", "org.kde.kdeconnect.device.clipboard", "sendClipboard"))
        return code and run(["kdeconnect-cli", "-d", dev, "--send-clipboard"])[0]
    if action == "share":
        paths = args[2:] or pick_file()
        if not paths:
            return 3  # kiezer geannuleerd: geen foutmelding
        code = 0
        for path in paths:
            code |= run(["kdeconnect-cli", "-d", dev, "--share", path], timeout=30)[0]
        return code
    if action == "browse":
        if not shutil.which("sshfs"):
            return 4
        if call(base + "/sftp", "org.kde.kdeconnect.device.sftp", "mountAndWait", timeout=20) is not True:
            return 1
        mount = call(base + "/sftp", "org.kde.kdeconnect.device.sftp", "mountPoint")
        if not mount:
            return 1
        return popen(["xdg-open", str(mount)])
    if action == "messages":
        if shutil.which("kdeconnect-sms"):
            return popen(["kdeconnect-sms", "--device", dev])
        return 1
    if action == "sms":
        if len(args) < 4 or not re.match(r"^[+0-9 ()\-]{3,}$", args[2]) or not args[3].strip():
            return 2
        number = re.sub(r"[ ()\-]", "", args[2])
        return run(["kdeconnect-cli", "-d", dev, "--send-sms", args[3], "--destination", number], timeout=15)[0]
    if action == "media":
        if len(args) < 3 or args[2] not in ("PlayPause", "Play", "Pause", "Next", "Previous", "Stop"):
            return 2
        return ok(call(base + "/mprisremote", "org.kde.kdeconnect.device.mprisremote", "sendAction", "s", args[2]))
    if action == "volume":
        try:
            vol = max(0, min(100, int(float(args[2]))))
        except (IndexError, ValueError):
            return 2
        return run(["busctl", "--user", "set-property", BUS, base + "/mprisremote",
                    "org.kde.kdeconnect.device.mprisremote", "volume", "i", str(vol)], timeout=3)[0]
    if action in ("dismiss", "reply"):
        if len(args) < 3:
            return 2
        nid = args[2]
        if "/" in nid or not nid.strip():
            return 2
        path = f"{base}/notifications/{nid}"
        iface = "org.kde.kdeconnect.device.notifications.notification"
        if action == "dismiss":
            return ok(call(path, iface, "dismiss"))
        if len(args) < 4 or not args[3].strip():
            return 2
        return ok(call(path, iface, "sendReply", "s", args[3]))
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
