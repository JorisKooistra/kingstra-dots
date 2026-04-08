import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    width: Screen.width
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: _theme }

    property string activeMode: "office"
    property bool isApplying: false
    property bool isReady: false

    // ---------------------------------------------------------------------------
    // Lees huidige mode uit state/mode.json
    // ---------------------------------------------------------------------------
    Process {
        id: modeReader
        command: ["bash", "-c",
            "jq -r '.name // \"office\"' \"${HOME}/.config/kingstra/state/mode.json\" 2>/dev/null || echo office"]
        stdout: StdioCollector {
            onStreamFinished: {
                let m = this.text.trim();
                if (m !== "") window.activeMode = m;
                window.isReady = true;
            }
        }
    }

    Component.onCompleted: modeReader.running = true

    // ---------------------------------------------------------------------------
    // Achtergrond
    // ---------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.35)
    }

    // ---------------------------------------------------------------------------
    // Title bar
    // ---------------------------------------------------------------------------
    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.topMargin: window.isReady ? window.s(40) : window.s(-80)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.topMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity           { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(48)
        width: titleRow.width + window.s(32)
        radius: window.s(14)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1

        Row {
            id: titleRow
            anchors.centerIn: parent
            spacing: window.s(10)

            Text {
                text: "󰒓"
                font.pixelSize: window.s(18)
                font.family: "JetBrainsMono Nerd Font"
                color: _theme.blue
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Mode kiezen"
                font.pixelSize: window.s(14)
                font.bold: true
                color: _theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Mode kaarten
    // ---------------------------------------------------------------------------
    Row {
        id: modeRow
        anchors.centerIn: parent
        anchors.verticalCenterOffset: window.s(-10)
        spacing: window.s(24)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Repeater {
            model: [
                { id: "office", icon: "󰒱", label: "Office",  desc: "Werk & productiviteit" },
                { id: "gaming", icon: "󰊗", label: "Gaming",  desc: "Prestaties & hardware" },
                { id: "media",  icon: "󰓃", label: "Media",   desc: "Muziek & video"        }
            ]

            delegate: Rectangle {
                required property var modelData
                property bool isActive: window.activeMode === modelData.id

                width: window.s(200)
                height: window.s(200)
                radius: window.s(18)

                color: isActive
                    ? Qt.rgba(_theme.blue.r,    _theme.blue.g,    _theme.blue.b,    0.18)
                    : Qt.rgba(_theme.surface0.r, _theme.surface0.g, _theme.surface0.b, 0.75)

                border.color: isActive
                    ? Qt.rgba(_theme.blue.r, _theme.blue.g, _theme.blue.b, 0.8)
                    : Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.4)
                border.width: isActive ? 2 : 1

                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                scale: hoverArea.containsMouse ? 1.04 : 1.0
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                Column {
                    anchors.centerIn: parent
                    spacing: window.s(12)

                    Text {
                        text: modelData.icon
                        font.pixelSize: window.s(42)
                        font.family: "JetBrainsMono Nerd Font"
                        color: isActive ? _theme.blue : _theme.subtext1
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        text: modelData.label
                        font.pixelSize: window.s(16)
                        font.bold: true
                        color: isActive ? _theme.text : _theme.subtext0
                        anchors.horizontalCenter: parent.horizontalCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }

                    Text {
                        text: modelData.desc
                        font.pixelSize: window.s(10)
                        color: Qt.rgba(_theme.subtext0.r, _theme.subtext0.g, _theme.subtext0.b, 0.7)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.applyMode(modelData.id)
                }
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Hint bar (onderin)
    // ---------------------------------------------------------------------------
    Rectangle {
        id: hintBar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: window.isReady ? window.s(30) : window.s(-60)
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
        Behavior on opacity             { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(40)
        width: hintRow.width + window.s(28)
        radius: window.s(10)
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.85)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.6)
        border.width: 1

        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: window.s(16)

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(44); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Klik"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Mode kiezen"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }

            Rectangle { width: 1; height: window.s(20); color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: window.s(4)
                Rectangle {
                    width: window.s(32); height: window.s(20); radius: window.s(4)
                    color: Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8)
                    anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: window.s(10); color: _theme.text; font.bold: true }
                }
                Text { text: "Sluiten"; font.pixelSize: window.s(11); color: _theme.subtext0; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Applying overlay
    // ---------------------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(_theme.crust.r, _theme.crust.g, _theme.crust.b, 0.6)
        visible: window.isApplying
        z: 50

        Column {
            anchors.centerIn: parent
            spacing: window.s(12)

            Text {
                text: "󰑓"
                font.pixelSize: window.s(32)
                font.family: "JetBrainsMono Nerd Font"
                color: _theme.blue
                anchors.horizontalCenter: parent.horizontalCenter

                RotationAnimation on rotation {
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 1200
                }
            }

            Text {
                text: "Mode wordt toegepast…"
                font.pixelSize: window.s(14)
                color: _theme.text
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Toetsenbord
    // ---------------------------------------------------------------------------
    Keys.onEscapePressed: {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        event.accepted = true;
    }

    Timer {
        id: closeTimer
        interval: 600
        onTriggered: {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
        }
    }

    // ---------------------------------------------------------------------------
    // Logica
    // ---------------------------------------------------------------------------
    function applyMode(modeId) {
        if (window.isApplying) return;
        window.isApplying = true;
        window.activeMode = modeId;

        Quickshell.execDetached([
            "bash",
            Quickshell.env("HOME") + "/.local/bin/kingstra-mode-switch",
            modeId
        ]);

        closeTimer.start();
    }
}
