#!/usr/bin/python3 -I
"""Pas de opgeslagen schermindeling toe op SDDM's eigen X-server.

Alleen data wordt uit de usersessie gelezen; geen shellcode/eval. EDID-serienummers
houden de mapping intact als Xorg en Hyprland andere connectornamen gebruiken.
"""
import json
from pathlib import Path
import re
import subprocess
import sys

PROFILE = Path("/usr/share/sddm/themes/kingstra/displays.json")


def edid_ids(data):
    """Alle serienummers die Hyprland voor dit scherm kan tonen.

    Hyprland (libdisplay-info) geeft de serie-tekst uit de EDID-descriptor, of
    als die ontbreekt het getal uit de EDID-kop als "0x%08X".
    """
    ids = []
    for offset in (54, 72, 90, 108):
        block = data[offset:offset + 18]
        if block[:5] == b"\0\0\0\xff\0":
            text = block[5:18].decode("ascii", errors="ignore").strip()
            if text:
                ids.append(text)
    if len(data) >= 16:
        number = int.from_bytes(data[12:16], "little")
        if number:
            ids.append(f"0x{number:08X}")
    return ids


def outputs_from_xrandr(text):
    """Aangesloten X-uitgangen met hun EDID-serienummers: {naam: [ids]}."""
    outputs = {}
    current = None
    edid = None
    for line in text.splitlines() + ["END"]:
        if re.fullmatch(r"\s+[0-9a-fA-F]{32}\s*", line) and current and edid is not None:
            edid += line.strip()
            continue
        if edid:
            outputs[current] = edid_ids(bytes.fromhex(edid))
            edid = None
        match = re.match(r"^(\S+) (connected|disconnected)\b", line)
        if match:
            current = match[1] if match[2] == "connected" else None
            if current:
                outputs[current] = []
        if line.strip() == "EDID:":
            edid = ""
    return outputs


def connector_key(name):
    """DP-2 < DP-10 < HDMI-0: zelfde soort op poortnummer."""
    kind, _, number = str(name).rpartition("-")
    return (kind, int(number)) if number.isdigit() else (str(name), -1)


def match_outputs(monitors, outputs):
    """Koppel Hyprland-schermen aan X-uitgangen.

    Eerst op serienummer. Xorg (zeker NVIDIA) nummert connectoren anders dan
    Hyprland (DP-1/3/4 tegen DP-0/2/4): een gelijke naam is dus geen bewijs.
    Wat overblijft wordt per soort connector op poortvolgorde gekoppeld.
    """
    pairs = {}
    used = set()
    for index, monitor in enumerate(monitors):
        serial = str(monitor.get("serial", "")).strip()
        hits = [name for name, ids in outputs.items() if serial and serial in ids and name not in used]
        if len(hits) == 1:
            pairs[index] = hits[0]
            used.add(hits[0])
    rest_monitors = [i for i in range(len(monitors)) if i not in pairs]
    rest_outputs = [name for name in outputs if name not in used]
    kinds = {connector_key(monitors[i].get("name"))[0] for i in rest_monitors}
    for kind in kinds:
        group = sorted((i for i in rest_monitors if connector_key(monitors[i].get("name"))[0] == kind),
                       key=lambda i: connector_key(monitors[i].get("name")))
        targets = sorted((n for n in rest_outputs if connector_key(n)[0] == kind), key=connector_key)
        if len(group) == len(targets):
            pairs.update(zip(group, targets))
            used.update(targets)
            rest_outputs = [n for n in rest_outputs if n not in used]
    # Nog één over aan beide kanten: dat moet hetzelfde scherm zijn.
    left = [i for i in rest_monitors if i not in pairs]
    if len(left) == 1 and len(rest_outputs) == 1:
        pairs[left[0]] = rest_outputs[0]
    return pairs


def display_command(profile, outputs):
    rows = []
    monitors = [m for m in profile.get("monitors", []) if not m.get("disabled")]
    pairs = match_outputs(monitors, outputs)
    for index, monitor in enumerate(monitors):
        name = pairs.get(index)
        if not name:
            print(f"kingstra-sddm-xsetup: geen X-uitgang voor {monitor.get('name')}", file=sys.stderr)
            continue
        # Xrandr krijgt alleen vaste opties en gecontroleerde waarden als argv.
        x, y = int(monitor["x"]), int(monitor["y"])
        width, height = int(monitor["width"]), int(monitor["height"])
        transform = int(monitor.get("transform", 0))
        scale = float(monitor.get("scale", 1))
        if not (0 < width <= 32768 and 0 < height <= 32768 and 0.25 <= scale <= 8 and 0 <= transform <= 3):
            continue
        print(f"kingstra-sddm-xsetup: {monitor.get('name')} -> {name} op {x}x{y}", file=sys.stderr)
        rows.append((name, x, y, width, height, transform, scale, monitor.get("focused", False)))
    command = ["/usr/bin/xrandr"]
    min_x = min((r[1] for r in rows), default=0)
    min_y = min((r[2] for r in rows), default=0)
    for name, x, y, width, height, transform, scale, primary in rows:
        command += ["--output", name, "--mode", f"{width}x{height}",
                    "--pos", f"{x-min_x}x{y-min_y}", "--rotate", ("normal", "left", "inverted", "right")[transform],
                    "--scale", f"{1/scale:g}x{1/scale:g}"]
        if primary:
            command += ["--primary"]
    return command


def main():
    if not PROFILE.is_file():
        return
    try:
        profile = json.loads(PROFILE.read_text())
        result = subprocess.run(["/usr/bin/xrandr", "--props"], capture_output=True, text=True, timeout=5, check=True)
        command = display_command(profile, outputs_from_xrandr(result.stdout))
        if len(command) > 1:
            subprocess.run(command, timeout=10, check=True)
        keyboard = profile.get("keyboard", {})
        layout, variant = keyboard.get("layout", "us"), keyboard.get("variant", "")
        if re.fullmatch(r"[a-zA-Z0-9_,+-]+", layout) and re.fullmatch(r"[a-zA-Z0-9_,+-]*", variant):
            subprocess.run(["/usr/bin/setxkbmap", "-layout", layout, "-variant", variant], timeout=5, check=True)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"kingstra-sddm-xsetup: {error}", file=sys.stderr)


if __name__ == "__main__":
    main()
