#!/usr/bin/env python3
"""
launcher-state.py — runtime state voor de Quickshell app-launcher.

Houdt launch counts en maximaal drie gepinde desktop-ids bij in
~/.cache/kingstra/launcher-state.json. De launcher leest dit als JSON en
roept kleine acties aan bij starten/pinnen.
"""
import json
import os
import sys
import tempfile
import time
import fcntl


MAX_PINS = 3


def state_path():
    home = os.path.expanduser("~")
    cache_home = os.environ.get("XDG_CACHE_HOME") or os.path.join(home, ".cache")
    return os.path.join(cache_home, "kingstra", "launcher-state.json")


def default_state():
    return {"version": 1, "counts": {}, "lastLaunched": {}, "pins": []}


def load_state():
    path = state_path()
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        data = {}

    state = default_state()
    if isinstance(data, dict):
        if isinstance(data.get("counts"), dict):
            state["counts"] = {
                str(k): int(v)
                for k, v in data["counts"].items()
                if isinstance(v, (int, float)) or str(v).isdigit()
            }
        if isinstance(data.get("lastLaunched"), dict):
            state["lastLaunched"] = {
                str(k): int(v)
                for k, v in data["lastLaunched"].items()
                if isinstance(v, (int, float)) or str(v).isdigit()
            }
        if isinstance(data.get("pins"), list):
            pins = []
            for item in data["pins"]:
                app_id = str(item)
                if app_id and app_id not in pins:
                    pins.append(app_id)
                if len(pins) >= MAX_PINS:
                    break
            state["pins"] = pins
    return state


def save_state(state):
    path = state_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".launcher-state.", dir=os.path.dirname(path), text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(state, fh, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
            fh.write("\n")
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def locked_update(mutator):
    path = state_path()
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lock_path = path + ".lock"
    with open(lock_path, "w", encoding="utf-8") as lock_fh:
        fcntl.flock(lock_fh, fcntl.LOCK_EX)
        state = load_state()
        mutator(state)
        save_state(state)
        fcntl.flock(lock_fh, fcntl.LOCK_UN)
        return state


def print_state(state):
    json.dump(state, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "get"
    app_id = sys.argv[2] if len(sys.argv) > 2 else ""
    state = load_state()

    if action == "get":
        print_state(state)
        return 0

    if action == "launch":
        if not app_id:
            return 2
        def mutate(state):
            counts = state.setdefault("counts", {})
            counts[app_id] = int(counts.get(app_id, 0)) + 1
            state.setdefault("lastLaunched", {})[app_id] = int(time.time())
        state = locked_update(mutate)
        print_state(state)
        return 0

    if action == "pin":
        if not app_id:
            return 2
        def mutate(state):
            pins = state.setdefault("pins", [])
            if app_id in pins:
                pins.remove(app_id)
            if len(pins) < MAX_PINS:
                pins.append(app_id)
        state = locked_update(mutate)
        print_state(state)
        return 0

    if action == "unpin":
        if not app_id:
            return 2
        def mutate(state):
            pins = state.setdefault("pins", [])
            if app_id in pins:
                pins.remove(app_id)
        state = locked_update(mutate)
        print_state(state)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
