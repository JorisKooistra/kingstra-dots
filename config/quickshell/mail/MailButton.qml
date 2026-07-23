import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx

    property bool isHovered: mailMouse.containsMouse

    visible: shell.moduleList.includes("mail")
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
        text: "󰇮"
        font.family: "Iosevka Nerd Font"
        font.pixelSize: shell.s(18)
        color: root.isHovered ? mocha.blue : mocha.text
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    Rectangle {
        visible: MailService.badgeText !== ""
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: shell.s(3)
        anchors.rightMargin: shell.s(3)
        width: Math.max(shell.s(16), badgeLabel.implicitWidth + shell.s(6))
        height: shell.s(16)
        radius: height / 2
        color: mocha.red

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: MailService.badgeText
            font.family: shell.monoFontFamily
            font.pixelSize: shell.s(9)
            font.weight: Font.Black
            color: mocha.base
        }
    }

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
        id: mailMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton)
                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "mail"]);
            if (mouse.button === Qt.RightButton)
                MailService.openThunderbird();
        }
    }
}
