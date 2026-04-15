import QtQuick
import QtQuick.Layouts
import Quickshell

// Left-bar pill: now-playing info + prev/play/next controls.
// musicRefreshProc is the Process owned by barWindow (BarShell) that force-refreshes music state.
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx           // BarContent root — supplies theme chrome colors/flags
    required property var musicRefreshProc  // barWindow.musicForceRefresh

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    clip: true

    property bool isMediaMode: shell.activeMode === "media"
    property real targetWidth: shell.isMediaActive ? mediaLayoutContainer.width + shell.s(24) : 0
    Layout.maximumWidth: isMediaMode ? shell.s(220) : targetWidth
    Layout.preferredWidth: targetWidth
    visible: (targetWidth > 0 || opacity > 0) && shell.moduleList.includes("media_controls")
    opacity: shell.isMediaActive ? 1.0 : 0.0

    color: ctx.cyberChrome ? ctx.cyberModuleColor : surface.panelColor
    radius: surface.panelRadius
    topLeftRadius: ctx.panelTopLeftRadius
    topRightRadius: ctx.panelTopRightRadius
    bottomLeftRadius: ctx.panelBottomLeftRadius
    bottomRightRadius: ctx.panelBottomRightRadius
    border.width: 1
    border.color: ctx.cyberChrome ? ctx.cyberModuleBorderColor : ctx.themeAccentBorderColor

    Behavior on targetWidth { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
    Behavior on opacity { NumberAnimation { duration: 400 } }

    // Cyber bottom tick line
    Rectangle {
        visible: ctx.cyberChrome
        anchors.left: parent.left; anchors.leftMargin: shell.s(10)
        anchors.right: parent.right; anchors.rightMargin: shell.s(10)
        anchors.bottom: parent.bottom; anchors.bottomMargin: shell.s(4)
        height: 1
        color: ctx.cyberModuleTickColor
        opacity: shell.isMediaActive ? 0.62 : 0.0
        Behavior on opacity { NumberAnimation { duration: 250 } }
    }

    Item {
        id: mediaLayoutContainer
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: shell.s(12)
        height: parent.height
        width: innerMediaLayout.width

        opacity: shell.isMediaActive ? 1.0 : 0.0
        transform: Translate {
            x: shell.isMediaActive ? 0 : shell.s(-20)
            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
        }
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Row {
            id: innerMediaLayout
            anchors.verticalCenter: parent.verticalCenter
            spacing: shell.width < 1920 ? shell.s(8) : shell.s(16)

            // Song info (click opens music popup)
            MouseArea {
                id: mediaInfoMouse
                width: infoLayout.width
                height: innerMediaLayout.height
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])

                Row {
                    id: infoLayout
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: shell.s(10)
                    scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                    // Album art
                    Rectangle {
                        width: shell.s(32); height: shell.s(32); radius: shell.s(8)
                        color: mocha.surface1
                        border.width: shell.musicData.status === "Playing" ? 1 : 0
                        border.color: mocha.mauve
                        clip: true
                        Image {
                            anchors.fill: parent
                            source: shell.musicData.artUrl || ""
                            fillMode: Image.PreserveAspectCrop
                        }
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                        }
                    }

                    // Title + timestamp
                    Column {
                        spacing: -2
                        anchors.verticalCenter: parent.verticalCenter
                        property real maxColWidth: shell.width < 1920 ? shell.s(120) : shell.s(180)
                        width: maxColWidth

                        Text {
                            text: shell.musicData.title
                            font.family: "JetBrains Mono"; font.weight: Font.Black
                            font.pixelSize: root.isMediaMode ? shell.s(11) : shell.s(13)
                            color: mocha.text
                            width: Math.min(parent.width, root.isMediaMode ? shell.s(120) : shell.s(200))
                            elide: Text.ElideRight
                        }
                        Text {
                            text: shell.musicData.timeStr
                            font.family: "JetBrains Mono"; font.weight: Font.Black
                            font.pixelSize: shell.s(10)
                            color: mocha.subtext0
                            width: parent.width; elide: Text.ElideRight
                        }
                    }
                }
            }

            // Playback controls
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: shell.width < 1920 ? shell.s(4) : shell.s(8)

                Item {
                    width: shell.s(24); height: shell.s(24)
                    Text {
                        anchors.centerIn: parent; text: "󰒮"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(26)
                        color: prevMouse.containsMouse ? mocha.text : mocha.overlay2
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: prevMouse.containsMouse ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        id: prevMouse; hoverEnabled: true; anchors.fill: parent
                        onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicRefreshProc.running = true; }
                    }
                }

                Item {
                    width: shell.s(28); height: shell.s(28)
                    Text {
                        anchors.centerIn: parent
                        text: shell.musicData.status === "Playing" ? "󰏤" : "󰐊"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(30)
                        color: playMouse.containsMouse ? mocha.green : mocha.text
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: playMouse.containsMouse ? 1.15 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        id: playMouse; hoverEnabled: true; anchors.fill: parent
                        onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicRefreshProc.running = true; }
                    }
                }

                Item {
                    width: shell.s(24); height: shell.s(24)
                    Text {
                        anchors.centerIn: parent; text: "󰒭"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: shell.s(26)
                        color: nextMouse.containsMouse ? mocha.text : mocha.overlay2
                        Behavior on color { ColorAnimation { duration: 150 } }
                        scale: nextMouse.containsMouse ? 1.1 : 1.0
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                    }
                    MouseArea {
                        id: nextMouse; hoverEnabled: true; anchors.fill: parent
                        onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicRefreshProc.running = true; }
                    }
                }
            }
        }
    }
}
