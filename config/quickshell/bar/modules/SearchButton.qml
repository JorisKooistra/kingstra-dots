import QtQuick
import QtQuick.Layouts
import Quickshell

// Left-bar button: opens the walker launcher.
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx   // BarContent root — supplies theme chrome colors/flags

    property bool isHovered: searchMouse.containsMouse

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    Layout.preferredWidth: shell.barHeight
    Layout.alignment: Qt.AlignVCenter

    color: ctx.cyberChrome
           ? (isHovered ? ctx.cyberModuleHoverColor : ctx.cyberModuleColor)
           : (isHovered ? surface.panelHoverColor : surface.panelColor)
    radius: surface.panelRadius
    topLeftRadius: ctx.panelTopLeftRadius
    topRightRadius: ctx.panelTopRightRadius
    bottomLeftRadius: ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.width: 1
    border.color: ctx.cyberChrome
                  ? (isHovered ? ctx.cyberModuleBorderHoverColor : ctx.cyberModuleBorderColor)
                  : (isHovered ? ctx.themeAccentBorderHoverColor : ctx.themeAccentBorderColor)

    scale: isHovered ? 1.05 : 1.0
    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Text {
        anchors.centerIn: parent
        text: "󰍉"
        font.family: "Iosevka Nerd Font"
        font.pixelSize: shell.s(24)
        color: ctx.cyberChrome
               ? (root.isHovered ? ctx.cyberTextHotColor : ctx.cyberTextColor)
               : (root.isHovered ? mocha.blue : mocha.text)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Cyber bottom tick line
    Rectangle {
        visible: ctx.cyberChrome
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: shell.s(4)
        width: root.isHovered ? shell.s(18) : shell.s(10)
        height: 1
        color: ctx.cyberModuleTickColor
        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        id: searchMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "walker"])
    }
}
