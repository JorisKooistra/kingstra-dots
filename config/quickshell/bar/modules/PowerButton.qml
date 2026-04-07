// =============================================================================
// PowerButton.qml — Power-menu knop
// =============================================================================
import QtQuick
import "../../"

Item {
    id: root
    implicitWidth:  26
    implicitHeight: 26

    signal togglePowerMenu()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  area.containsMouse
            ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.25)
            : Colors.pillBackground

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
        anchors.centerIn: parent
        text:  "⏻"
        color: area.containsMouse ? Colors.red : Colors.subtext0
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onClicked:    root.togglePowerMenu()
    }
}
