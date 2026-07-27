import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// FpsMonitor — gebruikt een live FPS-bestand als dat bestaat, anders de actuele monitor refresh rate.
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: fpsMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property string fpsStr: "--"
    property color fpsColor: mocha.lavender

    function _colorForFps(fps) {
        if (fps >= 144) return mocha.green;
        if (fps >= 90) return mocha.teal;
        if (fps >= 60) return mocha.blue;
        if (fps >= 30) return mocha.yellow;
        return mocha.red;
    }

    Process {
        id: fpsPoller
        command: ["bash", "-c",
            "fps=''; " +
            "for p in \"${XDG_RUNTIME_DIR:-/tmp}/kingstra-current-fps\" \"$HOME/.cache/quickshell/current_fps\"; do " +
                "[ -r \"$p\" ] || continue; " +
                "fps=$(awk 'NF{gsub(/[^0-9.]/, \"\", $1); if ($1 != \"\") {printf \"%.0f\", $1; exit}}' \"$p\" 2>/dev/null); " +
                "[ -n \"$fps\" ] && break; " +
            "done; " +
            "if [ -z \"$fps\" ] && command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then " +
                "fps=$(hyprctl -j monitors 2>/dev/null | jq -r '([.[] | select(.focused == true) | .refreshRate][0] // .[0].refreshRate // empty)' 2>/dev/null | awk 'NF{printf \"%.0f\", $1; exit}'); " +
            "fi; " +
            "printf '%s\\n' \"${fps:---}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    root.fpsStr = t;
                    let val = parseFloat(t);
                    if (!isNaN(val)) root.fpsColor = root._colorForFps(val);
                }
            }
        }
    }

    Timer { interval: 2000; running: root.visible; repeat: true; onTriggered: fpsPoller.running = true }
    Component.onCompleted: if (root.visible) fpsPoller.running = true
    onVisibleChanged: if (visible && !fpsPoller.running) fpsPoller.running = true

    property real targetWidth: fpsRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: fpsRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "FPS"
            font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black
            color: root.fpsColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.fpsStr
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.fpsColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    MouseArea {
        id: fpsMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "kitty --class floating-btop -e btop 2>/dev/null || btop 2>/dev/null || true"])
    }
}
