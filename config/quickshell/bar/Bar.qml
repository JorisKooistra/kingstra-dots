// =============================================================================
// Bar.qml — Topbar root (Imperative-stijl)
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./modules"
import "./popups"
import "../"      

PanelWindow {
    id: bar

    // ---------------------------------------------------------------------------
    // Positie en grootte
    // ---------------------------------------------------------------------------
    anchors {
        top:   true
        left:  true
        right: true
    }
    implicitHeight: 36

    // Reserveer ruimte voor de bar — vensters beginnen eronder
    exclusiveZone: implicitHeight

    // ---------------------------------------------------------------------------
    // Uiterlijk — transparant + blur (blur via Hyprland layerrule)
    // ---------------------------------------------------------------------------
    color: "transparent"

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color:        Colors.barBackground
        radius:       0

        // Subtiele onderlijn
        Rectangle {
            anchors {
                bottom: parent.bottom
                left:   parent.left
                right:  parent.right
            }
            height: 1
            color:  Qt.rgba(
                Colors.outline.r,
                Colors.outline.g,
                Colors.outline.b,
                0.4
            )
        }
    }

    // ---------------------------------------------------------------------------
    // Inhoud — drie kolommen
    // ---------------------------------------------------------------------------
    RowLayout {
        anchors {
            fill:          parent
            leftMargin:    8
            rightMargin:   8
            topMargin:     3
            bottomMargin:  3
        }
        spacing: 0

        // Links — werkruimtes
        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        // Midden — actief venster + klok
        Item {
            Layout.fillWidth: true

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                ActiveWindow {
                    Layout.alignment: Qt.AlignVCenter
                    maxWidth: 300
                }

                Clock {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // Rechts — systeem
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 4

            MediaPlayer {
                Layout.alignment: Qt.AlignVCenter
            }

            SystemStats {
                Layout.alignment: Qt.AlignVCenter
                onToggleStatsMenu: statsPopup.visible = !statsPopup.visible
            }

            NotifButton {
                Layout.alignment: Qt.AlignVCenter
            }

            PowerButton {
                Layout.alignment: Qt.AlignVCenter
                onTogglePowerMenu: powerPopup.visible = !powerPopup.visible
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Power-popup (aangestuurd door PowerButton)
    // ---------------------------------------------------------------------------
    PowerPopup {
        id: powerPopup
        visible: false
        parentBar: bar
    }

    // ---------------------------------------------------------------------------
    // Stats-popup (aangestuurd door SystemStats klik)
    // ---------------------------------------------------------------------------
    StatsPopup {
        id: statsPopup
        visible: false
        parentBar: bar
    }

    // IPC-signalen — andere processen kunnen popups togglen via:
    // qs ipc call power toggle  |  qs ipc call stats toggle
    IpcHandler {
        target: "power"
        function toggle() { powerPopup.visible = !powerPopup.visible }
    }
    IpcHandler {
        target: "stats"
        function toggle() { statsPopup.visible = !statsPopup.visible }
    }
}
