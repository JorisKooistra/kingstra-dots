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


def outputs_from_xrandr(text):
    outputs = {}
    current = None
    edid = None
    for line in text.splitlines() + ["END"]:
        if re.fullmatch(r"\s+[0-9a-fA-F]{32}\s*", line) and current and edid is not None:
            edid += line.strip()
            continue
        if edid:
            data = bytes.fromhex(edid)
            for offset in (54, 72, 90, 108):
                block = data[offset:offset + 18]
                if block[:5] == b"\0\0\0\xff\0":
                    outputs[current] = block[5:18].decode("ascii", errors="ignore").strip()
            edid = None
        match = re.match(r"^(\S+) (connected|disconnected)\b", line)
        if match:
            current = match[1] if match[2] == "connected" else None
            if current:
                outputs[current] = ""
        if line.strip() == "EDID:":
            edid = ""
    return outputs


def display_command(profile, outputs):
    rows = []
    used = set()
    for monitor in profile.get("monitors", []):
        serial = str(monitor.get("serial", "")).strip()
        matches = [name for name, value in outputs.items() if serial and value == serial]
        name = matches[0] if len(matches) == 1 else monitor.get("name")
        if name not in outputs or name in used:
            continue
        if serial and outputs[name] and outputs[name] != serial:
            continue
        # Xrandr krijgt alleen vaste opties en gecontroleerde waarden als argv.
        x, y = int(monitor["x"]), int(monitor["y"])
        width, height = int(monitor["width"]), int(monitor["height"])
        transform = int(monitor.get("transform", 0))
        scale = float(monitor.get("scale", 1))
        if not (0 < width <= 32768 and 0 < height <= 32768 and 0.25 <= scale <= 8 and 0 <= transform <= 3):
            continue
        used.add(name)
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
