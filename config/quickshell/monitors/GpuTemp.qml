import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// GpuTemp — Leest GPU temperatuur (nvidia-smi of /sys/class/drm)
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: gpuMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property string tempStr: "--°C"
    property color tempColor: mocha.green

    function _colorForTemp(t) {
        if (t >= 90) return mocha.red;
        if (t >= 80) return mocha.peach;
        if (t >= 65) return mocha.yellow;
        return mocha.green;
    }

    Process {
        id: gpuPoller
        command: ["bash", "-c",
            // Nvidia → nvidia-smi; AMD → /sys/class/drm
            "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk '{print $1\"°C\"; exit}' || " +
            "cat /sys/class/drm/card0/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 | awk '{printf \"%.0f°C\\n\", $1/1000}' || echo '--°C'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    root.tempStr = t;
                    let val = parseFloat(t);
                    if (!isNaN(val)) root.tempColor = root._colorForTemp(val);
                }
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: gpuPoller.running = true }
    Component.onCompleted: gpuPoller.running = true

    property real targetWidth: gpuRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: gpuRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰾲"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.tempStr
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    MouseArea {
        id: gpuMouse
        anchors.fill: parent
        hoverEnabled: true
    }
}
