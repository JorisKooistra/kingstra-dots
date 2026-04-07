// =============================================================================
// Bar.qml — Topbar root (Imperative-stijl)
// =============================================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "./modules" as Modules
import "./popups"  as Popups
import "../"       as Ks

PanelWindow {
    id: bar

    // ---------------------------------------------------------------------------
    // Scherm-koppeling (ingesteld door shell.qml via Variants)
    // ---------------------------------------------------------------------------
    property var screen: null
    WlrLayershell.monitor: bar.screen

    // ---------------------------------------------------------------------------
    // Positie en grootte
    // ---------------------------------------------------------------------------
    anchors {
        top:   true
        left:  true
        right: true
    }
    height: 36

    // Reserveer ruimte voor de bar — vensters beginnen eronder
    exclusiveZone: height

    // ---------------------------------------------------------------------------
    // Uiterlijk — transparant + blur (blur via Hyprland layerrule)
    // ---------------------------------------------------------------------------
    color: "transparent"

    Rectangle {
        id: barBackground
        anchors.fill: parent
        color:        Ks.Colors.barBackground
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
                Ks.Colors.outline.r,
                Ks.Colors.outline.g,
                Ks.Colors.outline.b,
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
        Modules.Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        // Midden — actief venster + klok
        Item {
            Layout.fillWidth: true

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Modules.ActiveWindow {
                    Layout.alignment: Qt.AlignVCenter
                    maxWidth: 300
                }

                Modules.Clock {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // Rechts — systeem
        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            spacing: 4

            Modules.MediaPlayer {
                Layout.alignment: Qt.AlignVCenter
            }

            Modules.SystemStats {
                Layout.alignment: Qt.AlignVCenter
            }

            Modules.NotifButton {
                Layout.alignment: Qt.AlignVCenter
            }

            Modules.PowerButton {
                Layout.alignment: Qt.AlignVCenter
                onTogglePowerMenu: powerPopup.visible = !powerPopup.visible
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Power-popup (aangestuurd door PowerButton)
    // ---------------------------------------------------------------------------
    Popups.PowerPopup {
        id: powerPopup
        visible: false
        parentBar: bar
    }

    // IPC-signalen — andere processen kunnen popups togglen via:
    // qs ipc call power toggle
    IpcHandler {
        target: "power"
        function toggle() { powerPopup.visible = !powerPopup.visible }
    }
}
