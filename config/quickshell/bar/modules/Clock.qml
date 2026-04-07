// =============================================================================
// Clock.qml — Klok met datum
// =============================================================================
import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    implicitWidth:  layout.implicitWidth + 16
    implicitHeight: 26

    property var _now: new Date()

    // Update elke minuut
    Timer {
        interval: 60000
        running:  true
        repeat:   true
        triggeredOnStart: true
        onTriggered: root._now = new Date()
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  Colors.pillBackground
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // Datum
        Text {
            text: Qt.formatDate(root._now, "ddd d MMM")
            color: Colors.subtext0
            font {
                family:    "Fira Sans"
                pixelSize: 12
            }
        }

        // Scheidingsteken
        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.5)
        }

        // Tijd
        Text {
            text: Qt.formatTime(root._now, "HH:mm")
            color: Colors.text
            font {
                family:    "JetBrainsMono Nerd Font"
                pixelSize: 13
                bold:      true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        // Fase 5+: open kalender popup
        // onClicked: Hyprland.dispatch("exec qs ipc call calendar toggle")
    }
}
