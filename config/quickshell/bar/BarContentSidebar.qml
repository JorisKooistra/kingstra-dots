import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import ".."
import "../clock"

Item {
    id: root
    required property var shell
    required property var surface
    required property var mocha

    property var currentDate: new Date()
    readonly property bool compactAnimatedSidebar: ThemeConfig.barTemplate === "compact-sidebar"
                                                  || String(shell.activeThemeName || "").toLowerCase() === "animated"
    readonly property int outerMargin: compactAnimatedSidebar ? shell.s(4) : (shell.edgeAttachedBar ? shell.s(8) : shell.s(10))
    readonly property bool flattenScreenEdgeCorners: shell.edgeAttachedBar
                                                     && String(shell.activeThemeName || "").toLowerCase() === "botanical"
    readonly property int panelTopLeftRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelTopRightRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property int panelBottomLeftRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelBottomRightRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property int sectionSpacing: shell.s(compactAnimatedSidebar ? 5 : 6)
    readonly property int moduleHeight: shell.s(compactAnimatedSidebar ? 28 : 32)
    readonly property int iconButtonSize: shell.s(compactAnimatedSidebar ? 28 : 32)
    readonly property int moduleInnerMargin: shell.s(compactAnimatedSidebar ? 0 : 8)
    readonly property int moduleSpacing: shell.s(compactAnimatedSidebar ? 0 : 8)
    readonly property string compactTimeText: {
        if (compactAnimatedSidebar) return Qt.formatDateTime(currentDate, "hh:mm");
        let parts = String(shell.timeStr || "--:--").split(":");
        if (parts.length >= 2) return parts[0] + ":" + parts[1];
        return String(shell.timeStr || "--:--");
    }
    readonly property string compactSecondsText: {
        if (compactAnimatedSidebar) return "";
        let parts = String(shell.timeStr || "").split(":");
        if (parts.length < 3) return "";
        let seconds = parts[2].replace(/[^0-9].*$/, "");
        return seconds !== "" ? seconds : "";
    }
    readonly property string compactDateText: Qt.formatDateTime(currentDate, "ddd dd")
    readonly property string compactWeatherText: {
        let txt = String(shell.weatherTemp || "--°").replace("°C", "°").replace(" C", "");
        return txt;
    }

    function _titleTextColor(active) {
        return active ? mocha.base : mocha.text;
    }

    function _subtitleTextColor(active) {
        return active ? Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.85) : mocha.subtext0;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.outerMargin
        spacing: root.sectionSpacing

        Rectangle {
            id: infoCard
            Layout.fillWidth: true
            Layout.preferredHeight: shell.s(compactAnimatedSidebar ? 76 : 88)
            radius: surface.panelRadius
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
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
                anchors.margins: shell.s(compactAnimatedSidebar ? 6 : 8)
                spacing: shell.s(compactAnimatedSidebar ? 2 : 3)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(root.compactAnimatedSidebar ? 0 : 3)

                    Text {
                        text: root.compactTimeText
                        Layout.fillWidth: true
                        font.family: shell.displayFontFamily
                        font.pixelSize: shell.s(root.compactAnimatedSidebar ? 12 : 15)
                        minimumPixelSize: shell.s(9)
                        fontSizeMode: Text.Fit
                        font.weight: Font.Black
                        font.letterSpacing: 0
                        color: mocha.yellow
                        horizontalAlignment: root.compactAnimatedSidebar ? Text.AlignHCenter : Text.AlignRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.compactSecondsText !== ""
                        text: root.compactSecondsText
                        Layout.preferredWidth: shell.s(root.compactAnimatedSidebar ? 11 : 15)
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(root.compactAnimatedSidebar ? 7 : 9)
                        minimumPixelSize: shell.s(6)
                        fontSizeMode: Text.Fit
                        font.weight: Font.Bold
                        font.letterSpacing: 0
                        color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.72)
                        horizontalAlignment: Text.AlignLeft
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    text: root.compactDateText
                    Layout.fillWidth: true
                    font.family: shell.uiFontFamily
                    font.pixelSize: shell.s(root.compactAnimatedSidebar ? 8 : 10)
                    minimumPixelSize: shell.s(7)
                    fontSizeMode: Text.Fit
                    font.weight: Font.DemiBold
                    font.letterSpacing: 0
                    color: mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(4)
                    Text {
                        text: shell.weatherIcon
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(root.compactAnimatedSidebar ? 13 : 15)
                        color: Qt.tint(shell.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4))
                    }
                    Text {
                        text: root.compactWeatherText
                        Layout.fillWidth: true
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(root.compactAnimatedSidebar ? 8 : 10)
                        minimumPixelSize: shell.s(7)
                        fontSizeMode: Text.Fit
                        font.weight: shell.themeFontWeight
                        font.letterSpacing: 0
                        color: mocha.peach
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideNone
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: shell.s(5)

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
                    font.pixelSize: shell.s(root.compactAnimatedSidebar ? 15 : 18)
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
                    font.pixelSize: shell.s(root.compactAnimatedSidebar ? 14 : 16)
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
            visible: shell.moduleList.includes("workspaces")
            Layout.fillWidth: true
            Layout.preferredHeight: wsColumn.implicitHeight + shell.s(16)
            radius: surface.panelRadius
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
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
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        property int wsId: index + 1
                        property bool hovered: wsMouse.containsMouse

                        property string stateLabel: {
                            if (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId)
                                return "active";
                            var wsList = Hyprland.workspaces;
                            for (var i = 0; i < wsList.length; i++) {
                                if (wsList[i].id === wsId)
                                    return wsList[i].windows > 0 ? "occupied" : "empty";
                            }
                            return "empty";
                        }

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
                            text: wsId.toString()
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
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsId])
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
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor

            ColumnLayout {
                id: mediaCard
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(4)

                readonly property var player: shell._activePlayer

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
                            onClicked: { if (mediaCard.player && mediaCard.player.canGoPrevious) mediaCard.player.previous(); }
                        }
                    }
                    Text {
                        text: shell.musicData.status === "Playing" ? "󰏤" : "󰐊"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(20)
                        color: mocha.green
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { if (mediaCard.player && mediaCard.player.canTogglePlaying) mediaCard.player.togglePlaying(); }
                        }
                    }
                    Text {
                        text: "󰒭"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: shell.s(18)
                        color: mocha.overlay2
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { if (mediaCard.player && mediaCard.player.canGoNext) mediaCard.player.next(); }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            id: trayPanel
            Layout.fillWidth: true
            Layout.preferredHeight: trayColumn.implicitHeight + shell.s(16)
            visible: trayColumn.implicitHeight > 0
            radius: surface.panelRadius
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
            border.width: 1
            border.color: surface.panelBorderColor
            color: surface.panelColor

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
                        property bool hiddenTrayItem: trayPanel.isHiddenTrayItem(modelData)
                        visible: !hiddenTrayItem
                        width: trayColumn.width
                        height: visible ? shell.s(28) : 0
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
            visible: shell.kbLayoutCount > 1
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: root.iconButtonSize
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            color: kbMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
            Text {
                anchors.centerIn: parent
                text: shell.kbLayout
                font.family: shell.monoFontFamily
                font.pixelSize: shell.s(12)
                font.weight: Font.Black
                font.letterSpacing: shell.themeLetterSpacing
                color: kbMouse.containsMouse ? mocha.text : mocha.overlay2
            }
            MouseArea {
                id: kbMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: shell.switchKeyboardLayout()
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
                visible: !root.compactAnimatedSidebar
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
            Row {
                visible: root.compactAnimatedSidebar
                anchors.centerIn: parent
                spacing: shell.s(4)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰚰"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(13)
                    color: shell.updateCount > 0 ? mocha.yellow : mocha.subtext0
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (parseInt(shell.updateCount) || 0).toString()
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(10)
                    font.weight: Font.Bold
                    font.letterSpacing: 0
                    color: shell.updateCount > 0 ? mocha.text : mocha.subtext0
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
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.wifiIcon
                    Layout.fillWidth: root.compactAnimatedSidebar
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isWifiOn ? mocha.blue : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: !root.compactAnimatedSidebar
                    text: shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "On") : "Off"
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
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.btIcon
                    Layout.fillWidth: root.compactAnimatedSidebar
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isBtOn ? mocha.mauve : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: !root.compactAnimatedSidebar
                    text: shell.btDevice
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
                visible: !root.compactAnimatedSidebar
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
            Row {
                visible: root.compactAnimatedSidebar
                anchors.centerIn: parent
                spacing: shell.s(4)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.volIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(13)
                    color: shell.isSoundActive ? mocha.peach : mocha.subtext0
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.volPercent
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(10)
                    font.weight: Font.Bold
                    font.letterSpacing: 0
                    color: shell.isSoundActive ? mocha.text : mocha.subtext0
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
                visible: !root.compactAnimatedSidebar
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
            Row {
                visible: root.compactAnimatedSidebar
                anchors.centerIn: parent
                spacing: shell.s(4)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.batIcon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(13)
                    color: shell.batDynamicColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: shell.batPercent
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(10)
                    font.weight: Font.Bold
                    font.letterSpacing: 0
                    color: shell.batDynamicColor
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
