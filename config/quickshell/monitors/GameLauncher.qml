import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// GameLauncher — Knop die Steam opent
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: launchMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.30)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    width: pillHeight  // vierkant

    Behavior on color { ColorAnimation { duration: 200 } }

    scale: isHovered ? 1.08 : 1.0
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: ""   // Steam icon (Nerd Font)
        font.family: "Iosevka Nerd Font"
        font.pixelSize: 18
        color: root.isHovered ? mocha.blue : mocha.subtext1
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: launchMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["bash", "-c",
            "steam 2>/dev/null || lutris 2>/dev/null || heroic 2>/dev/null || true"
        ])
    }
}
