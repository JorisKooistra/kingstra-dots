// =============================================================================
// NotifButton.qml — SwayNC notificatie-indicator
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root
    implicitWidth:  btn.implicitWidth + 12
    implicitHeight: 26

    property int  count:       0
    property bool dndActive:   false

    Rectangle {
        id: btn
        anchors.fill: parent
        radius: height / 2
        color:  count > 0
            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.2)
            : Colors.pillBackground

        Behavior on color { ColorAnimation { duration: 200 } }
    }

    RowLayout {
        anchors.centerIn: parent
        spacing: 5

        Text {
            text:  dndActive ? "󰂛" : (count > 0 ? "󰂚" : "󰂜")
            color: dndActive ? Colors.yellow
                 : count > 0 ? Colors.primary
                 : Colors.subtext0
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        Text {
            visible: count > 0
            text:    count > 99 ? "99+" : count.toString()
            color:   Colors.primary
            font { family: "Fira Sans"; pixelSize: 11; bold: true }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        onClicked:    swayncToggle.running = true
        onPressAndHold: swayncDismiss.running = true
    }

    // swaync-client aansturen
    Process {
        id: swayncToggle
        command: ["swaync-client", "-t"]
    }
    Process {
        id: swayncDismiss
        command: ["swaync-client", "-d"]
        onExited: countPoll.running = true
    }

    // Meldingencount ophalen
    Process {
        id: countPoll
        command: ["swaync-client", "-c"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const n = parseInt(data.trim())
                root.count = isNaN(n) ? 0 : n
            }
        }
    }

    // DND-status ophalen
    Process {
        id: dndPoll
        command: ["swaync-client", "--inhibit-count"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                root.dndActive = parseInt(data.trim()) > 0
            }
        }
    }

    Timer {
        interval: 10000
        running:  true
        repeat:   true
        onTriggered: {
            countPoll.running = true
            dndPoll.running   = true
        }
    }
}
