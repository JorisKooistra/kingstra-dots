import QtQuick
import QtQuick.Layouts
import Quickshell

// Compacte mediabalk-pill: prev · play/pause · titel · next
// Data via shell.mediaTitle / shell.mediaStatus (playerctl-polling in BarShell).
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx

    readonly property bool _isPlaying: shell.mediaStatus === "Playing"
    readonly property bool _isActive:  shell.mediaStatus === "Playing" || shell.mediaStatus === "Paused"

    // ── Layout ────────────────────────────────────────────────────────────────
    Layout.preferredHeight: ctx.cyberSideModuleHeight
    Layout.alignment: Qt.AlignVCenter
    clip: true

    property real targetWidth: _isActive ? shell.s(196) : 0
    Layout.preferredWidth: targetWidth
    visible: _isActive || opacity > 0
    opacity: _isActive ? 1.0 : 0.0

    Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on opacity     { NumberAnimation { duration: 300 } }

    // ── Styling ───────────────────────────────────────────────────────────────
    color: ctx.cyberChrome ? ctx.cyberModuleColor : surface.panelColor
    radius: surface.panelRadius
    topLeftRadius:     ctx.panelTopLeftRadius
    topRightRadius:    ctx.panelTopRightRadius
    bottomLeftRadius:  ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.width: 1
    border.color: ctx.cyberChrome ? ctx.cyberModuleBorderColor : ctx.themeAccentBorderColor

    Rectangle {
        visible: ctx.cyberChrome
        anchors.left: parent.left;   anchors.leftMargin: shell.s(10)
        anchors.right: parent.right;  anchors.rightMargin: shell.s(10)
        anchors.bottom: parent.bottom; anchors.bottomMargin: shell.s(4)
        height: 1
        color: ctx.cyberModuleTickColor
        opacity: root._isActive ? 0.62 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    // ── Controls ──────────────────────────────────────────────────────────────
    Row {
        anchors.centerIn: parent
        spacing: shell.s(4)

        Item {
            width: shell.s(22); height: shell.s(22)
            Text {
                anchors.centerIn: parent; text: "󰒮"
                font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(20)
                color: prevMouse.containsMouse ? mocha.text : mocha.overlay2
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: prevMouse.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
            MouseArea {
                id: prevMouse; anchors.fill: parent; hoverEnabled: true
                onClicked: Quickshell.execDetached(["playerctl", "previous"])
            }
        }

        Item {
            width: shell.s(24); height: shell.s(24)
            Text {
                anchors.centerIn: parent
                text: root._isPlaying ? "󰏤" : "󰐊"
                font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(22)
                color: playMouse.containsMouse ? mocha.green : mocha.text
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: playMouse.containsMouse ? 1.15 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
            MouseArea {
                id: playMouse; anchors.fill: parent; hoverEnabled: true
                onClicked: Quickshell.execDetached(["playerctl", "play-pause"])
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: shell.mediaTitle
            font.family: shell.monoFontFamily
            font.pixelSize: shell.s(11)
            font.weight: Font.Bold
            color: mocha.text
            width: shell.s(90)
            elide: Text.ElideRight
        }

        Item {
            width: shell.s(22); height: shell.s(22)
            Text {
                anchors.centerIn: parent; text: "󰒭"
                font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(20)
                color: nextMouse.containsMouse ? mocha.text : mocha.overlay2
                Behavior on color { ColorAnimation { duration: 150 } }
                scale: nextMouse.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            }
            MouseArea {
                id: nextMouse; anchors.fill: parent; hoverEnabled: true
                onClicked: Quickshell.execDetached(["playerctl", "next"])
            }
        }
    }
}
