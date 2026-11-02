#!/usr/bin/env python3
"""Laadt het SDDM-inlogscherm met nep-SDDM-objecten (zoals sddm-greeter ze als
contextproperties geeft) en controleert dat inloggen blijft werken.

Zonder argumenten draait elk scenario in een eigen proces; vereist PySide6.
Met RENDER_DIR=<map> worden ook schermafbeeldingen bewaard.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
THEME = ROOT / "config/sddm/themes/kingstra"

# scenario -> verwachte uitkomst
SCENARIOS = {
    "load": {"introDone": True, "inputActive": False, "submitted": "-"},
    "keys": {"submitted": "ab", "user": "joris", "session": 0, "inputActive": True},
    "fingerprint": {"submitted": "", "user": "joris"},
    "failed": {"submitted": "x", "loginFailed": True, "field": ""},
    "session": {"submitted": "x", "session": 1},
    "escape": {"inputActive": False, "field": ""},
    "users": {"submitted": "y", "user": "tweede"},
}


def run_scenario(theme_dir, scenario):
    from PySide6.QtCore import QEvent, Qt, QTimer, QUrl
    from PySide6.QtGui import QGuiApplication, QKeyEvent
    from PySide6.QtQml import QQmlComponent, QQmlEngine
    from PySide6.QtQuick import QQuickView

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    engine = view.engine()
    warnings = []
    engine.warnings.connect(lambda items: warnings.extend(w.toString() for w in items))
    keep = []

    def make(source):
        component = QQmlComponent(engine)
        component.setData(source.encode(), QUrl("file:///sddm-mock.qml"))
        obj = component.create()
        if obj is None:
            raise SystemExit(f"mock faalt: {[e.toString() for e in component.errors()]}")
        QQmlEngine.setObjectOwnership(obj, QQmlEngine.CppOwnership)
        keep.append((component, obj))
        return obj

    extra_user = 'ListElement { name: "tweede"; realName: ""; icon: "" }' if scenario == "users" else ""
    mocks = {
        "config": make('import QtQuick\nQtObject { property string background: "" }'),
        "keyboard": make('import QtQuick\nQtObject { property var layouts: [{shortName: "us"}]; '
                         'property int currentLayout: 0; property bool capsLock: false }'),
        "userModel": make('import QtQuick\nListModel { property string lastUser: "joris"\n'
                          'ListElement { name: "joris"; realName: "Joris"; icon: "" }\n' + extra_user + "}"),
        "sessionModel": make('import QtQuick\nListModel { property int lastIndex: 0\n'
                             'ListElement { name: "Hyprland" }\nListElement { name: "Hyprland (uwsm)" } }'),
        "sddm": make('import QtQuick\nQtObject { property string facesDir: "/nonexistent"; '
                     'property bool canSuspend: true; property string submitted: "-"; '
                     'property string user: ""; property int session: -1\n'
                     'signal loginSucceeded(); signal loginFailed()\n'
                     'function login(u, p, s) { submitted = p; user = u; session = s }\n'
                     'function reboot() {} function powerOff() {} function suspend() {} }'),
    }
    for name, obj in mocks.items():
        engine.rootContext().setContextProperty(name, obj)
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(1600, 900)
    view.setSource(QUrl.fromLocalFile(str(Path(theme_dir) / "Main.qml")))
    if view.status() != QQuickView.Ready:
        print(json.dumps({"error": [e.toString() for e in view.errors()]}))
        return 1
    view.show()
    root, sddm = view.rootObject(), mocks["sddm"]

    def key(code, text=""):
        for kind in (QEvent.KeyPress, QEvent.KeyRelease):
            QGuiApplication.sendEvent(view, QKeyEvent(kind, code, Qt.NoModifier, text))

    def finish():
        render = os.environ.get("RENDER_DIR")
        if render:
            view.grabWindow().save(str(Path(render) / f"{scenario}.png"))
        result = {k: sddm.property(k) for k in ("submitted", "user", "session")}
        for prop in ("inputActive", "introDone", "loginFailed"):
            result[prop] = root.property(prop)
        result["field"] = root.property("typedText")
        result["warnings"] = [w for w in warnings if "face.icon" not in w]
        print(json.dumps(result))
        app.quit()

    def act():
        if scenario == "keys":
            key(Qt.Key_A, "a"); key(Qt.Key_B, "b"); key(Qt.Key_Return)
        elif scenario == "fingerprint":
            key(Qt.Key_Return)  # eerste Enter opent, tweede start de vingerafdruk
            key(Qt.Key_Return)
        elif scenario == "failed":
            key(Qt.Key_X, "x"); key(Qt.Key_Return); sddm.loginFailed.emit()
        elif scenario == "session":
            root.setProperty("sessionIndex", 1)
            key(Qt.Key_X, "x"); key(Qt.Key_Return)
        elif scenario == "escape":
            key(Qt.Key_X, "x"); key(Qt.Key_Escape)
        elif scenario == "users":
            root.cycleUser(1)
            key(Qt.Key_Y, "y"); key(Qt.Key_Return)
        QTimer.singleShot(600, finish)

    # Typen tijdens de intro moet ook werken; wacht pas voor de controle.
    QTimer.singleShot(50 if scenario != "load" else 1800, act)
    app.exec()
    return 0


def main():
    if len(sys.argv) == 3:
        return run_scenario(sys.argv[1], sys.argv[2])
    try:
        import PySide6  # noqa: F401
    except ImportError:
        print("overgeslagen: PySide6 ontbreekt (pip install PySide6)")
        return 0
    env = dict(os.environ, QT_QPA_PLATFORM=os.environ.get("QT_QPA_PLATFORM", "offscreen"))
    theme_dir = os.environ.get("SDDM_THEME_DIR", str(THEME))
    failed = 0
    for scenario, expected in SCENARIOS.items():
        proc = subprocess.run([sys.executable, __file__, theme_dir, scenario], env=env,
                              capture_output=True, text=True, timeout=60)
        line = next((l for l in proc.stdout.splitlines() if l.startswith("{")), "{}")
        result = json.loads(line)
        problems = [f"{k}={result.get(k)!r} (verwacht {v!r})" for k, v in expected.items() if result.get(k) != v]
        problems += [f"waarschuwing: {w}" for w in result.get("warnings", [])]
        if "error" in result:
            problems.append(f"laden mislukt: {result['error']}")
        print(f"{'ok  ' if not problems else 'FOUT'} {scenario}" + "".join(f"\n     {p}" for p in problems))
        failed |= bool(problems)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
