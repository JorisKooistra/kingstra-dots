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
                                                  || ThemeConfig.effectiveBarTemplate === "compact-sidebar"
    readonly property bool expandAllowed: ThemeConfig.drawerStyle !== "none"
    readonly property bool compactRailOnly: compactAnimatedSidebar
    readonly property int railWidth: compactAnimatedSidebar && shell.isVerticalBar ? shell.baseBarThickness : width
    readonly property int hoverExpandedWidth: root.railWidth + shell.sidebarDrawerWidth - shell.s(8)
    property int hoverDepth: 0
    readonly property int outerMargin: compactAnimatedSidebar ? shell.s(4) : (shell.edgeAttachedBar ? shell.s(8) : shell.s(10))
    readonly property bool flattenScreenEdgeCorners: shell.edgeAttachedBar
                                                     && String(shell.activeThemeName || "").toLowerCase() === "organic"
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

    function railHoverEnter() {
        if (!compactAnimatedSidebar || !expandAllowed)
            return;
        hoverCloseTimer.stop();
        root.hoverDepth++;
        shell.sidebarDrawerOpen = true;
    }

    function railHoverExit() {
        if (!compactAnimatedSidebar || !expandAllowed)
            return;
        root.hoverDepth = Math.max(0, root.hoverDepth - 1);
        hoverCloseTimer.restart();
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
        id: hoverCloseTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (root.hoverDepth === 0)
                shell.sidebarDrawerOpen = false;
        }
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
                onClicked: shell.toggleWeatherPopup()
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

            Item {
                id: searchSlot
                Layout.fillWidth: false
                Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
                Layout.preferredWidth: root.railWidth
                Layout.preferredHeight: root.iconButtonSize

                Rectangle {
                    id: searchPill
                    property bool hovered: searchMouse.containsMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: hovered ? root.hoverExpandedWidth : root.railWidth
                    Behavior on width { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                    clip: true
                    radius: surface.innerPillRadius
                    topLeftRadius: root.pillTopLeftRadius
                    topRightRadius: root.pillTopRightRadius
                    bottomLeftRadius: root.pillBottomLeftRadius
                    bottomRightRadius: root.pillBottomRightRadius
                    color: hovered ? surface.innerPillHoverColor : surface.innerPillColor
                    border.width: root.edgeSidebarChrome ? 0 : 1
                    border.color: hovered ? surface.panelBorderHoverColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: shell.s(8)
                        spacing: shell.s(8)
                        Text {
                            text: "󰍉"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: shell.s(15)
                            color: searchPill.hovered ? mocha.blue : mocha.text
                        }
                        Text {
                            text: "Search"
                            visible: searchPill.hovered
                            opacity: searchPill.hovered ? 1 : 0
                            Layout.fillWidth: true
                            font.family: shell.monoFontFamily
                            font.pixelSize: shell.s(11)
                            font.weight: shell.themeFontWeight
                            color: mocha.text
                            elide: Text.ElideRight
                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                        }
                    }
                    MouseArea {
                        id: searchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.railHoverEnter()
                        onExited: root.railHoverExit()
                        onClicked: Quickshell.execDetached(["bash", "-c", "walker"])
                    }
                }
            }

            Item {
                id: notifSlot
                visible: shell.moduleList.includes("notifications")
                Layout.fillWidth: false
                Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
                Layout.preferredWidth: root.railWidth
                Layout.preferredHeight: root.iconButtonSize

                Rectangle {
                    id: notifPill
                    property bool hovered: notifMouse.containsMouse
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: hovered ? root.hoverExpandedWidth : root.railWidth
                    Behavior on width { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                    clip: true
                    radius: surface.innerPillRadius
                    topLeftRadius: root.pillTopLeftRadius
                    topRightRadius: root.pillTopRightRadius
                    bottomLeftRadius: root.pillBottomLeftRadius
                    bottomRightRadius: root.pillBottomRightRadius
                    color: hovered ? surface.innerPillHoverColor : surface.innerPillColor
                    border.width: root.edgeSidebarChrome ? 0 : 1
                    border.color: hovered ? surface.panelBorderHoverColor : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: shell.s(8)
                        spacing: shell.s(8)
                        Text {
                            text: "\uf0f3"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: shell.s(14)
                            color: notifPill.hovered ? mocha.yellow : mocha.text
                        }
                        Text {
                            text: "Notifications"
                            visible: notifPill.hovered
                            opacity: notifPill.hovered ? 1 : 0
                            Layout.fillWidth: true
                            font.family: shell.monoFontFamily
                            font.pixelSize: shell.s(11)
                            font.weight: shell.themeFontWeight
                            color: mocha.text
                            elide: Text.ElideRight
                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                        }
                    }
                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.railHoverEnter()
                        onExited: root.railHoverExit()
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.LeftButton) Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
                            if (mouse.button === Qt.RightButton) Quickshell.execDetached(["swaync-client", "-d"]);
                        }
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

            Column {
                id: wsColumn
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(5)

                Repeater {
                    model: 8
                    delegate: Rectangle {
                        id: wsPill
                        required property int index
                        property int wsId: index + 1
                        property bool hovered: wsMouse.containsMouse
                        readonly property bool previewApps: ThemeConfig.workspacePreview === "app-icons"
                                                           || ThemeConfig.workspacePreview === "hybrid"
                        readonly property var appIcons: hovered && previewApps ? root.workspaceAppIcons(wsId) : []
                        readonly property var visibleAppIcons: root.visibleAppIcons(appIcons)
                        readonly property bool showAppIcons: appIcons.length > 0
                        readonly property bool useIconGrid: visibleAppIcons.length >= 3
                        readonly property int iconSize: shell.s(useIconGrid ? 10 : 13)
                        readonly property int iconColumns: useIconGrid ? Math.ceil(visibleAppIcons.length / 2) : visibleAppIcons.length
                        property real targetWidth: hovered ? root.hoverExpandedWidth : wsColumn.width

                        property string stateLabel: {
                            if (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId)
                                return "active";
                            var workspace = root.workspaceForId(wsId);
                            if (workspace)
                                return workspace.toplevels.values.length > 0 ? "occupied" : "empty";
                            return "empty";
                        }

                        width: targetWidth
                        height: shell.s(30)
                        clip: true
                        Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
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

                        Item {
                            id: indicatorZone
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: wsColumn.width

                            Text {
                                anchors.centerIn: parent
                                opacity: wsPill.showAppIcons ? 0 : 1
                                text: wsPill.wsId.toString()
                                font.family: shell.monoFontFamily
                                font.pixelSize: shell.s(13)
                                font.weight: wsPill.stateLabel === "active" ? Font.Black : Font.Bold
                                font.letterSpacing: shell.themeLetterSpacing
                                color: wsPill.stateLabel === "active" ? mocha.crust : mocha.text
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Grid {
                                anchors.centerIn: parent
                                columns: Math.max(1, wsPill.iconColumns)
                                rowSpacing: shell.s(2)
                                columnSpacing: shell.s(wsPill.useIconGrid ? 3 : 4)
                                opacity: wsPill.showAppIcons ? 1 : 0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }

                                Repeater {
                                    model: wsPill.visibleAppIcons

                                    delegate: Item {
                                        id: appIconSlot
                                        required property string modelData
                                        width: wsPill.iconSize
                                        height: wsPill.iconSize
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
                                            color: wsPill.stateLabel === "active" ? mocha.crust : mocha.text
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.left: indicatorZone.right
                            anchors.right: parent.right
                            anchors.leftMargin: shell.s(4)
                            anchors.rightMargin: shell.s(10)
                            anchors.verticalCenter: parent.verticalCenter
                            visible: wsPill.hovered
                            opacity: wsPill.hovered ? 1 : 0
                            text: root.workspaceWindowSummary(wsPill.wsId)
                            font.family: shell.monoFontFamily
                            font.pixelSize: shell.s(10)
                            font.weight: shell.themeFontWeight
                            color: wsPill.stateLabel === "active" ? mocha.crust : mocha.subtext0
                            elide: Text.ElideRight
                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.railHoverEnter()
                            onExited: root.railHoverExit()
                            onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsPill.wsId])
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
            visible: (shell.mediaStatus === "Playing" || shell.mediaStatus === "Paused")
                && String(shell.mediaTitle || "").trim() !== ""
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

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: shell.toggleMusicPopup()
                    }
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
                        id: trayItemPill
                        required property var modelData
                        property bool hiddenTrayItem: trayPanel.isHiddenTrayItem(modelData)
                        property bool hovered: trayMouse.containsMouse
                        property string itemLabel: {
                            var title = trayPanel.trayField(modelData, "title");
                            return title !== "" ? title : trayPanel.trayField(modelData, "tooltipTitle");
                        }
                        visible: !hiddenTrayItem
                        width: hovered ? root.hoverExpandedWidth : trayColumn.width
                        height: visible ? shell.s(28) : 0
                        clip: true
                        Behavior on width { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                        radius: surface.innerPillRadius
                        topLeftRadius: root.pillTopLeftRadius
                        topRightRadius: root.pillTopRightRadius
                        bottomLeftRadius: root.pillBottomLeftRadius
                        bottomRightRadius: root.pillBottomRightRadius
                        color: hovered ? surface.innerPillHoverColor : surface.innerPillColor
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: shell.s(6)
                            spacing: shell.s(8)
                            Image {
                                Layout.preferredWidth: shell.s(16)
                                Layout.preferredHeight: shell.s(16)
                                source: trayItemPill.modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                sourceSize: Qt.size(shell.s(16), shell.s(16))
                            }
                            Text {
                                text: trayItemPill.itemLabel
                                visible: trayItemPill.hovered && text !== ""
                                opacity: trayItemPill.hovered ? 1 : 0
                                Layout.fillWidth: true
                                font.family: shell.monoFontFamily
                                font.pixelSize: shell.s(10)
                                font.weight: shell.themeFontWeight
                                color: mocha.text
                                elide: Text.ElideRight
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                            }
                        }
                        QsMenuAnchor {
                            id: menuAnchor
                            anchor.window: shell
                            anchor.item: parent
                            menu: trayItemPill.modelData.menu
                        }
                        MouseArea {
                            id: trayMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.railHoverEnter()
                            onExited: root.railHoverExit()
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) {
                                    trayItemPill.modelData.activate();
                                } else if (mouse.button === Qt.MiddleButton) {
                                    trayItemPill.modelData.secondaryActivate();
                                } else if (mouse.button === Qt.RightButton) {
                                    if (trayItemPill.modelData.menu) {
                                        menuAnchor.open();
                                    } else if (typeof trayItemPill.modelData.contextMenu === "function") {
                                        trayItemPill.modelData.contextMenu(mouse.x, mouse.y);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: kbSlot
            visible: shell.kbLayoutCount > 1
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: root.iconButtonSize
            Layout.preferredHeight: root.moduleHeight

            Rectangle {
                id: kbPill
                property bool hovered: kbMouse.containsMouse
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: hovered ? root.hoverExpandedWidth : root.iconButtonSize
                Behavior on width { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                clip: true
                radius: surface.innerPillRadius
                topLeftRadius: root.pillTopLeftRadius
                topRightRadius: root.pillTopRightRadius
                bottomLeftRadius: root.pillBottomLeftRadius
                bottomRightRadius: root.pillBottomRightRadius
                color: hovered ? surface.innerPillHoverColor : surface.innerPillColor
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: shell.s(8)
                    spacing: shell.s(8)
                    Text {
                        text: shell.kbLayout
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(12)
                        font.weight: Font.Black
                        font.letterSpacing: shell.themeLetterSpacing
                        color: kbPill.hovered ? mocha.text : mocha.overlay2
                    }
                    Text {
                        text: shell.kbLayoutCount + " layouts"
                        visible: kbPill.hovered
                        opacity: kbPill.hovered ? 1 : 0
                        Layout.fillWidth: true
                        font.family: shell.monoFontFamily
                        font.pixelSize: shell.s(10)
                        font.weight: shell.themeFontWeight
                        color: mocha.overlay2
                        elide: Text.ElideRight
                        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                    }
                }
                MouseArea {
                    id: kbMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.railHoverEnter()
                    onExited: root.railHoverExit()
                    cursorShape: Qt.PointingHandCursor
                    onClicked: shell.switchKeyboardLayout()
                }
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

            ColumnLayout {
                id: statusDockColumn
                anchors.fill: parent
                anchors.topMargin: shell.s(5)
                anchors.bottomMargin: shell.s(5)
                anchors.leftMargin: shell.isLeftBar && root.edgeSidebarChrome ? 0 : shell.s(5)
                anchors.rightMargin: shell.isRightBar && root.edgeSidebarChrome ? 0 : shell.s(5)
                spacing: shell.s(5)

        Rectangle {
            id: updatesPill
            visible: shell.moduleList.includes("updates")
            property bool hovered: updatesMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.62)
            border.width: root.edgeSidebarChrome ? 0 : 1
            border.color: Qt.rgba(mocha.yellow.r, mocha.yellow.g, mocha.yellow.b, 0.4)
            RowLayout {
                visible: updatesPill.hovered
                opacity: updatesPill.hovered ? 1 : 0
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                Text {
                    text: "\uf701"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.updateCount > 0 ? mocha.yellow : mocha.subtext0
                }
                Text {
                    text: (parseInt(shell.updateCount) || 0) + " updates"
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(12)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.updateCount > 0 ? mocha.text : mocha.subtext0
                    elide: Text.ElideRight
                }
            }
            Row {
                visible: !updatesPill.hovered
                opacity: updatesPill.hovered ? 0 : 1
                anchors.centerIn: parent
                spacing: shell.s(4)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(120) } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf701"
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
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: shell.openUpdatesTerminal()
            }
        }

        Rectangle {
            id: networkPill
            visible: shell.moduleList.includes("network")
            property bool hovered: wifiMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                anchors.fill: parent
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.wifiIcon
                    Layout.fillWidth: !networkPill.hovered
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isWifiOn ? mocha.blue : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: networkPill.hovered
                    opacity: networkPill.hovered ? 1 : 0
                    text: shell.isWifiOn ? (shell.wifiSsid !== "" ? shell.wifiSsid : "On") : "Off"
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.isWifiOn ? mocha.text : mocha.subtext0
                    elide: Text.ElideRight
                    Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                }
            }
            MouseArea {
                id: wifiMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"])
            }
        }

        Rectangle {
            id: bluetoothPill
            visible: shell.moduleList.includes("bluetooth")
            property bool hovered: btMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                anchors.fill: parent
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: shell.btIcon
                    Layout.fillWidth: !bluetoothPill.hovered
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: shell.isBtOn ? mocha.mauve : mocha.subtext0
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: bluetoothPill.hovered
                    opacity: bluetoothPill.hovered ? 1 : 0
                    text: shell.btDevice
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: shell.isBtOn ? mocha.text : mocha.subtext0
                    elide: Text.ElideRight
                    Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                }
            }
            MouseArea {
                id: btMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"])
            }
        }

        Rectangle {
            id: volumePill
            visible: shell.moduleList.includes("volume")
            property bool hovered: volMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                visible: volumePill.hovered
                opacity: volumePill.hovered ? 1 : 0
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
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
                visible: !volumePill.hovered
                opacity: volumePill.hovered ? 0 : 1
                anchors.centerIn: parent
                spacing: shell.s(4)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(120) } }
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
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: shell.toggleAudioControlsPopup()
                onWheel: (wheel) => {
                    shell.handleVolumeWheel(wheel.angleDelta.y);
                    wheel.accepted = true;
                }
            }
        }

        Rectangle {
            id: batteryPill
            visible: shell.moduleList.includes("battery")
            property bool hovered: batMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            RowLayout {
                visible: batteryPill.hovered
                opacity: batteryPill.hovered ? 1 : 0
                anchors.fill: parent
                anchors.margins: shell.s(8)
                spacing: shell.s(8)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
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
                visible: !batteryPill.hovered
                opacity: batteryPill.hovered ? 0 : 1
                anchors.centerIn: parent
                spacing: shell.s(4)
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(120) } }
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
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"])
            }
        }

        Rectangle {
            id: powerPill
            property bool hovered: powerMouse.containsMouse
            property real targetWidth: hovered ? root.hoverExpandedWidth : root.railWidth
            Layout.fillWidth: false
            Layout.alignment: shell.isRightBar ? Qt.AlignRight : Qt.AlignLeft
            Layout.preferredWidth: targetWidth
            Layout.preferredHeight: root.moduleHeight
            Behavior on targetWidth { NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
            clip: true
            radius: surface.innerPillRadius
            topLeftRadius: root.pillTopLeftRadius
            topRightRadius: root.pillTopRightRadius
            bottomLeftRadius: root.pillBottomLeftRadius
            bottomRightRadius: root.pillBottomRightRadius
            color: hovered ? surface.innerPillHoverColor : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58)
            border.width: hovered ? 1 : 0
            border.color: hovered ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.36) : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.margins: root.moduleInnerMargin
                spacing: root.moduleSpacing
                Text {
                    text: "󰐥"
                    Layout.fillWidth: !powerPill.hovered
                    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: shell.s(15)
                    color: mocha.red
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    visible: powerPill.hovered
                    opacity: powerPill.hovered ? 1 : 0
                    text: "Afsluitmenu"
                    Layout.fillWidth: true
                    font.family: shell.monoFontFamily
                    font.pixelSize: shell.s(11)
                    font.weight: shell.themeFontWeight
                    font.letterSpacing: shell.themeLetterSpacing
                    color: mocha.text
                    elide: Text.ElideRight
                    Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(160) } }
                }
            }

            MouseArea {
                id: powerMouse
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.railHoverEnter()
                onExited: root.railHoverExit()
                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle power"])
            }
        }
            }
        }
    }
}
