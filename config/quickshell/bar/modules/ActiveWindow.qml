// =============================================================================
// ActiveWindow.qml — Actieve venstertitel
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../" as Ks

Item {
    id: root

    property real maxWidth: 280
    implicitHeight: 26
    implicitWidth:  Math.min(titleText.implicitWidth + 24, maxWidth)

    readonly property string windowTitle: Hyprland.focusedClient?.title    ?? ""
    readonly property string windowClass: Hyprland.focusedClient?.appId    ?? ""
    readonly property string displayText: windowTitle.length > 0 ? windowTitle : windowClass

    visible: displayText.length > 0

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color:  Ks.Colors.pillBackground
    }

    Text {
        id: titleText
        anchors {
            verticalCenter: parent.verticalCenter
            left:           parent.left
            right:          parent.right
            leftMargin:     12
            rightMargin:    12
        }

        text:  root.displayText
        color: Ks.Colors.subtext0
        elide: Text.ElideRight
        font {
            family:    "Fira Sans"
            pixelSize: 12
        }

        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: titleText; property: "opacity"; to: 0; duration: 80 }
                PropertyAction  {}
                NumberAnimation { target: titleText; property: "opacity"; to: 1; duration: 80 }
            }
        }
    }
}
