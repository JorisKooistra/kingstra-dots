import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../overview/common/functions/HyprDispatch.js" as Lua

Scope {
    id: root
    property var zooms: ({})
    FileView {
        id: state
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/kingstra-native-zoom.json"
        watchChanges: true
        onLoaded: {
            try { root.zooms = JSON.parse(text()); }
            catch (e) { root.zooms = ({}); }
        }
        onLoadFailed: root.zooms = ({})
    }
    Timer { interval: 150; running: true; repeat: true; onTriggered: state.reload() }
    Variants {
        model: Quickshell.screens
        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData
                visible: Number(root.zooms[modelData.name] || 1) < 0.999
                anchors { bottom: true; right: true }
                margins { bottom: 56; right: 84 }
                implicitWidth: 196
                implicitHeight: 44
                color: "transparent"
                WlrLayershell.namespace: "quickshell:kingstra-native-zoom"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.exclusiveZone: -1
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                MatugenColors { id: zoomPalette }
                readonly property color labelColor: zoomPalette.materialOnPrimary
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: mouse.containsMouse ? Qt.lighter(zoomPalette.primary, 1.08) : zoomPalette.primary
                    border.width: 1
                    border.color: zoomPalette.primary
                    Text {
                        anchors.centerIn: parent
                        text: Math.round(Number(root.zooms[win.modelData.name] || 1) * 100) + "%  ·  ↺ Reset 100%"
                        color: win.labelColor
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([
                            "hyprctl", "eval", "require(\"lua.native-zoom\").reset(" + Lua.quote(win.modelData.name) + ")"
                        ])
                    }
                }
            }
        }
    }
}
