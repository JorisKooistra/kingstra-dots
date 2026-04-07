// =============================================================================
// Clock.qml — Klok met datum
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../" as Ks

Item {
    id: root
    implicitWidth:  layout.implicitWidth + 16
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  Ks.Colors.pillBackground
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        // Datum
        Text {
            text: Qt.formatDate(SystemClock.date, "ddd d MMM")
            color: Ks.Colors.subtext0
            font {
                family:    "Fira Sans"
                pixelSize: 12
            }
        }

        // Scheidingsteken
        Rectangle {
            width: 1; height: 14
            color: Qt.rgba(Ks.Colors.outline.r, Ks.Colors.outline.g, Ks.Colors.outline.b, 0.5)
        }

        // Tijd
        Text {
            text: Qt.formatTime(SystemClock.time, "HH:mm")
            color: Ks.Colors.text
            font {
                family:    "JetBrainsMono Nerd Font"
                pixelSize: 13
                bold:      true
            }
        }
    }

    // Klok tikt elke minuut
    SystemClock {
        precision: SystemClock.Minutes
    }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        // Fase 5+: open kalender popup
        // onClicked: Hyprland.dispatch("exec qs ipc call calendar toggle")
    }
}
