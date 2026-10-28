#!/usr/bin/env python3
"""Workspace layout control. Runtime layout, not saved preferences, gates actions."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

LAYOUTS = {"tegels": "dwindle", "50-50": "master", "70-30": "master",
           "midden": "master", "kolommen": "scrolling", "scrollen": "scrolling",
           "ruimtelijk": "lua:hyprscroll2d", "focus": "monocle"}
STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "kingstra"
HYPR = os.environ.get("HYPRCTL_BIN", "hyprctl")


def hypr(*args):
    result = subprocess.run([HYPR, *args], text=True, capture_output=True, timeout=5, check=False)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "Hyprland niet bereikbaar")
    text = result.stdout.strip()
    if text.lower().startswith(("error", "invalid", "unknown")):
        raise RuntimeError(text)
    return text


def query(name):
    return json.loads(hypr(name, "-j"))


def layout_name(workspace):
    value = workspace.get("tiledLayout", workspace.get("layout", ""))
    return value.get("name", "") if isinstance(value, dict) else str(value)


def saved():
    try:
        data = json.loads((STATE / "workspace-layouts.json").read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def save(workspace, preset):
    data = saved()
    data[str(workspace)] = preset
    flat = "".join(f"{w} {LAYOUTS[p]}\n" for w, p in sorted(data.items())
                   if re.fullmatch(r"[1-9]\d*", str(w)) and p in LAYOUTS)
    atomic(STATE / "workspace-layouts", flat)
    atomic(STATE / "workspace-layouts.json", json.dumps(data, indent=2) + "\n")


def dispatch(message):
    return hypr("dispatch", "hl.dsp.layout(" + json.dumps(message) + ")")


def current():
    workspace = query("activeworkspace")
    actual = layout_name(workspace)
    preset = saved().get(str(workspace["id"]), "tegels")
    if LAYOUTS.get(preset) != actual:
        preset = next((key for key, value in LAYOUTS.items() if value == actual), "onbekend")
    return {"workspace": str(workspace["id"]), "preset": preset, "layout": actual,
            "windows": int(workspace.get("windows", 0))}


def apply(preset, workspace=None):
    if preset not in LAYOUTS:
        raise ValueError("Onbekende indeling: " + preset)
    if workspace is not None and not re.fullmatch(r"[1-9]\d*", str(workspace)):
        raise ValueError("Ongeldige werkruimte")
    previous = current()
    target = str(workspace or previous["workspace"])
    if target != previous["workspace"]:
        hypr("dispatch", "hl.dsp.focus({workspace=" + json.dumps(target) + "})")
        if current()["workspace"] != target:
            raise RuntimeError("Werkruimte kon niet worden geselecteerd")
    before = current()
    wanted = LAYOUTS[preset]
    if wanted == "lua:hyprscroll2d":
        registered = hypr("eval", 'return rawget(_G, "__hyprscroll2d_layout_registered") == true')
        if "true" not in registered.lower():
            raise RuntimeError("Ruimtelijk werkvlak vereist de Lua-layout-API van Hyprland 0.56")
    rule = "hl.workspace_rule({workspace=%s,layout=%s})"
    hypr("eval", rule % (json.dumps(target), json.dumps(wanted)))
    try:
        observed = None
        for _ in range(6):
            observed = current()
            if observed["layout"] == wanted:
                break
            time.sleep(0.05)
        if observed["layout"] != wanted:
            raise RuntimeError("Hyprland bevestigt de gevraagde indeling niet")
        for message in {
            "50-50": ["orientationleft", "mfact exact 0.5"],
            "70-30": ["orientationleft", "mfact exact 0.7"],
            "midden": ["orientationcenter", "mfact exact 0.5"],
            "kolommen": ["colresize all 0.333"],
            "scrollen": ["colresize all 0.5"],
        }.get(preset, []):
            if observed["windows"]:
                dispatch(message)
    except Exception:
        if before["layout"]:
            hypr("eval", rule % (json.dumps(target), json.dumps(before["layout"])))
        raise
    save(target, preset)
    return current()


def action(kind, value="", extra=""):
    state = current()
    if state["layout"] not in ("scrolling", "lua:hyprscroll2d") or not state["windows"]:
        return False
    if state["layout"] == "lua:hyprscroll2d":
        if kind == "panby":
            dx, dy = float(value), float(extra)
            if not all(abs(v) < 100000 for v in (dx, dy)):
                raise ValueError("Ongeldige verplaatsing")
            dispatch(f"panby {dx:.4f} {dy:.4f}")
        elif kind == "wheel":
            if value not in ("left", "right", "up", "down"):
                raise ValueError("Ongeldige richting")
            dispatch("pan " + value)
        elif kind == "resize":
            if value not in ("grow", "shrink"):
                raise ValueError("Ongeldige maat")
            dispatch("resize width " + value)
        elif kind == "center":
            dispatch("center")
        else:
            return False
    elif kind == "wheel":
        if value not in ("left", "right", "up", "down"):
            raise ValueError("Ongeldige richting")
        dispatch("move " + ("-col" if value in ("up", "left") else "+col"))
    elif kind == "resize":
        if value not in ("grow", "shrink"):
            raise ValueError("Ongeldige maat")
        dispatch("colresize " + ("+conf" if value == "grow" else "-conf"))
    else:
        return False
    return True


def overview():
    state = current()
    if state["layout"] != "lua:hyprscroll2d":
        return False
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime:
        raise RuntimeError("Geen runtime-directory")
    atomic(Path(runtime) / "kingstra-spatial-overview-request",
           json.dumps({"workspace": int(state["workspace"]), "token": time.time_ns()}) + "\n")
    return True


def main(args):
    command = args[0] if args else "current"
    if command == "list":
        print("\n".join(LAYOUTS))
    elif command == "current":
        print(json.dumps(current()))
    elif command == "apply":
        print(json.dumps(apply(args[1], args[2] if len(args) > 2 else None)))
    elif command == "scroll":
        state = current()
        print(json.dumps(apply("tegels" if state["layout"] in ("scrolling", "lua:hyprscroll2d") else "scrollen")))
    elif command == "overview":
        return 0 if overview() else 3
    elif command == "select":
        address = args[1]
        if not re.fullmatch(r"0x[0-9a-fA-F]+", address):
            raise ValueError("Ongeldig venster")
        if any(c.get("address") == address for c in query("clients")):
            hypr("dispatch", "hl.dsp.focus({window=" + json.dumps("address:" + address) + "})")
    elif command == "main":
        state = current()
        if state["layout"] == "master":
            dispatch("swapwithmaster")
        elif state["layout"] == "scrolling" and state["windows"]:
            dispatch("promote")
        elif state["layout"] == "lua:hyprscroll2d":
            action("center")
    elif command in ("wheel", "resize", "panby", "center"):
        action(command, *args[1:])
    else:
        raise ValueError("Onbekende actie: " + command)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (OSError, ValueError, KeyError, IndexError, RuntimeError, subprocess.SubprocessError) as error:
        print("Indeling: " + str(error), file=sys.stderr)
        sys.exit(1)
