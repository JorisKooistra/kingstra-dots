import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// CpuTemp — compacte CPU/RAM pill voor office, CPU/temp pill voor gaming.
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: cpuMouse.containsMouse
    property bool showTemperature: true

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: false

    Behavior on color { ColorAnimation { duration: 200 } }

    property string tempStr: "--°C"
    property string usagePct: "--%"
    property string ramPct: "--%"
    property color tempColor: mocha.green
    property color ramColor: mocha.blue
    property color displayColor: showTemperature ? tempColor : ramColor
    property string hoverLabel: {
        if (!cpuMouse.containsMouse) return "";
        let splitX = Math.max(1, root.width * 0.5);
        if (cpuMouse.mouseX < splitX) return "CPU";
        return showTemperature ? "TEMP" : "RAM";
    }

    function _colorForTemp(t) {
        if (t >= 90) return mocha.red;
        if (t >= 75) return mocha.peach;
        if (t >= 60) return mocha.yellow;
        return mocha.green;
    }

    function _colorForUsage(pct) {
        if (pct >= 90) return mocha.red;
        if (pct >= 75) return mocha.peach;
        if (pct >= 60) return mocha.yellow;
        return mocha.blue;
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
            "awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(seen){printf \"%.0f%%\",(u-prevu)*100/(t-prevt); exit} prevt=t; prevu=u; seen=1}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim().replace(/\s+/g, " ");
                if (t !== "") root.usagePct = t;
            }
        }
    }

    Process {
        id: ramPoller
        command: ["bash", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{pct=int((t-a)*100/t); print pct\"%\"}' /proc/meminfo 2>/dev/null || echo '--%'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim().replace(/\s+/g, " ");
                if (t !== "") {
                    root.ramPct = t;
                    let val = parseInt(t);
                    if (!isNaN(val)) root.ramColor = root._colorForUsage(val);
                }
            }
        }
    }

    Timer { interval: 3000; running: showTemperature; repeat: true; onTriggered: cpuPoller.running = true }
    Timer { interval: 3000; running: true; repeat: true; onTriggered: cpuUsagePoller.running = true }
    Timer { interval: 3000; running: !showTemperature; repeat: true; onTriggered: ramPoller.running = true }
    Component.onCompleted: {
        if (showTemperature) {
            cpuPoller.running = true;
        } else {
            ramPoller.running = true;
        }
        cpuUsagePoller.running = true;
    }
    onShowTemperatureChanged: {
        if (showTemperature) {
            cpuPoller.running = true;
        } else {
            ramPoller.running = true;
        }
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
            color: root.displayColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.usagePct
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.displayColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.showTemperature ? root.tempStr : root.ramPct
            visible: root.showTemperature
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.displayColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: "󰘚"
            visible: !root.showTemperature
            font.family: "Iosevka Nerd Font"; font.pixelSize: 15
            color: root.ramColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.ramPct
            visible: !root.showTemperature
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.ramColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    Rectangle {
        id: hoverTag
        visible: cpuMouse.containsMouse && root.hoverLabel !== ""
        opacity: visible ? 1 : 0
        z: 20
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        width: hoverText.implicitWidth + 12
        height: 20
        radius: 6
        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.92)
        border.color: Qt.rgba(root.displayColor.r, root.displayColor.g, root.displayColor.b, 0.72)
        border.width: 1

        Text {
            id: hoverText
            anchors.centerIn: parent
            text: root.hoverLabel
            font.family: "JetBrains Mono"
            font.pixelSize: 10
            font.weight: Font.Black
            color: root.hoverLabel === "RAM" ? root.ramColor : root.displayColor
        }

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: cpuMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "kitty --class floating-btop -e btop 2>/dev/null || btop 2>/dev/null || true"])
    }
}
