// =============================================================================
// PowerPopup.qml — Power-menu popup (Imperative-stijl)
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../" as Ks

PanelWindow {
    id: popup

    property var parentBar: null

    // ---------------------------------------------------------------------------
    // Positie — rechts bovenhoek, onder de bar
    // ---------------------------------------------------------------------------
    anchors {
        top:   true
        right: true
    }
    margins {
        top:   (parentBar?.height ?? 36) + 6
        right: 12
    }

    implicitWidth:  220
    implicitHeight: grid.implicitHeight + 24

    WlrLayershell {
        layer:       WlrLayershell.Overlay
        keyboardFocus: WlrKeyboardFocus.None
    }

    color: "transparent"

    // Achtergrond
    Rectangle {
        anchors.fill: parent
        radius: 12
        color:  Ks.Colors.popupBackground

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:   Qt.rgba(0, 0, 0, 0.5)
            shadowBlur:    0.8
            shadowVerticalOffset: 4
        }
    }

    // Sluiten bij klik buiten popup
    MouseArea {
        anchors.fill: parent
        onClicked:    popup.visible = false
        z: -1
    }

    // ---------------------------------------------------------------------------
    // Knoppen
    // ---------------------------------------------------------------------------
    GridLayout {
        id: grid
        anchors {
            top:         parent.top
            left:        parent.left
            right:       parent.right
            topMargin:   12
            leftMargin:  12
            rightMargin: 12
        }
        columns:     2
        rowSpacing:  8
        columnSpacing: 8

        Repeater {
            model: [
                { icon: "󰌾", label: "Vergrendelen",  cmd: ["hyprlock"] },
                { icon: "󰗽", label: "Uitloggen",     cmd: ["hyprctl", "dispatch", "exit"] },
                { icon: "󰒲", label: "Slaapstand",    cmd: ["systemctl", "suspend"] },
                { icon: "󰜉", label: "Herstarten",    cmd: ["systemctl", "reboot"] },
                { icon: "⏻",  label: "Afsluiten",    cmd: ["systemctl", "poweroff"] },
            ]

            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                height: 52
                radius: 8
                color:  btnArea.containsMouse
                    ? Qt.rgba(Ks.Colors.surfaceVariant.r, Ks.Colors.surfaceVariant.g, Ks.Colors.surfaceVariant.b, 0.9)
                    : Qt.rgba(Ks.Colors.surface.r, Ks.Colors.surface.g, Ks.Colors.surface.b, 0.7)

                Behavior on color { ColorAnimation { duration: 150 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text:  modelData.icon
                        color: btnArea.containsMouse ? Ks.Colors.primary : Ks.Colors.text
                        font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text:  modelData.label
                        color: Ks.Colors.subtext0
                        font { family: "Fira Sans"; pixelSize: 11 }
                    }
                }

                MouseArea {
                    id: btnArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked: {
                        popup.visible = false
                        actionProc.command = modelData.cmd
                        actionProc.running = true
                    }
                }
            }
        }
    }

    Process {
        id: actionProc
        command: []
    }
}
