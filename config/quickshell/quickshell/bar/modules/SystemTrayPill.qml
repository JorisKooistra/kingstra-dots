import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray

// Right-bar pill: system tray icons.
// shell must be the barWindow (PanelWindow) — used as anchor.window for context menus.
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx   // BarContent root — supplies theme chrome colors/flags

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    Layout.alignment: Qt.AlignVCenter
    radius: surface.panelRadius
    topLeftRadius: ctx.panelTopLeftRadius
    topRightRadius: ctx.panelTopRightRadius
    bottomLeftRadius: ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.color: ctx.rightGroupBorderColor
    border.width: 1
    color: ctx.rightGroupColor
    clip: true

    property real targetWidth: trayLayout.width > 0 ? trayLayout.width + shell.s(24) : 0
    Layout.preferredWidth: targetWidth
    Behavior on targetWidth { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }

    visible: targetWidth > 0
    opacity: targetWidth > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }

    function trayField(item, key) {
        try {
            var value = item[key];
            return value === undefined || value === null ? "" : String(value);
        } catch(e) {
            return "";
        }
    }

    function isHiddenTrayItem(item) {
        var haystack = [
            trayField(item, "id"),
            trayField(item, "title"),
            trayField(item, "tooltipTitle"),
            trayField(item, "icon")
        ].join(" ").toLowerCase();

        return haystack.indexOf("nm-applet") !== -1
            || haystack.indexOf("networkmanager") !== -1
            || haystack.indexOf("nm-signal") !== -1
            || haystack.indexOf("network-wireless-signal") !== -1;
    }

    // Cyber bottom tick line
    Rectangle {
        visible: ctx.cyberChrome
        anchors.left: parent.left; anchors.leftMargin: shell.s(8)
        anchors.right: parent.right; anchors.rightMargin: shell.s(8)
        anchors.bottom: parent.bottom; anchors.bottomMargin: shell.s(4)
        height: 1
        color: ctx.cyberModuleTickColor
        opacity: 0.48
    }

    Row {
        id: trayLayout
        anchors.centerIn: parent
        spacing: shell.s(10)

        Repeater {
            id: trayRepeater
            model: SystemTray.items
            delegate: Image {
                id: trayIcon
                property bool hiddenTrayItem: root.isHiddenTrayItem(modelData)
                source: modelData.icon || ""
                fillMode: Image.PreserveAspectFit
                sourceSize: Qt.size(shell.s(18), shell.s(18))
                visible: !hiddenTrayItem
                width: visible ? shell.s(18) : 0; height: visible ? shell.s(18) : 0
                anchors.verticalCenter: parent.verticalCenter

                property bool isHovered: trayMouse.containsMouse
                property bool initAnimTrigger: false

                opacity: initAnimTrigger ? (ctx.cyberChrome ? 1.0 : (isHovered ? 1.0 : 0.8)) : 0.0
                scale:   initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                Component.onCompleted: {
                    if (!shell.startupCascadeFinished) {
                        trayAnimTimer.interval = index * 50;
                        trayAnimTimer.start();
                    } else {
                        initAnimTrigger = true;
                    }
                }
                Timer {
                    id: trayAnimTimer; running: false; repeat: false
                    onTriggered: trayIcon.initAnimTrigger = true
                }

                Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                Behavior on scale  { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                QsMenuAnchor {
                    id: menuAnchor
                    anchor.window: shell   // shell IS the barWindow PanelWindow
                    anchor.item: trayIcon
                    menu: modelData.menu
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.menu) {
                                menuAnchor.open();
                            } else if (typeof modelData.contextMenu === "function") {
                                modelData.contextMenu(mouse.x, mouse.y);
                            }
                        }
                    }
                }
            }
        }
    }
}
