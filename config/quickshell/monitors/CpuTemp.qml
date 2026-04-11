import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// CpuTemp — Leest CPU temperatuur en toont als pill in de TopBar
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: cpuMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property string tempStr: "--°C"
    property string usagePct: "--%"
    property color tempColor: mocha.green

    function _colorForTemp(t) {
        if (t >= 90) return mocha.red;
        if (t >= 75) return mocha.peach;
        if (t >= 60) return mocha.yellow;
        return mocha.green;
    }

    Process {
        id: cpuPoller
        command: ["bash", "-c",
            // Probeer eerst sensors, dan /sys/class/thermal
            "sensors 2>/dev/null | awk '/^(Core 0|Tdie|Package id 0|temp1):/ {gsub(/[^0-9.]/,\" \",$2); if($2+0>0){print $2+0\"°C\"; exit}}' || " +
            "cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf \"%.0f°C\\n\", $1/1000}' || echo '--°C'"
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

    Process {
        id: cpuUsagePoller
        command: ["bash", "-c",
            "awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(prevt>0){printf \"%.0f%%\",(u-prevu)*100/(t-prevt)} else {print \"--%\"}; prevt=t; prevu=u}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim();
                if (t !== "") root.usagePct = t;
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: cpuPoller.running = true }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: cpuUsagePoller.running = true }
    Component.onCompleted: {
        cpuPoller.running = true;
        cpuUsagePoller.running = true;
    }

    property real targetWidth: cpuRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: cpuRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "󰍛"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.usagePct
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
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
        id: cpuMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "kitty --class floating-btop -e btop 2>/dev/null || btop 2>/dev/null || true"])
    }
}
