import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// RamUsage — Leest RAM gebruik uit /proc/meminfo
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: ramMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property string usageStr: "--%"
    property color usageColor: mocha.blue

    function _colorForUsage(pct) {
        if (pct >= 90) return mocha.red;
        if (pct >= 75) return mocha.peach;
        if (pct >= 60) return mocha.yellow;
        return mocha.blue;
    }

    Process {
        id: ramPoller
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{pct=int((t-a)*100/t); print pct\"%\"}' /proc/meminfo 2>/dev/null || echo '--%'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") {
                    root.usageStr = t;
                    let val = parseInt(t);
                    if (!isNaN(val)) root.usageColor = root._colorForUsage(val);
                }
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: ramPoller.running = true }
    Component.onCompleted: ramPoller.running = true

    property real targetWidth: ramRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: ramRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰍺"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
            color: root.usageColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.usageStr
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.usageColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    MouseArea {
        id: ramMouse
        anchors.fill: parent
        hoverEnabled: true
    }
}
