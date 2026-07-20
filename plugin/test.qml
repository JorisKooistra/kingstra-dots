import QtQuick
import Quickshell
import Quickshell.Wayland
import Kingstra.Test 1.0

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
        }

        implicitWidth: 240
        implicitHeight: 160
        color: "#1a1a24"

        WlrLayershell.namespace: "quickshell:kingstra-plugin-test"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        TestRect {
            anchors.fill: parent
            anchors.margins: 16
            fillColor: "#00d7ff"
        }

        Text {
            anchors.centerIn: parent
            text: "Native QML plugin"
            color: "#10131a"
            font.bold: true
            font.pixelSize: 20
        }
    }
}
