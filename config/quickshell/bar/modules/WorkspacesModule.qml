import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// Left-bar pill: clickable workspace indicator dots.
// Uses Quickshell.Hyprland for event-driven workspace state (no polling).
Rectangle {
    id: root
    required property var shell
    required property var surface
    required property var mocha
    required property var ctx           // BarContent root — supplies theme chrome colors/flags

    readonly property int wsCount: 10

    Layout.preferredHeight: ctx.cyberSideModuleHeight
    Layout.alignment: Qt.AlignVCenter
    property real targetWidth: wsLayout.implicitWidth + shell.s(20)
    Layout.preferredWidth: targetWidth
    width: targetWidth
    visible: shell.moduleList && shell.moduleList.includes("workspaces")
    opacity: visible ? 1 : 0
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

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            shell.handleWorkspaceWheel(wheel.angleDelta.y, root.wsCount);
            wheel.accepted = true;
        }
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
            model: root.wsCount
            delegate: Rectangle {
                id: wsPill
                required property int index
                property int wsId: index + 1
                property bool isHovered: wsPillMouse.containsMouse
                readonly property var appIcons: isHovered ? root.workspaceAppIcons(wsId) : []
                readonly property var visibleAppIcons: root.visibleAppIcons(appIcons)
                readonly property bool showAppIcons: appIcons.length > 0
                readonly property bool useIconGrid: visibleAppIcons.length >= 3
                readonly property int iconSize: shell.s(useIconGrid ? 10 : 16)
                readonly property int iconColumns: useIconGrid ? Math.ceil(visibleAppIcons.length / 2) : visibleAppIcons.length

                property string stateLabel: {
                    if (Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId)
                        return "active";
                    var workspace = root.workspaceForId(wsId);
                    if (workspace)
                        return workspace.toplevels.values.length > 0 ? "occupied" : "empty";
                    return "empty";
                }

                property real targetWidth: showAppIcons && iconColumns > 0
                                           ? Math.max(shell.s(32), (iconColumns * iconSize) + ((iconColumns - 1) * shell.s(useIconGrid ? 3 : 4)) + shell.s(14))
                                           : shell.s(32)
                width: targetWidth
                Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                height: shell.s(34)
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
                    opacity: wsPill.showAppIcons ? 0 : 1
                    text: wsPill.wsId.toString()
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
                                color: wsPill.stateLabel === "active" ? (ctx.cyberChrome ? mocha.base : mocha.crust) : mocha.text
                            }
                        }
                    }
                }

                MouseArea {
                    id: wsPillMouse
                    hoverEnabled: true
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh " + wsPill.wsId])
                    onWheel: (wheel) => {
                        shell.handleWorkspaceWheel(wheel.angleDelta.y, root.wsCount);
                        wheel.accepted = true;
                    }
                }
            }
        }
    }
}
