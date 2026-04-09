import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../clock"

Item {
    id: root
    required property var shell
    required property var surface
    required property var mocha

    readonly property int outerMargin: shell.edgeAttachedBar ? shell.s(8) : shell.s(10)
    readonly property int sectionSpacing: shell.s(6)
    readonly property int moduleHeight: shell.s(34)
    readonly property int iconButtonSize: shell.s(34)

    function _titleTextColor(active) {
        return active ? mocha.base : mocha.text;
    }

    function _subtitleTextColor(active) {
        return active ? Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.85) : mocha.subtext0;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.outerMargin
        spacing: root.sectionSpacing

        Rectangle {
            id: infoCard
            Layout.fillWidth: true
            Layout.preferredHeight: shell.s(98)
            radius: surface.panelRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: shell.s(10)
                spacing: shell.s(4)

                Item {
                    Layout.fillWidth: true
                    implicitHeight: clockLoader.implicitHeight

                    Loader {
                        id: clockLoader
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: {
                            let style = String(shell.clockStyle || "digital").toLowerCase();
                            if (style === "analog") return analogClockComponent;
                            if (style === "hybrid") return hybridClockComponent;
                            return digitalClockComponent;
                        }
                    }

                    Component {
                        id: digitalClockComponent
                        DigitalClock { shell: root.shell; mocha: root.mocha }
                    }

                    Component {
                        id: analogClockComponent
                        RowLayout {
                            spacing: shell.s(8)
                            AnalogClock {
                                shell: root.shell
                                mocha: root.mocha
                                showSecondHand: false
                            }
                            Text {
                                text: shell.timeStr
                                Layout.alignment: Qt.AlignVCenter
                                font.family: shell.displayFontFamily
                                font.pixelSize: shell.s(12)
                                font.weight: shell.themeFontWeight
                                font.letterSpacing: shell.themeLetterSpacing
                                color: mocha.blue
                            }
                        }
                    }

                    Component {
                        id: hybridClockComponent
                        RowLayout {
                            spacing: shell.s(8)
                            AnalogClock {
                                shell: root.shell
                                mocha: root.mocha
                                showSecondHand: false
                            }
                            ColumnLayout {
                                spacing: shell.s(1)
                                Text {
                                    text: shell.timeStr
                                    font.family: shell.displayFontFamily
                                    font.pixelSize: shell.s(12)
                                    font.weight: shell.themeFontWeight
                                    font.letterSpacing: shell.themeLetterSpacing
                                    color: mocha.blue
                                }
                                Text {
                                    text: shell.fullDateStr
                                    font.family: shell.monoFontFamily
                                    font.pixelSize: shell.s(9)
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(6)
                    Text {
                        text: shell.weatherIcon
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(18)
                        color: Qt.tint(shell.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4))
                    }
                    Text {
                        text: shell.weatherTemp
                        Layout.fillWidth: true
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(12)
                        font.weight: shell.themeFontWeight
                        font.letterSpacing: shell.themeLetterSpacing
                        color: mocha.peach
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: shell.s(6)

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.iconButtonSize
                radius: surface.innerPillRadius
                color: searchMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
                border.width: 1
                border.color: searchMouse.containsMouse ? surface.panelBorderHoverColor : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰍉"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(18)
                    color: searchMouse.containsMouse ? mocha.blue : mocha.text
                }
                MouseArea {
                    id: searchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["bash", "-c", "walker"])
                }
            }

            Rectangle {
                visible: shell.moduleList.includes("notifications")
                Layout.fillWidth: true
                Layout.preferredHeight: root.iconButtonSize
                radius: surface.innerPillRadius
                color: notifMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
                border.width: 1
                border.color: notifMouse.containsMouse ? surface.panelBorderHoverColor : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(16)
                    color: notifMouse.containsMouse ? mocha.yellow : mocha.text
                }
                MouseArea {
                    id: notifMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
                        if (mouse.button === Qt.RightButton) Quickshell.execDetached(["swaync-client", "-d"]);
                    }
                }
            }
        }

        Rectangle {
            id: workspacesCard
            visible: shell.moduleList.includes("workspaces") && workspacesModel.count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: wsColumn.implicitHeight + shell.s(16)
            radius: surface.panelRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor
            clip: true

            Column {
                id: wsColumn
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(5)

                Repeater {
                    model: workspacesModel
                    delegate: Rectangle {
                        property string stateLabel: model.wsState
                        property string wsName: model.wsId
                        property bool hovered: wsMouse.containsMouse
                        width: wsColumn.width
                        height: shell.s(30)
                        radius: surface.innerPillRadius
                        color: stateLabel === "active"
                                ? mocha.mauve
                                : (hovered
                                    ? Qt.rgba(mocha.overlay0.r, mocha.overlay0.g, mocha.overlay0.b, 0.9)
                                    : (stateLabel === "occupied"
                                        ? Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.9)
                                        : "transparent"))
                        border.width: stateLabel === "empty" ? 1 : 0
                        border.color: Qt.rgba(mocha.overlay0.r, mocha.overlay0.g, mocha.overlay0.b, 0.5)

                        Text {
                            anchors.centerIn: parent
                            text: wsName
                            font.family: shell.monoFontFamily
                            font.pixelSize: shell.s(13)
                            font.weight: stateLabel === "active" ? Font.Black : Font.Bold
                            font.letterSpacing: shell.themeLetterSpacing
                            color: stateLabel === "active" ? mocha.crust : mocha.text
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsName])
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("media_controls") && shell.isMediaActive
            Layout.fillWidth: true
            Layout.preferredHeight: shell.s(74)
            radius: surface.panelRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(4)

                Text {
                    text: shell.musicData.title
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: Font.Bold
                    color: mocha.text
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(10)
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "󰒮"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(18)
                        color: mocha.overlay2
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "previous"]);
                                Quickshell.execDetached(["bash", "-c", "bash ~/.config/quickshell/music/music_info.sh > /tmp/music_info.json"]);
                            }
                        }
                    }
                    Text {
                        text: shell.musicData.status === "Playing" ? "󰏤" : "󰐊"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(20)
                        color: mocha.green
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "play-pause"]);
                                Quickshell.execDetached(["bash", "-c", "bash ~/.config/quickshell/music/music_info.sh > /tmp/music_info.json"]);
                            }
                        }
                    }
                    Text {
                        text: "󰒭"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(18)
                        color: mocha.overlay2
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Quickshell.execDetached(["playerctl", "next"]);
                                Quickshell.execDetached(["bash", "-c", "bash ~/.config/quickshell/music/music_info.sh > /tmp/music_info.json"]);
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: trayColumn.implicitHeight + shell.s(16)
            visible: trayRepeater.count > 0
            radius: surface.panelRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor

            Column {
                id: trayColumn
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(6)

                Repeater {
                    id: trayRepeater
                    model: SystemTray.items
                    delegate: Rectangle {
                        required property var modelData
                        width: trayColumn.width
                        height: shell.s(28)
                        radius: surface.innerPillRadius
                        color: trayMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
                        Image {
                            anchors.centerIn: parent
                            source: modelData.icon || ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize: Qt.size(shell.s(16), shell.s(16))
                            width: shell.s(16)
                            height: shell.s(16)
                        }
                        QsMenuAnchor {
                            id: menuAnchor
                            anchor.window: shell
                            anchor.item: parent
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: surface.innerPillColor
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: "󰌌"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: mocha.overlay2
                }
                Text {
                    text: shell.kbLayout
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(12)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: mocha.text
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("updates")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: updatesMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            border.width: 1
            border.color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.4)
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: "󰚰"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.updateCount > 0 ? mocha.yellow : mocha.subtext0
                }
                Text {
                    text: (parseInt(shell.updateCount) || 0).toString()
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(12)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.updateCount > 0 ? mocha.text : mocha.subtext0
                    horizontalAlignment: Text.AlignRight
                }
            }
            MouseArea {
                id: updatesMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: shell.openUpdatesTerminal()
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("network")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: wifiMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: shell.wifiIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isWifiOn ? mocha.blue : mocha.subtext0
                }
                Text {
                    text: shell.sysPollerLoaded ? (shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "On") : "Off") : ""
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.isWifiOn ? mocha.text : mocha.subtext0
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"])
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("bluetooth")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: btMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: shell.btIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isBtOn ? mocha.mauve : mocha.subtext0
                }
                Text {
                    text: shell.sysPollerLoaded ? shell.btDevice : ""
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.isBtOn ? mocha.text : mocha.subtext0
                    elide: Text.ElideRight
                }
            }
            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"])
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("volume")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: volMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: shell.volIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isSoundActive ? mocha.peach : mocha.subtext0
                }
                Text {
                    text: shell.volPercent
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.isSoundActive ? mocha.text : mocha.subtext0
                    horizontalAlignment: Text.AlignRight
                }
            }
            MouseArea {
                id: volMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"])
                onWheel: (wheel) => {
                    shell.handleVolumeWheel(wheel.angleDelta.y);
                    wheel.accepted = true;
                }
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("battery")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: batMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            RowLayout {
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Text {
                    text: shell.batIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.batDynamicColor
                }
                Text {
                    text: shell.batPercent
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.batDynamicColor
                    horizontalAlignment: Text.AlignRight
                }
            }
            MouseArea {
                id: batMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"])
            }
        }
    }
}
