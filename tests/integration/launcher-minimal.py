#!/usr/bin/env python3
"""Exercise the real launcher with private app/state fixtures and safe activations."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    with tempfile.TemporaryDirectory(prefix="kingstra-launcher-test-") as tmp:
        base = Path(tmp)
        farm = base / "shell"
        farm.mkdir()
        for source in (ROOT / "config/quickshell").iterdir():
            (farm / source.name).symlink_to(source)
        home = base / "home"
        config = home / ".config/quickshell"
        helpers = config / "shellsurface"
        helpers.mkdir(parents=True)
        apps = [dict(id=f"app-{i}", name=f"App {i}", icon="", comment="description", exec="false") for i in range(10)]
        apps[0]["name"] = "Firefox"
        (helpers / "list-apps.py").write_text("import json\nprint(" + repr(json.dumps(apps)) + ")\n")
        shutil.copyfile(ROOT / "config/quickshell/shellsurface/launcher-state.py", helpers / "launcher-state.py")
        (config / "theme.json").write_text('{"theme":"matte","style_profile":{"family":"matte","widget_radius":10}}')
        (config / "colors.json").write_text('{"text":"#dddddd","primary":"#aabbaa","base":"#161616"}')
        runtime = base / "runtime"
        runtime.mkdir(mode=0o700)
        qml = farm / "LauncherTest.qml"
        qml.write_text('''import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "."
import "shellsurface"
ShellRoot {
    property string activated: ""
    Window {
        visible: true; width: 540; height: 404
        LauncherPanel {
            id: launcher; anchors.fill: parent; focus: true
            function launch(app) { activated = "app:" + app.id; }
            function runQuickAction(action) { activated = "action:" + action.target; }
            function runPrefixResult(item) { activated = "prefix:" + item.kind + ":" + item.value; }
            function closePanel() { activated = "close"; }
        }
    }
    IpcHandler {
        target: "launcher-test"
        function inspect(): string {
            return JSON.stringify({rows: launcher.results.map(r => ({kind:r.kind,label:r.label})),
                selected:launcher.selectedIndex, query:launcher.query, help:launcher.helpOpen,
                activated:activated, pins:launcher.pinnedIds, width:launcher.preferredPanelWidth,
                height:launcher.preferredPanelHeight, focused:launcher.activeFocus});
        }
        function search(text: string): void { launcher.searchText = text; }
        function move(delta: int): void { launcher.move(delta); }
        function activate(): void { launcher.activateSelected(); }
        function help(): void { launcher.toggleHelp(); }
        function pin(): void { launcher.togglePin(launcher.results[launcher.selectedIndex].app); }
        function theme(name: string): void { ThemeConfig.theme = name; ThemeConfig.styleFamily = name; }
    }
}
''')
        env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"),
                   XDG_RUNTIME_DIR=str(runtime), XDG_CACHE_HOME=str(base / "cache"),
                   QT_QPA_PLATFORM="offscreen", QT_QUICK_BACKEND="software")
        env.pop("WAYLAND_DISPLAY", None)
        log_path = base / "log"
        with log_path.open("w") as log:
            process = subprocess.Popen(["quickshell", "--no-duplicate", "-p", str(qml)], env=env, stdout=log, stderr=subprocess.STDOUT)
            def call(method, *args):
                result = subprocess.run(["quickshell", "ipc", "--any-display", "-p", str(qml), "call", "launcher-test", method, *map(str, args)],
                                        env=env, capture_output=True, text=True, timeout=4)
                if result.returncode:
                    raise RuntimeError(result.stderr + log_path.read_text())
                return json.loads(result.stdout) if method == "inspect" else None
            def state():
                return call("inspect")
            def search(text):
                call("search", text)
                return state()
            try:
                deadline = time.monotonic() + 6
                while time.monotonic() < deadline:
                    try:
                        s = state()
                        if len(s["rows"]) == 10: break
                    except RuntimeError: pass
                    time.sleep(.05)
                else: raise AssertionError(log_path.read_text())
                assert not s["help"] and all(r["kind"] == "app" for r in s["rows"]), s
                assert s["width"] == 540 and s["height"] <= 404 and s["focused"], s
                call("move", 3)
                time.sleep(2.2)  # Cross two real state-refresh ticks.
                s = state()
                assert s["selected"] == 3, ("selection reset by background refresh", s)
                chosen = s["rows"][s["selected"]]["label"]
                chosen_id = next(app["id"] for app in apps if app["name"] == chosen)
                saved = base / "cache/kingstra/launcher-state.json"
                saved.parent.mkdir(parents=True, exist_ok=True)
                staged = saved.with_suffix(".new")
                staged.write_text(json.dumps(dict(version=1, counts={chosen_id: 100}, lastLaunched={}, pins=[])))
                staged.replace(saved)
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    s = state()
                    if s["rows"][0]["label"] == chosen:
                        assert s["rows"][s["selected"]]["label"] == chosen, ("selected app lost after reorder", s)
                        break
                    time.sleep(.05)
                else:
                    raise AssertionError(s)
                s = search("firefox")
                assert s["rows"][0]["label"] == "Firefox", s
                call("activate")
                assert state()["activated"] == "app:app-0"
                s = search("vergrendelen")
                assert s["rows"][0]["kind"] == "action", s
                call("activate")
                assert state()["activated"] == "action:lock"
                s = search("=2*(3+4)")
                assert s["rows"][0]["label"] == "= 14", s
                call("activate")
                assert state()["activated"] == "prefix:copy:14"
                s = search("no-matching-application-xyz")
                assert s["rows"] == [], s
                call("activate")  # Empty selection must do nothing.
                search("")
                call("help")
                assert state()["rows"][0]["kind"] == "mode"
                call("activate")
                assert state()["query"] == "=" and not state()["help"]
                search("")
                call("move", 1)
                call("pin")
                deadline = time.monotonic() + 3
                while time.monotonic() < deadline:
                    s = state()
                    if len(s["pins"]) == 1 and s["selected"] == 0:
                        break
                    time.sleep(.05)
                else:
                    raise AssertionError(s)
                for theme in ["paper", "organic", "neon", "mono", "mono-accent", "matte"]:
                    call("theme", theme)
                    s = search("firefox")
                    assert s["rows"][0]["label"] == "Firefox", (theme, s)
                errors = log_path.read_text()
                assert not any(e in errors for e in ["ReferenceError", "TypeError", "Binding loop", "Cannot assign"]), errors
                print("Launcher OK: rustige start, apps, toetsenbordacties, prefixes, hulp, pins en zes thema's")
            finally:
                process.terminate()
                try: process.wait(timeout=4)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait()


if __name__ == "__main__":
    main()
