#!/usr/bin/env python3
"""Render the real BedieningPage using Qt; only external shell/IO services are mocked."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ.setdefault("QT_QUICK_BACKEND", "software")
from PySide6.QtCore import QEventLoop, QTimer, QUrl, qInstallMessageHandler
from PySide6.QtGui import QColor, QGuiApplication
from PySide6.QtQuick import QQuickView

REPO = Path(__file__).resolve().parents[2]
DARK = {"base": "#1e1e2e", "surface0": "#313244", "surface1": "#45475a", "surface2": "#585b70",
        "text": "#cdd6f4", "subtext0": "#a6adc8", "primary": "#89b4fa", "on_surface": "#cdd6f4"}
LIGHT = {"base": "#f5f2e9", "surface0": "#e5e8dd", "surface1": "#d6ddcd", "surface2": "#c5cebb",
         "text": "#17201a", "subtext0": "#526055", "primary": "#355e39", "on_surface": "#17201a"}

STUBS = {
    "Quickshell/qmldir": "module Quickshell\nsingleton Quickshell 1.0 Quickshell.qml\n",
    "Quickshell/Quickshell.qml": '''pragma Singleton
import QtQuick
QtObject {
    function env(name) { return "/fixture"; }
    function execDetached(args) {}
}
''',
    "Quickshell/Io/qmldir": "module Quickshell.Io\nProcess 1.0 Process.qml\nStdioCollector 1.0 StdioCollector.qml\nFileView 1.0 FileView.qml\n",
    "Quickshell/Io/Process.qml": '''import QtQuick
Item {
    property var command: []
    property bool running: false
    property QtObject stdout
    property QtObject stderr
    signal exited(int exitCode, int exitStatus)
}
''',
    "Quickshell/Io/StdioCollector.qml": '''import QtQuick
QtObject { property string text: ""; signal streamFinished() }
''',
    "Quickshell/Io/FileView.qml": '''import QtQuick
import Fixture 1.0
Item {
    id: fileView
    property string path: ""
    property bool watchChanges: false
    property bool preload: false
    property string __text: TestEnvironment.colorsJson
    signal internalTextChanged()
    signal loaded()
    signal fileChanged()
    signal loadFailed()
    function text() { return __text; }
    function reload() { internalTextChanged(); loaded(); }
    Component.onCompleted: Qt.callLater(function() { fileView.reload(); })
    Connections {
        target: TestEnvironment
        function onColorsJsonChanged() { fileView.reload(); }
    }
}
''',
    "Fixture/qmldir": "module Fixture\nsingleton TestEnvironment 1.0 TestEnvironment.qml\n",
    "Fixture/TestEnvironment.qml": '''pragma Singleton
import QtQuick
QtObject { property string colorsJson: "{}"; property color background: "#1e1e2e" }
''',
}
SINGLETONS = {
    "ThemeConfig.qml": '''pragma Singleton
import QtQuick
QtObject {
    property string uiFont: "DejaVu Sans"
    property real popupOpacity: 0.92
    property real styleGlassStrength: 0.1
    property real styleOutlineStrength: 0.18
}
''',
    "RailPins.qml": '''pragma Singleton
import QtQuick
QtObject { property var pins: [] }
''',
    "ScreenProfiles.qml": '''pragma Singleton
import QtQuick
QtObject {
    property bool busy: false
    property string errorText: ""
    property var state: ({presets: {office: {modules: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications"], bar_autohide: false}}})
    property var monitors: [
        {name: "DP-4", x: 0, y: 0, width: 1920, height: 1080, scale: 1, activeWorkspace: {id: 1}},
        {name: "DP-3", x: 1920, y: 0, width: 1920, height: 1080, scale: 1, focused: true, description: "Test display", activeWorkspace: {id: 2}},
        {name: "DP-1", x: 3840, y: 0, width: 1920, height: 1080, scale: 1, activeWorkspace: {id: 3}}
    ]
    function profile(name) { return {mode: "office", inherited: true, rail: {}, nowPlaying: "auto", desktopMedia: true, playerStyle: "theme"}; }
    function action(args) {}
    function togglePin(name, id, current) {}
}
''',
}
HOST = '''import QtQuick
import Fixture 1.0
import "./quickshell/settings"
Rectangle {
    id: host
    width: 860; height: 680
    color: TestEnvironment.background
    readonly property var environment: TestEnvironment
    BedieningPage { id: page; anchors.fill: parent }
    readonly property string auditJson: {
        let dependency = TestEnvironment.colorsJson;
        let texts = [];
        function walk(item) {
            if (typeof item.text === "string" && item.color !== undefined) {
                texts.push({text: item.text, color: String(item.color),
                    background: item.parent && item.parent.color !== undefined ? String(item.parent.color) : ""});
            }
            for (let child of item.children) walk(child);
        }
        walk(page);
        return JSON.stringify(texts);
    }
}
'''


def wait(milliseconds=180):
    loop = QEventLoop()
    QTimer.singleShot(milliseconds, loop.quit)
    loop.exec()


def rendered_text(root, text):
    # Inspect QML inside its own runtime. Avoid PySide wrapper type collisions
    # for dynamically generated inline component classes.
    for item in json.loads(root.property("auditJson")):
        if item["text"] == text:
            return item
    raise AssertionError(f"Real page did not instantiate text: {text}")


def luminance(color):
    channels = [color.redF(), color.greenF(), color.blueF()]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def composite(color, background):
    alpha = color.alphaF()
    return QColor.fromRgbF(color.redF() * alpha + background.redF() * (1-alpha),
                           color.greenF() * alpha + background.greenF() * (1-alpha),
                           color.blueF() * alpha + background.blueF() * (1-alpha))


def contrast(foreground, background):
    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def build(folder, baseline):
    imports = folder / "imports"
    for name, content in STUBS.items():
        path = imports / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    quickshell = folder / "quickshell"
    (quickshell / "settings").mkdir(parents=True)
    qmldir = "MatugenColors 1.0 MatugenColors.qml\n"
    for name, content in SINGLETONS.items():
        (quickshell / name).write_text(content)
        qmldir += f"singleton {name[:-4]} 1.0 {name}\n"
    (quickshell / "qmldir").write_text(qmldir)
    shutil.copyfile(REPO / "config/quickshell/MatugenColors.qml", quickshell / "MatugenColors.qml")
    source = (REPO / "config/quickshell/settings/BedieningPage.qml").read_text()
    if baseline:
        source = source.replace("MatugenColors { id: pageColors }", "MatugenColors { id: palette }")
        source = source.replace("    readonly property var themeColors: pageColors\n", "")
        source = source.replace("root.themeColors.", "palette.")
    (quickshell / "settings/BedieningPage.qml").write_text(source)
    (folder / "Host.qml").write_text(HOST)
    return imports


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", action="store_true")
    parser.add_argument("--output", default="artifacts/bediening-colors")
    args = parser.parse_args()
    messages = []
    qInstallMessageHandler(lambda kind, context, message: messages.append(message))
    app = QGuiApplication([])
    with tempfile.TemporaryDirectory() as directory:
        folder = Path(directory)
        imports = build(folder, args.baseline)
        view = QQuickView()
        view.engine().addImportPath(str(imports))
        view.setSource(QUrl.fromLocalFile(str(folder / "Host.qml")))
        if view.status() == QQuickView.Status.Error:
            raise RuntimeError("\n".join(str(error) for error in view.errors()))
        view.show()
        wait()
        root = view.rootObject()
        environment = root.property("environment")
        for name, seed in (("dark", DARK), ("light", LIGHT)):
            messages.clear()
            environment.setProperty("background", QColor(seed["base"]))
            environment.setProperty("colorsJson", json.dumps(seed))
            wait()
            heading = rendered_text(root, "Bediening")
            actual = QColor(heading["color"]).name()
            if args.baseline:
                if actual == QColor(seed["text"]).name():
                    raise AssertionError("Baseline unexpectedly has the correct Kingstra text color")
                print(f"Reproduced original palette collision: {actual} instead of {seed['text']}")
                output = Path(args.output)
                output.mkdir(parents=True, exist_ok=True)
                assert view.grabWindow().save(str(output / "bediening-before.png"))
                view.close()
                view.setSource(QUrl())
                return 0
            assert actual == QColor(seed["text"]).name(), (name, actual, seed["text"])
            for label in ("Office", "Volg standaard", "Ruimtelijk werkvlak", "Tegelen"):
                caption = rendered_text(root, label)
                assert QColor(caption["color"]).name() == QColor(seed["text"]).name(), (name, label, "text")
                background = composite(QColor(caption["background"]), QColor(seed["base"]))
                ratio = contrast(QColor(caption["color"]), background)
                assert ratio >= 4.5, (name, label, "contrast", ratio)
            for label in ("DP-4\noffice", "DP-3\noffice", "DP-1\noffice"):
                caption = rendered_text(root, label)
                assert QColor(caption["color"]).name() == QColor(seed["text"]).name(), (name, label)
            bad = [m for m in messages if any(part in m for part in
                   ("ReferenceError", "TypeError", "Unable to assign", "Binding loop"))]
            assert not bad, "\n".join(bad)
            output = Path(args.output)
            output.mkdir(parents=True, exist_ok=True)
            image = view.grabWindow()
            assert not image.isNull(), "Qt rendered no image"
            assert image.save(str(output / f"bediening-{name}.png"))
            print(f"PASS: {name}: real page rendered, labels and selected/unselected controls have readable colors")
        view.close()
        view.setSource(QUrl())
    return 0


if __name__ == "__main__":
    sys.exit(main())
