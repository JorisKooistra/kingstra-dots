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
    readonly property bool compactAnimatedSidebar: ThemeConfig.effectiveBarTemplate === "compact-sidebar"
                                                  || String(shell.activeThemeName || "").toLowerCase() === "animated"
    readonly property bool drawerAllowed: ThemeConfig.drawerStyle !== "none"
    readonly property bool drawerOpen: compactAnimatedSidebar && drawerAllowed && shell.sidebarDrawerOpen
    readonly property bool compactRailOnly: compactAnimatedSidebar
    readonly property int railWidth: compactAnimatedSidebar && shell.isVerticalBar ? shell.baseBarThickness : width
    property string drawerKind: "summary"
    property real drawerAnchorY: height * 0.5
    property int drawerWorkspaceId: 1
    property int drawerWorkspaceAnchorId: 0
    property bool pointerInWorkspaces: false
    readonly property int outerMargin: compactAnimatedSidebar ? shell.s(4) : (shell.edgeAttachedBar ? shell.s(8) : shell.s(10))
    readonly property bool flattenScreenEdgeCorners: shell.edgeAttachedBar
                                                     && String(shell.activeThemeName || "").toLowerCase() === "botanical"
    readonly property bool edgeSidebarChrome: flattenScreenEdgeCorners && shell.isVerticalBar
    readonly property int screenEdgeMargin: flattenScreenEdgeCorners ? 0 : outerMargin
    readonly property int panelBorderWidth: edgeSidebarChrome ? 0 : 1
    readonly property int panelTopLeftRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelTopRightRadius: flattenScreenEdgeCorners && (shell.isTopBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property int panelBottomLeftRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isLeftBar) ? 0 : surface.panelRadius
    readonly property int panelBottomRightRadius: flattenScreenEdgeCorners && (shell.isBottomBar || shell.isRightBar) ? 0 : surface.panelRadius
    readonly property int pillTopLeftRadius: edgeSidebarChrome && shell.isLeftBar ? 0 : surface.innerPillRadius
    readonly property int pillTopRightRadius: edgeSidebarChrome && shell.isRightBar ? 0 : surface.innerPillRadius
    readonly property int pillBottomLeftRadius: edgeSidebarChrome && shell.isLeftBar ? 0 : surface.innerPillRadius
    readonly property int pillBottomRightRadius: edgeSidebarChrome && shell.isRightBar ? 0 : surface.innerPillRadius
    readonly property int densityOffset: ThemeConfig.moduleDensity === "minimal" ? -2 : (ThemeConfig.moduleDensity === "rich" ? 2 : 0)
    readonly property int sectionSpacing: shell.s(Math.max(3, (compactRailOnly ? 5 : 6) + densityOffset))
    readonly property int moduleHeight: shell.s(Math.max(24, (compactRailOnly ? 28 : 32) + densityOffset))
    readonly property int iconButtonSize: shell.s(Math.max(24, (compactRailOnly ? 28 : 32) + densityOffset))
    readonly property int moduleInnerMargin: shell.s(compactRailOnly ? 0 : 8)
    readonly property int moduleSpacing: shell.s(compactRailOnly ? 0 : 8)
    readonly property bool statusDockVisible: shell.moduleList.includes("updates")
                                             || shell.moduleList.includes("network")
                                             || shell.moduleList.includes("bluetooth")
                                             || shell.moduleList.includes("volume")
                                             || shell.moduleList.includes("battery")
    readonly property string compactTimeText: {
        if (compactRailOnly) return Qt.formatDateTime(currentDate, "hh:mm");
        let parts = String(shell.timeStr || "--:--").split(":");
        if (parts.length >= 2) return parts[0] + ":" + parts[1];
        return String(shell.timeStr || "--:--");
    }
    readonly property string compactSecondsText: {
        if (compactRailOnly) return "";
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

    function workspaceForId(wsId) {
        var wsList = Hyprland.workspaces.values;
        for (var i = 0; i < wsList.length; i++) {
            if (wsList[i].id === wsId)
                return wsList[i];
        }
        return null;
    }

    function toplevelIconName(toplevel) {
        if (!toplevel)
            return "";

        var ipc = toplevel.lastIpcObject || {};
        var iconName = String(ipc.initialClass || ipc.class || "");

        if (iconName === "" && toplevel.wayland)
            iconName = String(toplevel.wayland.appId || "");

        return desktopIconForName(iconName);
    }

    function desktopIconForName(name) {
        var raw = String(name || "").replace(/\.desktop$/i, "");
        if (raw === "")
            return "";

        var lower = raw.toLowerCase();
        var candidates = [raw, lower, raw + ".desktop", lower + ".desktop"];
        for (var i = 0; i < candidates.length; i++) {
            var exactEntry = DesktopEntries.byId(candidates[i]);
            if (exactEntry && exactEntry.icon)
                return String(exactEntry.icon);
        }

        var apps = DesktopEntries.applications.values;
        for (var j = 0; j < apps.length; j++) {
            var entry = apps[j];
            var entryId = String(entry.id || "").replace(/\.desktop$/i, "").toLowerCase();
            var startupClass = String(entry.startupClass || "").toLowerCase();
            var entryName = String(entry.name || "").toLowerCase();

            if ((entryId === lower || startupClass === lower || entryName === lower) && entry.icon)
                return String(entry.icon);
        }

        var heuristicEntry = DesktopEntries.heuristicLookup(raw);
        if (heuristicEntry && heuristicEntry.icon)
            return String(heuristicEntry.icon);

        return raw;
    }

    function workspaceAppIcons(wsId) {
        var workspace = workspaceForId(wsId);
        if (!workspace)
            return [];

        var icons = [];
        var windows = workspace.toplevels.values;
        for (var i = 0; i < windows.length; i++) {
            var iconName = toplevelIconName(windows[i]);
            if (iconName !== "")
                icons.push(iconName);
        }

        return icons;
    }

    function visibleAppIcons(icons) {
        if (icons.length <= 8)
            return icons;

        var visibleIcons = icons.slice(0, 7);
        visibleIcons.push("+" + (icons.length - 7));
        return visibleIcons;
    }

    function setDrawerOpen(open, kind, item, detail) {
        if (!compactAnimatedSidebar || !drawerAllowed)
            return;
        if (open) {
            drawerCloseTimer.stop();
            var nextKind = kind || "summary";
            var kindChanged = drawerKind !== nextKind;
            drawerKind = nextKind;
            if (drawerKind === "workspaces" && detail !== undefined)
                drawerWorkspaceId = Number(detail);
            var workspaceAnchorChanged = drawerKind === "workspaces" && drawerWorkspaceAnchorId !== drawerWorkspaceId;
            if (workspaceAnchorChanged)
                drawerWorkspaceAnchorId = drawerWorkspaceId;
            if (item !== undefined && item !== null && (kindChanged || drawerKind !== "workspaces" || workspaceAnchorChanged)) {
                var point = root.mapFromItem(item, item.width / 2, item.height / 2);
                drawerAnchorY = Math.max(shell.s(88), Math.min(root.height - shell.s(88), point.y));
            }
            shell.sidebarDrawerOpen = true;
            return;
        }
        drawerCloseTimer.restart();
    }

    function drawerTitle() {
        if (drawerKind === "calendar") return root.compactDateText;
        if (drawerKind === "launcher") return "Launcher";
        if (drawerKind === "notifications") return "Notifications";
        if (drawerKind === "workspaces") return "Workspaces";
        if (drawerKind === "media") return "Media";
        if (drawerKind === "tray") return "Tray";
        if (drawerKind === "keyboard") return "Keyboard";
        if (drawerKind === "updates") return "Updates";
        if (drawerKind === "network") return "Network";
        if (drawerKind === "bluetooth") return "Bluetooth";
        if (drawerKind === "volume") return "Volume";
        if (drawerKind === "battery") return "Battery";
        return ThemeConfig.name;
    }

    function drawerPrimary() {
        if (drawerKind === "calendar") return root.compactTimeText + (root.compactWeatherText !== "" ? "  " + root.compactWeatherText : "");
        if (drawerKind === "launcher") return "Open Walker";
        if (drawerKind === "notifications") return "Left: panel  Right: clear";
        if (drawerKind === "workspaces") return workspaceSummary(drawerWorkspaceId);
        if (drawerKind === "media") return shell.musicData.title || "No active track";
        if (drawerKind === "tray") return visibleTrayCount() + " visible tray item" + (visibleTrayCount() === 1 ? "" : "s");
        if (drawerKind === "keyboard") return shell.kbLayout;
        if (drawerKind === "updates") return (parseInt(shell.updateCount) || 0) + " package updates";
        if (drawerKind === "network") return shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "Wi-Fi on") : "Wi-Fi off";
        if (drawerKind === "bluetooth") return shell.isBtOn ? shell.btDevice : "Bluetooth off";
        if (drawerKind === "volume") return shell.isSoundActive ? shell.volPercent : "Muted";
        if (drawerKind === "battery") return shell.batPercent + (shell.isCharging ? " charging" : "");
        return shell.activeMode;
    }

    function drawerSecondary() {
        if (drawerKind === "calendar") return shell.weatherIcon + " " + String(shell.weatherTemp || "--");
        if (drawerKind === "launcher") return "Click to search apps and commands";
        if (drawerKind === "notifications") return shell.moduleList.includes("notifications") ? "Notification center is enabled" : "Hidden in this mode";
        if (drawerKind === "workspaces") return workspaceWindowSummary(drawerWorkspaceId);
        if (drawerKind === "media") return shell.musicData.artist || shell.musicData.status || "Click controls playback";
        if (drawerKind === "tray") return "Right-click an icon for its menu";
        if (drawerKind === "keyboard") return shell.kbLayoutCount + " layouts available";
        if (drawerKind === "updates") return "Click to open update terminal";
        if (drawerKind === "network") return shell.isWifiOn ? "Click for Wi-Fi controls" : "Click to open network controls";
        if (drawerKind === "bluetooth") return shell.isBtOn ? "Click for device controls" : "Click to open Bluetooth controls";
        if (drawerKind === "volume") return "Scroll to adjust volume";
        if (drawerKind === "battery") return shell.batIcon;
        return "Mode-aware compact sidebar";
    }

    function workspaceSummary(wsId) {
        var ws = workspaceForId(wsId);
        if (!ws)
            return "Workspace " + wsId;
        return "Workspace " + ws.id;
    }

    function workspaceWindowSummary(wsId) {
        var ws = workspaceForId(wsId);
        if (!ws)
            return "Empty";
        var count = ws.toplevels.values.length;
        return count + " window" + (count === 1 ? "" : "s") + " open";
    }

    function visibleTrayCount() {
        return trayRepeater ? trayRepeater.count : 0;
    }

    Timer {
        id: drawerCloseTimer
        interval: 260
        repeat: false
        onTriggered: shell.sidebarDrawerOpen = false
    }

    Component.onDestruction: {
        if (compactAnimatedSidebar)
            shell.sidebarDrawerOpen = false;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    ColumnLayout {
        width: root.railWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: shell.isLeftBar ? parent.left : undefined
        anchors.right: shell.isRightBar ? parent.right : undefined
        anchors.topMargin: shell.isTopBar ? root.screenEdgeMargin : root.outerMargin
        anchors.bottomMargin: shell.isBottomBar ? root.screenEdgeMargin : root.outerMargin
        anchors.leftMargin: shell.isLeftBar ? root.screenEdgeMargin : root.outerMargin
        anchors.rightMargin: shell.isRightBar ? root.screenEdgeMargin : root.outerMargin
        spacing: root.sectionSpacing

        Rectangle {
            id: infoCard
            Layout.fillWidth: true
            Layout.preferredHeight: shell.s(root.compactRailOnly ? 76 : 88)
            radius: surface.panelRadius
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
            border.width: root.panelBorderWidth
            border.color: surface.panelBorderColor
            color: surface.panelColor

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.setDrawerOpen(true, "calendar", infoCard)
                onExited: root.setDrawerOpen(false)
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: shell.s(root.compactRailOnly ? 6 : 8)
                spacing: shell.s(root.compactRailOnly ? 2 : 3)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: shell.s(root.compactRailOnly ? 0 : 3)

                    Text {
                        text: root.compactTimeText
                        Layout.fillWidth: true
                        font.family: shell.displayFontFamily
                        font.pixelSize: shell.s(root.compactRailOnly ? 12 : 15)
                        minimumPixelSize: shell.s(9)
                        fontSizeMode: Text.Fit
                        font.weight: Font.Black
                        font.letterSpacing: 0
                        color: mocha.yellow
                        horizontalAlignment: root.compactRailOnly ? Text.AlignHCenter : Text.AlignRight
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.compactSecondsText !== ""
                        text: root.compactSecondsText
                        Layout.preferredWidth: shell.s(root.compactRailOnly ? 11 : 15)
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(root.compactRailOnly ? 7 : 9)
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
                    font.pixelSize: shell.s(root.compactRailOnly ? 8 : 10)
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
                        font.pixelSize: shell.s(root.compactRailOnly ? 13 : 15)
                        color: Qt.tint(shell.weatherHex, Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.4))
                    }
                    Text {
                        text: root.compactWeatherText
                        Layout.fillWidth: true
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(root.compactRailOnly ? 8 : 10)
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
                topLeftRadius: root.pillTopLeftRadius
                topRightRadius: root.pillTopRightRadius
                bottomLeftRadius: root.pillBottomLeftRadius
                bottomRightRadius: root.pillBottomRightRadius
                color: searchMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
                border.width: root.edgeSidebarChrome ? 0 : 1
                border.color: searchMouse.containsMouse ? surface.panelBorderHoverColor : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "󰍉"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(root.compactRailOnly ? 15 : 18)
                    color: searchMouse.containsMouse ? mocha.blue : mocha.text
                }
                MouseArea {
                    id: searchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.setDrawerOpen(true, "launcher", parent)
                    onExited: root.setDrawerOpen(false)
                    onClicked: Quickshell.execDetached(["bash", "-c", "walker"])
                }
            }

            Rectangle {
                visible: shell.moduleList.includes("notifications")
                Layout.fillWidth: true
                Layout.preferredHeight: root.iconButtonSize
                radius: surface.innerPillRadius
                topLeftRadius: root.pillTopLeftRadius
                topRightRadius: root.pillTopRightRadius
                bottomLeftRadius: root.pillBottomLeftRadius
                bottomRightRadius: root.pillBottomRightRadius
                color: notifMouse.containsMouse ? surface.innerPillHoverColor : surface.innerPillColor
                border.width: root.edgeSidebarChrome ? 0 : 1
                border.color: notifMouse.containsMouse ? surface.panelBorderHoverColor : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(root.compactRailOnly ? 14 : 16)
                    color: notifMouse.containsMouse ? mocha.yellow : mocha.text
                }
                MouseArea {
                    id: notifMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.setDrawerOpen(true, "notifications", parent)
                    onExited: root.setDrawerOpen(false)
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
            border.width: root.panelBorderWidth
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
                        readonly property bool previewApps: ThemeConfig.workspacePreview === "app-icons"
                                                           || ThemeConfig.workspacePreview === "hybrid"
                        readonly property var appIcons: hovered && previewApps ? root.workspaceAppIcons(wsId) : []
                        readonly property var visibleAppIcons: root.visibleAppIcons(appIcons)
                        readonly property bool showAppIcons: appIcons.length > 0
                        readonly property bool useIconGrid: visibleAppIcons.length >= 3
                        readonly property int iconSize: shell.s(useIconGrid ? 10 : (root.compactRailOnly ? 13 : 15))
                        readonly property int iconColumns: useIconGrid ? Math.ceil(visibleAppIcons.length / 2) : visibleAppIcons.length

                        property string stateLabel: {
                            if (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId)
                                return "active";
                            var workspace = root.workspaceForId(wsId);
                            if (workspace)
                                return workspace.toplevels.values.length > 0 ? "occupied" : "empty";
                            return "empty";
                        }

                        width: wsColumn.width
                        height: shell.s(30)
                        radius: surface.innerPillRadius
                        topLeftRadius: root.pillTopLeftRadius
                        topRightRadius: root.pillTopRightRadius
                        bottomLeftRadius: root.pillBottomLeftRadius
                        bottomRightRadius: root.pillBottomRightRadius
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
                            opacity: showAppIcons ? 0 : 1
                            text: wsId.toString()
                            font.family: shell.monoFontFamily
                            font.pixelSize: shell.s(13)
                            font.weight: stateLabel === "active" ? Font.Black : Font.Bold
                            font.letterSpacing: shell.themeLetterSpacing
                            color: stateLabel === "active" ? mocha.crust : mocha.text
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        Grid {
                            anchors.centerIn: parent
                            columns: Math.max(1, iconColumns)
                            rowSpacing: shell.s(2)
                            columnSpacing: shell.s(useIconGrid ? 3 : 4)
                            opacity: showAppIcons ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 140 } }

                            Repeater {
                                model: visibleAppIcons

                                delegate: Item {
                                    id: appIconSlot
                                    required property string modelData
                                    width: iconSize
                                    height: iconSize
                                    readonly property bool overflowLabel: modelData.charAt(0) === "+"

                                    Image {
                                        anchors.fill: parent
                                        visible: !appIconSlot.overflowLabel
                                        sourceSize.width: width
                                        sourceSize.height: height
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        source: appIconSlot.modelData.startsWith("/") ? "file://" + appIconSlot.modelData : "image://icon/" + appIconSlot.modelData
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: appIconSlot.overflowLabel
                                        text: appIconSlot.modelData
                                        font.family: shell.monoFontFamily
                                        font.pixelSize: shell.s(9)
                                        font.weight: Font.Bold
                                        color: stateLabel === "active" ? mocha.crust : mocha.text
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                root.pointerInWorkspaces = true;
                                root.setDrawerOpen(true, "workspaces", parent, wsId);
                            }
                            onExited: {
                                root.pointerInWorkspaces = false;
                                root.setDrawerOpen(false);
                            }
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsId])
                            onWheel: (wheel) => {
                                shell.handleWorkspaceWheel(wheel.angleDelta.y, 8);
                                wheel.accepted = true;
                            }
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
            border.width: root.panelBorderWidth
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
                            hoverEnabled: true
                            onEntered: root.setDrawerOpen(true, "media", parent)
                            onExited: root.setDrawerOpen(false)
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
                            hoverEnabled: true
                            onEntered: root.setDrawerOpen(true, "media", parent)
                            onExited: root.setDrawerOpen(false)
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
                            hoverEnabled: true
                            onEntered: root.setDrawerOpen(true, "media", parent)
                            onExited: root.setDrawerOpen(false)
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
            border.width: root.panelBorderWidth
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
                        topLeftRadius: root.pillTopLeftRadius
                        topRightRadius: root.pillTopRightRadius
                        bottomLeftRadius: root.pillBottomLeftRadius
                        bottomRightRadius: root.pillBottomRightRadius
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
                            onEntered: root.setDrawerOpen(true, "tray", parent)
                            onExited: root.setDrawerOpen(false)
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
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
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
                onEntered: root.setDrawerOpen(true, "keyboard", parent)
                onExited: root.setDrawerOpen(false)
                cursorShape: Qt.PointingHandCursor
                onClicked: shell.switchKeyboardLayout()
            }
        }

        Rectangle {
            id: statusDock
            visible: root.statusDockVisible
            Layout.fillWidth: true
            Layout.preferredHeight: statusDockColumn.implicitHeight + shell.s(10)
            radius: surface.panelRadius
            topLeftRadius: root.panelTopLeftRadius
            topRightRadius: root.panelTopRightRadius
            bottomLeftRadius: root.panelBottomLeftRadius
            bottomRightRadius: root.panelBottomRightRadius
            color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, root.edgeSidebarChrome ? 0.24 : 0.14)
            border.width: root.edgeSidebarChrome ? 0 : 1
            border.color: surface.panelBorderColor
            clip: true

            ColumnLayout {
                id: statusDockColumn
                anchors.fill: parent
                anchors.topMargin: shell.s(5)
                anchors.bottomMargin: shell.s(5)
                anchors.leftMargin: shell.isLeftBar && root.edgeSidebarChrome ? 0 : shell.s(5)
                anchors.rightMargin: shell.isRightBar && root.edgeSidebarChrome ? 0 : shell.s(5)
                spacing: shell.s(5)

        Rectangle {
            visible: shell.moduleList.includes("updates")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: updatesMouse.containsMouse ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.62)
            border.width: root.edgeSidebarChrome ? 0 : 1
            border.color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.4)
            RowLayout {
                visible: !root.compactRailOnly
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
                visible: root.compactRailOnly
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
                onEntered: root.setDrawerOpen(true, "updates", parent)
                onExited: root.setDrawerOpen(false)
                onClicked: shell.openUpdatesTerminal()
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("network")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: wifiMouse.containsMouse ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                anchors.fill: parent
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.wifiIcon
                    Layout.fillWidth: root.compactRailOnly
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isWifiOn ? mocha.blue : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: !root.compactRailOnly
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
                onEntered: root.setDrawerOpen(true, "network", parent)
                onExited: root.setDrawerOpen(false)
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"])
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("bluetooth")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: btMouse.containsMouse ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                anchors.fill: parent
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.btIcon
                    Layout.fillWidth: root.compactRailOnly
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isBtOn ? mocha.mauve : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: !root.compactRailOnly
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
                onEntered: root.setDrawerOpen(true, "bluetooth", parent)
                onExited: root.setDrawerOpen(false)
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"])
            }
        }

        Rectangle {
            visible: shell.moduleList.includes("volume")
            Layout.fillWidth: true
            Layout.preferredHeight: root.moduleHeight
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: volMouse.containsMouse ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                visible: !root.compactRailOnly
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
                visible: root.compactRailOnly
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
                onEntered: root.setDrawerOpen(true, "volume", parent)
                onExited: root.setDrawerOpen(false)
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
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: batMouse.containsMouse ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                visible: !root.compactRailOnly
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
                visible: root.compactRailOnly
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
                onEntered: root.setDrawerOpen(true, "battery", parent)
                onExited: root.setDrawerOpen(false)
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"])
            }
        }
            }
        }
    }

    Rectangle {
        id: contextDrawer
        visible: root.compactAnimatedSidebar && root.drawerAllowed
        width: shell.sidebarDrawerWidth
        height: drawerContent.implicitHeight + shell.s(18)
        radius: surface.panelRadius
        border.width: 1
        border.color: ThemeConfig.drawerStyle === "rail-panel"
                      ? Qt.rgba(mocha.blue.r, mocha.blue.g, mocha.blue.b, drawerOpen ? 0.46 : 0.0)
                      : Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, drawerOpen ? 0.52 : 0.0)
        color: ThemeConfig.drawerStyle === "rail-panel"
               ? Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.94)
               : Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.90)
        opacity: drawerOpen ? 1.0 : 0.0
        scale: drawerOpen ? 1.0 : 0.985
        x: shell.isLeftBar ? root.railWidth + shell.s(8) : root.width - root.railWidth - width - shell.s(8)
        y: Math.max(shell.s(8), Math.min(root.height - height - shell.s(8), root.drawerAnchorY - height / 2))
        z: 20
        clip: true

        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(180); easing.type: Easing.InOutSine } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(180); easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: ThemeConfig.duration(120); easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            enabled: root.drawerOpen
            hoverEnabled: true
            onEntered: root.setDrawerOpen(true, root.drawerKind, contextDrawer)
            onExited: root.setDrawerOpen(false)
        }

        ColumnLayout {
            id: drawerContent
            anchors.fill: parent
            anchors.margins: shell.s(9)
            spacing: shell.s(5)

            Text {
                text: root.drawerTitle()
                Layout.fillWidth: true
                font.family: shell.uiFontFamily
                font.pixelSize: shell.s(11)
                font.weight: Font.DemiBold
                font.letterSpacing: 0
                color: mocha.subtext0
                elide: Text.ElideRight
            }

            Text {
                text: root.drawerPrimary()
                Layout.fillWidth: true
                font.family: shell.displayFontFamily
                font.pixelSize: shell.s(15)
                minimumPixelSize: shell.s(10)
                fontSizeMode: Text.Fit
                font.weight: Font.Black
                font.letterSpacing: 0
                color: mocha.text
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.32)
            }

            Text {
                text: root.drawerSecondary()
                Layout.fillWidth: true
                font.family: shell.monoFontFamily
                font.pixelSize: shell.s(10)
                font.weight: shell.themeFontWeight
                font.letterSpacing: 0
                color: mocha.overlay2
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
