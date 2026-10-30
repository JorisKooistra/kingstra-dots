#!/usr/bin/env python3
"""Measure atomic palette propagation across many real Quickshell components.

Only private config files are changed. No windows, wallpaper or desktop colours
are touched. Includes recovery from an interrupted/invalid JSON write.
"""
import json
import os
from pathlib import Path
import statistics
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix="kingstra-palette-test-") as tmp:
        base = Path(tmp)
        farm = base / "shell"
        farm.mkdir()
        for source in (ROOT / "config/quickshell").iterdir():
            (farm / source.name).symlink_to(source)
        config = base / "config/quickshell"
        config.mkdir(parents=True)
        palette = config / "colors.json"
        palette.write_text('{"primary":"#112233","text":"#eeeeee","on_surface":"#eeeeee"}')
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        qml = farm / "PaletteTest.qml"
        qml.write_text('''import QtQuick
import Quickshell
import Quickshell.Io
import "."
ShellRoot {
    Item {
        Repeater { id: instances; model: 80; MatugenColors {} }
    }
    IpcHandler {
        target: "colours"
        function inspect(): string {
            let rows=[];
            for(let i=0;i<instances.count;i++) rows.push({primary:String(instances.itemAt(i).primary),text:String(instances.itemAt(i).text)});
            return JSON.stringify({shared:String(Colors.primary),rows:rows});
        }
    }
}
''')
        env = dict(os.environ, XDG_CONFIG_HOME=str(base / "config"), XDG_RUNTIME_DIR=str(runtime),
                   XDG_CACHE_HOME=str(base / "cache"), QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        log_path = base / "log"
        with log_path.open("w") as log:
            process = subprocess.Popen(["quickshell", "--no-duplicate", "-p", str(qml)], env=env, stdout=log, stderr=subprocess.STDOUT)
            def state():
                result = subprocess.run(["quickshell", "ipc", "--any-display", "-p", str(qml), "call", "colours", "inspect"],
                                        env=env, capture_output=True, text=True, timeout=4)
                return json.loads(result.stdout) if result.returncode == 0 else {}
            def wait_for(value):
                deadline = time.monotonic() + 4
                while time.monotonic() < deadline:
                    data = state()
                    if data.get("shared") == value and len(data.get("rows", [])) == 80 and all(row["primary"] == value for row in data["rows"]):
                        return
                    if process.poll() is not None: break
                    time.sleep(.02)
                raise AssertionError(log_path.read_text())
            try:
                wait_for("#112233")
                latencies = []
                for colour in ["#334455", "#8899aa", "#445566", "#aabbcc", "#556677", "#112233"]:
                    staged = palette.with_suffix(".new")
                    staged.write_text(json.dumps(dict(primary=colour, text="#eeeeee", on_surface="#eeeeee")))
                    started = time.monotonic()
                    staged.replace(palette)
                    wait_for(colour)
                    latencies.append((time.monotonic() - started) * 1000)
                palette.write_text("{interrupted")
                time.sleep(.4)
                data = state()
                assert all(row["primary"] == "#112233" and row["text"] == "#eeeeee" for row in data["rows"]), data
                palette.write_text('{"primary":"#abcdef","text":"#eeeeee","on_surface":"#eeeeee"}')
                wait_for("#abcdef")
                assert max(latencies) < 750, latencies
                text = log_path.read_text()
                assert all(error not in text for error in ["ERROR:", "TypeError", "ReferenceError", "Binding loop"]), text
                print(json.dumps(dict(instances=80, medianMs=round(statistics.median(latencies), 1), maxMs=round(max(latencies), 1), invalidWriteKeptPalette=True)))
            finally:
                process.terminate()
                try: process.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()


if __name__ == "__main__":
    main()
