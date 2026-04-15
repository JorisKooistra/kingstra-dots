import QtQuick
import QtQuick.Layouts
import Quickshell

// Left-bar pill: clickable workspace indicator dots.
// workspacesModel is a ListModel owned by barWindow (BarShell) and passed in explicitly.
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx           // BarContent root — supplies theme chrome colors/flags
    required property var workspacesModel

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    property real targetWidth: workspacesModel.count > 0 ? wsLayout.width + shell.s(20) : 0
    Layout.preferredWidth: targetWidth
    visible: targetWidth > 0 && shell.moduleList.includes("workspaces")
    opacity: workspacesModel.count > 0 ? 1 : 0
    clip: true

    color: ctx.cyberChrome ? ctx.cyberModuleColor : surface.panelColor
    radius: surface.panelRadius
    topLeftRadius: ctx.panelTopLeftRadius
    topRightRadius: ctx.panelTopRightRadius
    bottomLeftRadius: ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.width: 1
    border.color: ctx.cyberChrome ? ctx.cyberModuleBorderColor : ctx.themeAccentBorderColor

    Behavior on opacity { NumberAnimation { duration: 300 } }

    // Cyber bottom tick line
    Rectangle {
        visible: ctx.cyberChrome
        anchors.left: parent.left; anchors.leftMargin: shell.s(10)
        anchors.right: parent.right; anchors.rightMargin: shell.s(10)
        anchors.bottom: parent.bottom; anchors.bottomMargin: shell.s(4)
        height: 1
        color: ctx.cyberModuleTickColor
        opacity: 0.52
    }

    Row {
        id: wsLayout
        anchors.centerIn: parent
        spacing: shell.s(6)

        Repeater {
            model: workspacesModel
            delegate: Rectangle {
                id: wsPill
                property bool isHovered: wsPillMouse.containsMouse
                property string stateLabel: model.wsState
                property string wsName: model.wsId

                property real targetWidth: shell.s(32)
                width: targetWidth
                Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                height: shell.s(32)
                radius: surface.innerPillRadius

                color: stateLabel === "active"
                        ? (ctx.cyberChrome ? ctx.cyberWorkspaceActiveColor : mocha.mauve)
                        : (isHovered
                            ? (ctx.cyberChrome
                                ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, 0.26)
                                : Qt.rgba(mocha.overlay0.r, mocha.overlay0.g, mocha.overlay0.b, 0.9))
                            : (stateLabel === "occupied"
                                ? (ctx.cyberChrome
                                    ? ctx.cyberWorkspaceOccupiedColor
                                    : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.9))
                                : "transparent"))

                scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                // Staggered entry animation
                property bool initAnimTrigger: false
                opacity: initAnimTrigger ? 1 : 0
                transform: Translate {
                    y: wsPill.initAnimTrigger ? 0 : shell.s(15)
                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                }
                Component.onCompleted: {
                    if (!shell.startupCascadeFinished) {
                        animTimer.interval = index * 60;
                        animTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }
                Timer {
                    id: animTimer
                    running: false; repeat: false
                    onTriggered: wsPill.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 250 } }

                Text {
                    anchors.centerIn: parent
                    text: wsName
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(14)
                    font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)
                    font.letterSpacing: shell.themeLetterSpacing
                    color: stateLabel === "active"
                            ? (ctx.cyberChrome ? mocha.base : mocha.crust)
                            : (isHovered
                                ? (ctx.cyberChrome ? mocha.text : mocha.crust)
                                : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))
                    Behavior on color { ColorAnimation { duration: 250 } }
                }

                MouseArea {
                    id: wsPillMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                }
            }
        }
    }
}
