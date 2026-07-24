#!/usr/bin/env python3
"""Streamt venstergeometrie voor de neon target-lock frames.

Hyprland stuurt tijdens een muis-drag geen geometrie-events, dus de positie
moet gepold worden. Dat gebeurt hier en niet in Quickshell zelf: de
controlsocket verbreekt na elk antwoord, en Quickshell logt dan per query een
waarschuwing. Dit proces houdt het pollen buiten de shell en stuurt alleen een
regel zodra er echt iets veranderd is.

Uitvoer: één compacte JSON-regel per wijziging.
    {"m": [monitoren], "c": [vensters]}
"""

import json
import os
import socket
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "")
SIGNATURE = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
SOCKET_PATH = "%s/hypr/%s/.socket.sock" % (RUNTIME, SIGNATURE)

# In rust volstaat een rustige tik; zodra er iets beweegt schakelen we op tot
# vlak boven de beeldverversing en zakken daarna weer terug.
IDLE_INTERVAL = 1.0 / 30
FAST_INTERVAL = 1.0 / 90
SETTLE_SECONDS = 0.6
MONITOR_INTERVAL = 2.0


def query(command):
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(2.0)
    try:
        sock.connect(SOCKET_PATH)
        sock.sendall(command.encode())
        chunks = []
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
        return b"".join(chunks).decode("utf-8", "replace")
    finally:
        sock.close()


def read_monitors():
    out = []
    for mon in json.loads(query("j/monitors")):
        active_ws = mon.get("activeWorkspace") or {}
        special_ws = mon.get("specialWorkspace") or {}
        out.append({
            "id": mon.get("id", -1),
            "name": mon.get("name", ""),
            "x": mon.get("x", 0),
            "y": mon.get("y", 0),
            "aws": active_ws.get("id", 0),
            "sws": special_ws.get("id", 0),
        })
    return out


def read_clients():
    out = []
    for win in json.loads(query("j/clients")):
        if not win.get("mapped") or win.get("hidden"):
            continue
        if win.get("fullscreen") or win.get("fullscreenClient"):
            continue
        window_class = str(win.get("class") or win.get("initialClass") or "").lower()
        if window_class == "org.quickshell" or win.get("title") == "qs-master":
            continue
        at = win.get("at") or [0, 0]
        size = win.get("size") or [0, 0]
        if size[0] < 80 or size[1] < 60:
            continue
        workspace = win.get("workspace") or {}
        out.append({
            "a": win.get("address", ""),
            "m": win.get("monitor", -1),
            "ws": workspace.get("id", 0),
            "x": at[0],
            "y": at[1],
            "w": size[0],
            "h": size[1],
            # focusHistoryID 0 is het actieve venster; dat scheelt een tweede
            # query per tik.
            "f": 1 if win.get("focusHistoryID") == 0 else 0,
            "p": 1 if win.get("pinned") else 0,
        })
    return out


def main():
    if not RUNTIME or not SIGNATURE:
        sys.stderr.write("geen Hyprland-sessie gevonden\n")
        return 1

    monitors = []
    previous_clients = None
    previous_monitors = None
    last_monitor_poll = 0.0
    last_change = 0.0

    while True:
        now = time.monotonic()
        try:
            if now - last_monitor_poll >= MONITOR_INTERVAL or not monitors:
                monitors = read_monitors()
                last_monitor_poll = now
            clients = read_clients()
        except (OSError, ValueError):
            # Compositor herstart of socket weg: even wachten en opnieuw.
            time.sleep(0.5)
            continue

        if clients != previous_clients or monitors != previous_monitors:
            previous_clients = clients
            previous_monitors = monitors
            last_change = now
            sys.stdout.write(json.dumps({"m": monitors, "c": clients}) + "\n")
            sys.stdout.flush()

        fast = (now - last_change) < SETTLE_SECONDS
        time.sleep(FAST_INTERVAL if fast else IDLE_INTERVAL)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
    except BrokenPipeError:
        sys.exit(0)
