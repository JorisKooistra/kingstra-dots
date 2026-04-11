import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var shell
    property var mocha
    property var surface
    property bool isVisible: false

    property var tempRows: []
    property int cpuPct: 0
    property int gpuPct: 0
    property int ramPct: 0

    visible: opacity > 0.0
    opacity: isVisible ? 1.0 : 0.0
    z: 40
    width: popupBox.implicitWidth
    height: popupBox.implicitHeight

    function clampPct(v) {
        let n = parseInt(v);
        if (isNaN(n)) return 0;
        return Math.max(0, Math.min(100, n));
    }

    function refreshData() {
        tempPoller.running = true;
        usagePoller.running = true;
    }

    onIsVisibleChanged: {
        if (isVisible) refreshData();
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: {
            if (root.isVisible) root.refreshData();
        }
    }

    Behavior on opacity { NumberAnimation { duration: 180 } }

    Process {
        id: tempPoller
        command: ["bash", "-c",
            "out=$(sensors -j 2>/dev/null | jq -r 'to_entries[] as $chip | ($chip.value | to_entries[]?) as $group | ($group.value | to_entries[]? | select(.key | test(\"temp[0-9]+_input$\"))) | \"\\($chip.key) \\($group.key)\\t\\((.value|tonumber|round))C\"' 2>/dev/null); " +
            "if [ -n \"$out\" ]; then echo \"$out\"; " +
            "else cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | awk '{printf \"Thermal Zone %d\\t%.0fC\\n\", NR, $1/1000}'; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                let rows = [];
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line === "") continue;
                    let sep = line.indexOf("\t");
                    if (sep >= 0) {
                        rows.push({
                            label: line.substring(0, sep).trim(),
                            value: line.substring(sep + 1).trim()
                        });
                    } else {
                        rows.push({ label: "Sensor " + (rows.length + 1), value: line });
                    }
                }
                if (rows.length === 0) rows.push({ label: "Temperatuur", value: "--" });
                root.tempRows = rows;
            }
        }
    }

    Process {
        id: usagePoller
        command: ["bash", "-c",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(prevt>0){printf \"%.0f\",(u-prevu)*100/(t-prevt)} else {print 0}; prevt=t; prevu=u}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)); " +
            "gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); " +
            "if [ -z \"$gpu\" ]; then gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); fi; " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo 2>/dev/null); " +
            "echo \"${cpu:-0}|${gpu:-0}|${ram:-0}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let raw = this.text.trim();
                if (raw === "") return;
                let parts = raw.split("|");
                if (parts.length >= 3) {
                    root.cpuPct = root.clampPct(parts[0]);
                    root.gpuPct = root.clampPct(parts[1]);
                    root.ramPct = root.clampPct(parts[2]);
                }
            }
        }
    }

    Rectangle {
        id: popupBox
        anchors.fill: parent
        implicitWidth: shell.s(360)
        implicitHeight: contentCol.implicitHeight + shell.s(18)
        radius: shell.s(9)
        color: surface ? surface.innerPillColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.8)
        clip: true

        ColumnLayout {
            id: contentCol
            anchors.fill: parent
            anchors.margins: shell.s(10)
            spacing: shell.s(8)

            Text {
                text: "Temperaturen"
                font.family: "JetBrains Mono"
                font.pixelSize: shell.s(12)
                font.weight: Font.Black
                color: mocha.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: shell.s(4)
                Repeater {
                    model: root.tempRows
                    delegate: RowLayout {
                        Layout.fillWidth: true
                        spacing: shell.s(8)
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            font.family: "JetBrains Mono"
                            font.pixelSize: shell.s(11)
                            color: mocha.subtext0
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.value
                            font.family: "JetBrains Mono"
                            font.pixelSize: shell.s(11)
                            font.weight: Font.Black
                            color: mocha.text
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(mocha.overlay1.r, mocha.overlay1.g, mocha.overlay1.b, 0.55)
            }

            Text {
                text: "Gebruik"
                font.family: "JetBrains Mono"
                font.pixelSize: shell.s(12)
                font.weight: Font.Black
                color: mocha.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: shell.s(6)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(8)
                    Text { text: "CPU"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.subtext0; Layout.preferredWidth: shell.s(34) }
                    Rectangle {
                        Layout.fillWidth: true
                        height: shell.s(8)
                        radius: shell.s(4)
                        color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.8)
                        Rectangle {
                            width: parent.width * (root.cpuPct / 100.0)
                            height: parent.height
                            radius: parent.radius
                            color: mocha.blue
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text { text: root.cpuPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.text; Layout.preferredWidth: shell.s(42) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(8)
                    Text { text: "GPU"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.subtext0; Layout.preferredWidth: shell.s(34) }
                    Rectangle {
                        Layout.fillWidth: true
                        height: shell.s(8)
                        radius: shell.s(4)
                        color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.8)
                        Rectangle {
                            width: parent.width * (root.gpuPct / 100.0)
                            height: parent.height
                            radius: parent.radius
                            color: mocha.mauve
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text { text: root.gpuPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.text; Layout.preferredWidth: shell.s(42) }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(8)
                    Text { text: "RAM"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.subtext0; Layout.preferredWidth: shell.s(34) }
                    Rectangle {
                        Layout.fillWidth: true
                        height: shell.s(8)
                        radius: shell.s(4)
                        color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.8)
                        Rectangle {
                            width: parent.width * (root.ramPct / 100.0)
                            height: parent.height
                            radius: parent.radius
                            color: mocha.green
                            Behavior on width { NumberAnimation { duration: 180 } }
                        }
                    }
                    Text { text: root.ramPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: shell.s(11); color: mocha.text; Layout.preferredWidth: shell.s(42) }
                }
            }
        }
    }
}
