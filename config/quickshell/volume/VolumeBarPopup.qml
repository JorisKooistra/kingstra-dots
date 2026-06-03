import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."

Scope {
    id: volumeScope
    property bool open: false
    // Monitor-ID vastgelegd op het moment van openen, zodat slechts één scherm
    // de popup toont — ook als de focus later verschuift.
    property int activeMonitorId: -1

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: volumeWindow
            required property var modelData
            screen: modelData

            readonly property var monitor: Hyprland.monitorFor(screen)
            readonly property bool isActiveScreen: {
                if (volumeScope.activeMonitorId < 0)
                    return screen === Quickshell.screens[0];
                return monitor !== null && monitor.id === volumeScope.activeMonitorId;
            }

            // Alleen zichtbaar op het actieve scherm.
            visible: volumeScope.open && isActiveScreen
            color: "transparent"

            WlrLayershell.namespace: "quickshell:volume-popup"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            anchors.top:    ThemeConfig.barPosition === "top"
            anchors.bottom: ThemeConfig.barPosition === "bottom"
            anchors.left:   ThemeConfig.barPosition === "left"
            anchors.right:  ThemeConfig.barPosition !== "left"

            margins.top:    ThemeConfig.barPosition === "top"    ? ThemeConfig.barHeight + 6 : 6
            margins.bottom: ThemeConfig.barPosition === "bottom" ? ThemeConfig.barHeight + 6 : 6
            margins.right:  ThemeConfig.barPosition !== "left"   ? 6 : 0
            margins.left:   ThemeConfig.barPosition === "left"   ? ThemeConfig.barHeight + 6 : 0

            Scaler {
                id: scaler
                currentWidth: volumeWindow.modelData ? volumeWindow.modelData.width : 1920
            }

            implicitWidth:  scaler.s(480)
            implicitHeight: scaler.s(760)

            // Focus grab alleen actief op het zichtbare scherm; onCleared sluit
            // alleen als déze instantie de actieve is.
            HyprlandFocusGrab {
                id: focusGrab
                windows: [volumeWindow]
                active: false
                onCleared: {
                    if (volumeWindow.isActiveScreen) volumeScope.open = false;
                }
            }

            Connections {
                target: volumeScope
                function onOpenChanged() {
                    if (volumeScope.open && volumeWindow.isActiveScreen) {
                        grabDelayTimer.start();
                    } else {
                        focusGrab.active = false;
                    }
                }
            }

            Timer {
                id: grabDelayTimer
                interval: 50
                repeat: false
                onTriggered: focusGrab.active = true
            }

            Item {
                anchors.fill: parent
                focus: volumeWindow.visible

                Keys.onEscapePressed: {
                    volumeScope.open = false;
                    event.accepted = true;
                }

                VolumePopup {
                    anchors.fill: parent
                }
            }
        }
    }

    IpcHandler {
        target: "volume"
        function toggle() {
            if (!volumeScope.open) {
                // Leg het gefocuste scherm vast vóór de popup opent.
                let mon = Hyprland.focusedMonitor;
                volumeScope.activeMonitorId = mon ? mon.id : -1;
            }
            volumeScope.open = !volumeScope.open;
        }
        function open() {
            let mon = Hyprland.focusedMonitor;
            volumeScope.activeMonitorId = mon ? mon.id : -1;
            volumeScope.open = true;
        }
        function close() { volumeScope.open = false }
    }
}
