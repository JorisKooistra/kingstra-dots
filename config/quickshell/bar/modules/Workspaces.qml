// =============================================================================
// Workspaces.qml — Hyprland werkruimte-indicator
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "../../"

Item {
    id: root
    implicitHeight: row.implicitHeight
    implicitWidth:  row.implicitWidth

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            // Werkruimtes 1-10 altijd tonen
            model: 10

            delegate: Item {
                id: wsItem
                required property int index

                readonly property int wsId:      index + 1
                readonly property bool isActive: Hyprland.activeWorkspace?.id === wsId
                readonly property bool hasWindows: {
                    const list = Hyprland.workspaces.values ?? []
                    for (const ws of list) {
                        if (ws.id === wsId && ws.windowCount > 0) return true
                    }
                    return false
                }

                implicitWidth:  dot.implicitWidth
                implicitHeight: dot.implicitHeight

                Rectangle {
                    id: dot
                    width:  isActive ? 22 : (hasWindows ? 8 : 6)
                    height: isActive ? 22 : (hasWindows ? 8 : 6)
                    radius: isActive ? 6 : width / 2
                    anchors.centerIn: parent

                    color: isActive
                        ? Colors.primary
                        : hasWindows
                            ? Qt.rgba(Colors.primary.r, Colors.primary.g, Colors.primary.b, 0.5)
                            : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.4)

                    // Werkruimtenummer tonen in actieve dot
                    Text {
                        anchors.centerIn: parent
                        visible:  parent.width >= 16
                        text:     wsItem.wsId.toString()
                        color:    Colors.onPrimary
                        font {
                            family:    "Fira Sans"
                            pixelSize: 11
                            bold:      true
                        }
                    }

                    Behavior on width  { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on color  { ColorAnimation  { duration: 150 } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch("workspace " + wsItem.wsId)
                }
            }
        }
    }
}
