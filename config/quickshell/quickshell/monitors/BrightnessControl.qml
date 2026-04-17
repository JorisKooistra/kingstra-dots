import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// BrightnessControl — Slider die brightnessctl aanroept
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: brightMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property int brightness: 100   // 0–100

    // Lees huidige helderheid
    Process {
        id: brightReader
        command: ["bash", "-c",
            "brightnessctl get 2>/dev/null | tr -d '\\n' || echo 100"
        ]
        stdout: StdioCollector { onStreamFinished: {
            let v = parseInt(this.text.trim());
            if (!isNaN(v)) {
                maxReader.running = true;
                root._rawValue = v;
            }
        }}
    }
    property int _rawValue: 100
    property int _maxValue: 255

    Process {
        id: maxReader
        command: ["bash", "-c", "brightnessctl max 2>/dev/null || echo 255"]
        stdout: StdioCollector { onStreamFinished: {
            let m = parseInt(this.text.trim());
            if (!isNaN(m) && m > 0) {
                root._maxValue = m;
                root.brightness = Math.round(root._rawValue * 100 / m);
            }
        }}
    }

    Timer { interval: 5000; running: true; repeat: true; onTriggered: brightReader.running = true }
    Component.onCompleted: brightReader.running = true

    property real targetWidth: brightRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: brightRow
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: root.brightness >= 70 ? "󰃠" : root.brightness >= 30 ? "󰃟" : "󰃞"
            font.family: "Iosevka Nerd Font"; font.pixelSize: 16
            color: mocha.yellow
            anchors.verticalCenter: parent.verticalCenter
        }

        // Mini slider
        Rectangle {
            width: 80; height: 6
            radius: 3
            color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.5)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                width: parent.width * (root.brightness / 100)
                height: parent.height
                radius: parent.radius
                color: mocha.yellow
                Behavior on width { NumberAnimation { duration: 200 } }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => {
                    let pct = Math.round(mouse.x / width * 100);
                    pct = Math.max(1, Math.min(100, pct));
                    root.brightness = pct;
                    Quickshell.execDetached(["bash", "-c",
                        "brightnessctl set " + pct + "% 2>/dev/null || true"
                    ]);
                }
            }
        }

        Text {
            text: root.brightness + "%"
            font.family: "JetBrains Mono"; font.pixelSize: 12; font.weight: Font.Bold
            color: mocha.subtext0
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: brightMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        onWheel: (wheel) => {
            let delta = wheel.angleDelta.y > 0 ? 5 : -5;
            let newVal = Math.max(1, Math.min(100, root.brightness + delta));
            root.brightness = newVal;
            Quickshell.execDetached(["bash", "-c",
                "brightnessctl set " + newVal + "% 2>/dev/null || true"
            ]);
            wheel.accepted = true;
        }
        onClicked: (mouse) => mouse.accepted = false
    }
}
