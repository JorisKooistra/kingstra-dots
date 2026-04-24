import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "../"

Item {
    id: root
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    MatugenColors { id: theme }

    readonly property int workspaceCount: 10
    readonly property int columns: 5
    readonly property int rows: 2
    readonly property int groupBase: Math.floor((Math.max(1, activeWorkspaceId) - 1) / workspaceCount) * workspaceCount
    readonly property int cardWidth: root.s(196)
    readonly property int cardHeight: root.s(188)
    readonly property int gap: root.s(12)
    property int activeWorkspaceId: 1
    property int hoveredWorkspaceId: -1
    property int dropTargetWorkspaceId: -1
    property int dropTargetWindowWorkspaceId: -1
    property int dragSourceWorkspaceId: -1
    property bool suppressWorkspaceClick: false
    property string draggedWindowAddress: ""
    property string dropTargetWindowAddress: ""
    property var windows: []
    property var monitors: []
    property var gridOrder: ({})
    property var pendingWindowMoves: ({})
    readonly property string gridStateScript: Quickshell.env("HOME") + "/.config/quickshell/workspaces/workspace-grid-state.sh"

    function s(value) {
        return scaler.s(value);
    }

    function workspaceIdAt(index) {
        return groupBase + index + 1;
    }

    function blockWorkspaceClick() {
        suppressWorkspaceClick = true;
        suppressWorkspaceClickTimer.restart();
    }

    function isShellWindow(win) {
        var title = String(win.title || "");
        var klass = String(win.class || "");
        var initialClass = String(win.initialClass || "");
        return title === "qs-master" || klass === "org.quickshell" || initialClass === "org.quickshell";
    }

    function windowsForWorkspace(wsId) {
        return windows.filter(function(win) {
            return effectiveWorkspaceId(win) === wsId && !isShellWindow(win);
        });
    }

    function effectiveWorkspaceId(win) {
        var address = String(win.address || "");
        if (address !== "" && pendingWindowMoves[address] !== undefined)
            return Number(pendingWindowMoves[address]);

        return win.workspace ? Number(win.workspace.id || -1) : -1;
    }

    function setPendingWindowMove(address, wsId) {
        var next = Object.assign({}, pendingWindowMoves);
        next[String(address)] = wsId;
        pendingWindowMoves = next;
        pendingMoveCleanupTimer.restart();
    }

    function reconcilePendingWindowMoves(clientList) {
        var next = Object.assign({}, pendingWindowMoves);
        var changed = false;

        for (var i = 0; i < clientList.length; i++) {
            var client = clientList[i];
            var address = String(client.address || "");
            if (address !== "" && next[address] !== undefined && client.workspace && Number(client.workspace.id || -1) === Number(next[address])) {
                delete next[address];
                changed = true;
            }
        }

        if (changed)
            pendingWindowMoves = next;
    }

    function orderedWindowsForWorkspace(wsId) {
        var list = windowsForWorkspace(wsId).slice();
        var key = String(wsId);
        var order = Array.isArray(gridOrder[key]) ? gridOrder[key] : [];

        return list.sort(function(a, b) {
            var ai = order.indexOf(String(a.address || ""));
            var bi = order.indexOf(String(b.address || ""));
            if (ai === -1 && bi === -1)
                return 0;
            if (ai === -1)
                return 1;
            if (bi === -1)
                return -1;
            return ai - bi;
        });
    }

    function addressOrderForWorkspace(wsId) {
        var ordered = orderedWindowsForWorkspace(wsId);
        var addresses = [];
        for (var i = 0; i < ordered.length; i++) {
            var address = String(ordered[i].address || "");
            if (address !== "")
                addresses.push(address);
        }
        return addresses;
    }

    function setWorkspaceOrder(wsId, addresses) {
        var next = Object.assign({}, gridOrder);
        next[String(wsId)] = addresses;
        gridOrder = next;
        saveGridOrder();
    }

    function saveGridOrder() {
        Quickshell.execDetached(["bash", gridStateScript, "save", JSON.stringify(gridOrder)]);
    }

    function removeAddressFromAllOrders(address) {
        var next = Object.assign({}, gridOrder);
        var changed = false;

        for (var key in next) {
            if (!Array.isArray(next[key]))
                continue;

            var filtered = next[key].filter(function(item) {
                return item !== address;
            });

            if (filtered.length !== next[key].length) {
                next[key] = filtered;
                changed = true;
            }
        }

        if (changed) {
            gridOrder = next;
            saveGridOrder();
        }
    }

    function appendAddressToOrder(wsId, address) {
        var addresses = addressOrderForWorkspace(wsId).filter(function(item) {
            return item !== address;
        });
        addresses.push(address);
        setWorkspaceOrder(wsId, addresses);
    }

    function reorderWindowInWorkspace(wsId, draggedAddress, targetAddress) {
        if (!draggedAddress || !targetAddress || draggedAddress === targetAddress)
            return;

        // Swap positions in gridOrder
        var addresses = addressOrderForWorkspace(wsId);
        var di = addresses.indexOf(draggedAddress);
        var ti = addresses.indexOf(targetAddress);

        // Ensure both are present
        if (di === -1) { addresses.push(draggedAddress); di = addresses.length - 1; }
        if (ti === -1) { addresses.push(targetAddress); ti = addresses.length - 1; }

        var tmp = addresses[di];
        addresses[di] = addresses[ti];
        addresses[ti] = tmp;
        setWorkspaceOrder(wsId, addresses);

        // Swap in Hyprland's tiling layout: focus dragged window first, then swap with target
        Quickshell.execDetached(["bash", "-c",
            "hyprctl dispatch focuswindow address:" + draggedAddress +
            " && hyprctl dispatch swapwindow address:" + targetAddress
        ]);
        refreshTimer.restart();
    }

    function monitorForWindow(win) {
        for (var i = 0; i < monitors.length; i++) {
            if (monitors[i].id === win.monitor)
                return monitors[i];
        }
        return monitors.length > 0 ? monitors[0] : ({ x: 0, y: 0, width: 1920, height: 1080, scale: 1 });
    }

    function monitorLogicalWidth(mon) {
        return Math.max(1, Number(mon.width || 1920) / Math.max(0.1, Number(mon.scale || 1)));
    }

    function monitorLogicalHeight(mon) {
        return Math.max(1, Number(mon.height || 1080) / Math.max(0.1, Number(mon.scale || 1)));
    }

    function previewWidth(win, areaWidth) {
        var mon = monitorForWindow(win);
        var ratio = Number(win.size ? win.size[0] : 1) / monitorLogicalWidth(mon);
        return Math.max(s(34), Math.min(areaWidth, Math.round(areaWidth * ratio)));
    }

    function previewHeight(win, areaHeight) {
        var mon = monitorForWindow(win);
        var ratio = Number(win.size ? win.size[1] : 1) / monitorLogicalHeight(mon);
        return Math.max(s(28), Math.min(areaHeight, Math.round(areaHeight * ratio)));
    }

    function previewX(win, areaWidth) {
        var mon = monitorForWindow(win);
        var rawX = Number(win.at ? win.at[0] : mon.x) - Number(mon.x || 0);
        var x = Math.round((rawX / monitorLogicalWidth(mon)) * areaWidth);
        return Math.max(0, Math.min(areaWidth - previewWidth(win, areaWidth), x));
    }

    function previewY(win, areaHeight) {
        var mon = monitorForWindow(win);
        var rawY = Number(win.at ? win.at[1] : mon.y) - Number(mon.y || 0);
        var y = Math.round((rawY / monitorLogicalHeight(mon)) * areaHeight);
        return Math.max(0, Math.min(areaHeight - previewHeight(win, areaHeight), y));
    }

    function orderIndexForWindow(wsId, address) {
        var key = String(wsId);
        var order = Array.isArray(gridOrder[key]) ? gridOrder[key] : [];
        var index = order.indexOf(String(address || ""));
        return index === -1 ? 0 : index;
    }

    function toplevelForAddress(address) {
        var target = String(address || "").replace(/^0x/i, "").toLowerCase();
        var values = Hyprland.toplevels.values;
        for (var i = 0; i < values.length; i++) {
            var hyprToplevel = values[i];
            var current = String(hyprToplevel.address || "").replace(/^0x/i, "").toLowerCase();
            if (current === target)
                return hyprToplevel.wayland;
        }
        return null;
    }

    function switchWorkspace(wsId) {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "workspace", String(wsId)]);
    }

    function moveWindowToWorkspace(address, wsId, sourceWsId) {
        if (!address || wsId < 1)
            return;

        if (sourceWsId && sourceWsId !== wsId) {
            removeAddressFromAllOrders(address);
            appendAddressToOrder(wsId, address);
        }

        setPendingWindowMove(address, wsId);
        Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspacesilent", wsId + ",address:" + address]);
        postDropRefreshTimer.restart();
        secondPostDropRefreshTimer.restart();
        refreshTimer.restart();
    }

    function windowIcon(win) {
        var raw = String(win.initialClass || win.class || "").replace(/\.desktop$/i, "");
        if (raw === "")
            return "application-x-executable";

        var lower = raw.toLowerCase();
        var candidates = [raw, lower, raw + ".desktop", lower + ".desktop"];
        for (var i = 0; i < candidates.length; i++) {
            var exactEntry = DesktopEntries.byId(candidates[i]);
            if (exactEntry && exactEntry.icon)
                return String(exactEntry.icon);
        }

        var heuristicEntry = DesktopEntries.heuristicLookup(raw);
        if (heuristicEntry && heuristicEntry.icon)
            return String(heuristicEntry.icon);

        return raw;
    }

    function cleanTitle(win) {
        var title = String(win.title || win.class || "Venster");
        return title.length > 42 ? title.slice(0, 39) + "..." : title;
    }

    function refresh() {
        if (!clientsProcess.running)
            clientsProcess.running = true;
        if (!activeWorkspaceProcess.running)
            activeWorkspaceProcess.running = true;
        if (!monitorsProcess.running)
            monitorsProcess.running = true;
    }

    Component.onCompleted: {
        forceActiveFocus();
        gridStateLoadProcess.running = true;
        refresh();
    }

    Shortcut {
        sequence: "Left"
        onActivated: Hyprland.dispatch("workspace r-1")
    }

    Shortcut {
        sequence: "Right"
        onActivated: Hyprland.dispatch("workspace r+1")
    }

    Shortcut {
        sequence: "1"
        onActivated: root.switchWorkspace(root.groupBase + 1)
    }

    Shortcut {
        sequence: "2"
        onActivated: root.switchWorkspace(root.groupBase + 2)
    }

    Shortcut {
        sequence: "3"
        onActivated: root.switchWorkspace(root.groupBase + 3)
    }

    Shortcut {
        sequence: "4"
        onActivated: root.switchWorkspace(root.groupBase + 4)
    }

    Shortcut {
        sequence: "5"
        onActivated: root.switchWorkspace(root.groupBase + 5)
    }

    Shortcut {
        sequence: "6"
        onActivated: root.switchWorkspace(root.groupBase + 6)
    }

    Shortcut {
        sequence: "7"
        onActivated: root.switchWorkspace(root.groupBase + 7)
    }

    Shortcut {
        sequence: "8"
        onActivated: root.switchWorkspace(root.groupBase + 8)
    }

    Shortcut {
        sequence: "9"
        onActivated: root.switchWorkspace(root.groupBase + 9)
    }

    Shortcut {
        sequence: "0"
        onActivated: root.switchWorkspace(root.groupBase + 10)
    }

    Timer {
        id: refreshTimer
        interval: 650
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        id: postDropRefreshTimer
        interval: 120
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: secondPostDropRefreshTimer
        interval: 420
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        id: pendingMoveCleanupTimer
        interval: 1800
        repeat: false
        onTriggered: root.pendingWindowMoves = ({})
    }

    Timer {
        id: suppressWorkspaceClickTimer
        interval: 260
        repeat: false
        onTriggered: root.suppressWorkspaceClick = false
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var clientList = JSON.parse(this.text || "[]");
                    root.windows = clientList;
                    root.reconcilePendingWindowMoves(clientList);
                } catch (e) {
                    root.windows = [];
                }
            }
        }
    }

    Process {
        id: activeWorkspaceProcess
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text || "{}");
                    root.activeWorkspaceId = Math.max(1, Number(data.id || 1));
                } catch (e) {
                    root.activeWorkspaceId = 1;
                }
            }
        }
    }

    Process {
        id: monitorsProcess
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(this.text || "[]");
                } catch (e) {
                    root.monitors = [];
                }
            }
        }
    }

    Process {
        id: gridStateLoadProcess
        command: ["bash", root.gridStateScript, "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.gridOrder = JSON.parse(this.text || "{}");
                } catch (e) {
                    root.gridOrder = ({});
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.s(Math.max(12, ThemeConfig.styleWidgetRadius + 4))
        color: Qt.rgba(theme.mantle.r, theme.mantle.g, theme.mantle.b, Math.min(0.96, ThemeConfig.popupOpacity + 0.06))
        border.width: 1
        border.color: Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.12)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(18)
            spacing: root.s(14)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(12)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: root.s(2)

                    Text {
                        text: "Workspaces"
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: root.s(26)
                        font.weight: Font.Black
                        color: theme.text
                    }

                    Text {
                        text: "Sleep vensters binnen of tussen workspaces. Klik om te gaan."
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: root.s(13)
                        color: theme.subtext0
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root.s(118)
                    Layout.preferredHeight: root.s(36)
                    radius: root.s(8)
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.72)
                    border.width: 1
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: (root.groupBase + 1) + "-" + (root.groupBase + root.workspaceCount)
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: root.s(13)
                        font.weight: Font.Bold
                        color: theme.blue
                    }
                }
            }

            Grid {
                id: workspaceGrid
                Layout.alignment: Qt.AlignHCenter
                columns: root.columns
                rowSpacing: root.gap
                columnSpacing: root.gap

                Repeater {
                    model: root.workspaceCount

                    delegate: Rectangle {
                        id: workspaceCard
                        required property int index
                        readonly property int wsId: root.workspaceIdAt(index)
                        readonly property var wsWindows: root.orderedWindowsForWorkspace(wsId)
                        readonly property bool active: root.activeWorkspaceId === wsId
                        readonly property bool dropTarget: root.dropTargetWorkspaceId === wsId && root.draggedWindowAddress !== ""

                        width: root.cardWidth
                        height: root.cardHeight
                        radius: root.s(10)
                        color: active
                            ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.22)
                            : dropTarget
                                ? Qt.rgba(theme.teal.r, theme.teal.g, theme.teal.b, 0.18)
                                : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.58)
                        border.width: active || dropTarget ? 2 : 1
                        border.color: active
                            ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.72)
                            : dropTarget
                                ? Qt.rgba(theme.teal.r, theme.teal.g, theme.teal.b, 0.68)
                                : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.08)

                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        DropArea {
                            anchors.fill: parent
                            onEntered: {
                                root.dropTargetWorkspaceId = workspaceCard.wsId;
                                root.dropTargetWindowAddress = "";
                                root.dropTargetWindowWorkspaceId = -1;
                            }
                            onExited: {
                                if (root.dropTargetWorkspaceId === workspaceCard.wsId)
                                    root.dropTargetWorkspaceId = -1;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: {
                                if (!root.suppressWorkspaceClick)
                                    root.switchWorkspace(workspaceCard.wsId);
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: root.s(10)
                            spacing: root.s(8)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: root.s(8)

                                Rectangle {
                                    Layout.preferredWidth: root.s(34)
                                    Layout.preferredHeight: root.s(28)
                                    radius: root.s(8)
                                    color: workspaceCard.active ? theme.blue : Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.82)

                                    Text {
                                        anchors.centerIn: parent
                                        text: workspaceCard.wsId
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: root.s(13)
                                        font.weight: Font.Black
                                        color: workspaceCard.active ? theme.crust : theme.text
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: workspaceCard.wsWindows.length === 1 ? "1 venster" : workspaceCard.wsWindows.length + " vensters"
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: root.s(12)
                                    font.weight: Font.DemiBold
                                    color: workspaceCard.active ? theme.text : theme.subtext0
                                    elide: Text.ElideRight
                                }
                            }

                            Item {
                                id: previewArea
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                Repeater {
                                    model: workspaceCard.wsWindows

                                    delegate: Item {
                                        id: windowSlot
                                        required property var modelData
                                        readonly property string windowAddress: String(modelData.address || "")
                                        readonly property var sourceToplevel: root.toplevelForAddress(windowAddress)
                                        x: root.previewX(modelData, previewArea.width)
                                        y: root.previewY(modelData, previewArea.height)
                                        width: root.previewWidth(modelData, previewArea.width)
                                        height: root.previewHeight(modelData, previewArea.height)
                                        z: dragMouse.drag.active ? 50 : 2 + root.orderIndexForWindow(workspaceCard.wsId, windowAddress) + (modelData.floating ? 20 : 0) + (modelData.fullscreen ? 30 : 0)

                                        Behavior on x { enabled: !dragMouse.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on y { enabled: !dragMouse.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on width { enabled: !dragMouse.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on height { enabled: !dragMouse.drag.active; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            id: windowPreview
                                            width: windowSlot.width
                                            height: windowSlot.height
                                            radius: root.s(8)
                                            color: dragMouse.pressed
                                                ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28)
                                                : Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.78)
                                            border.width: 1
                                            border.color: root.dropTargetWindowAddress === windowSlot.windowAddress
                                                ? Qt.rgba(theme.teal.r, theme.teal.g, theme.teal.b, 0.82)
                                                : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.10)
                                            clip: true

                                            Drag.active: dragMouse.drag.active
                                            Drag.hotSpot.x: width / 2
                                            Drag.hotSpot.y: height / 2

                                            Behavior on border.color { ColorAnimation { duration: 140 } }

                                            ScreencopyView {
                                                anchors.fill: parent
                                                captureSource: windowSlot.sourceToplevel
                                                live: true
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: dragMouse.containsMouse || root.dropTargetWindowAddress === windowSlot.windowAddress
                                                    ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.14)
                                                    : Qt.rgba(theme.crust.r, theme.crust.g, theme.crust.b, 0.10)
                                            }

                                            DropArea {
                                                anchors.fill: parent
                                                onEntered: {
                                                    if (root.draggedWindowAddress !== "" && root.draggedWindowAddress !== windowSlot.windowAddress) {
                                                        root.dropTargetWorkspaceId = workspaceCard.wsId;
                                                        root.dropTargetWindowWorkspaceId = workspaceCard.wsId;
                                                        root.dropTargetWindowAddress = windowSlot.windowAddress;
                                                    }
                                                }
                                                onExited: {
                                                    if (root.dropTargetWindowAddress === windowSlot.windowAddress) {
                                                        root.dropTargetWindowAddress = "";
                                                        root.dropTargetWindowWorkspaceId = -1;
                                                    }
                                                }
                                            }

                                            Row {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.bottom: parent.bottom
                                                anchors.margins: root.s(4)
                                                height: root.s(24)
                                                spacing: root.s(4)

                                                Image {
                                                    width: root.s(16)
                                                    height: root.s(16)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    sourceSize.width: width
                                                    sourceSize.height: height
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    source: "image://icon/" + root.windowIcon(windowSlot.modelData)
                                                }

                                                Text {
                                                    width: parent.width - root.s(22)
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: root.cleanTitle(windowSlot.modelData)
                                                    font.family: ThemeConfig.uiFont
                                                    font.pixelSize: root.s(10)
                                                    color: theme.text
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.WordWrap
                                                }
                                            }

                                            MouseArea {
                                                id: dragMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                drag.target: windowPreview
                                                drag.threshold: root.s(8)
                                                onPressed: {
                                                    root.blockWorkspaceClick();
                                                    root.draggedWindowAddress = windowSlot.windowAddress;
                                                    root.dragSourceWorkspaceId = workspaceCard.wsId;
                                                    root.dropTargetWorkspaceId = workspaceCard.wsId;
                                                    root.dropTargetWindowWorkspaceId = -1;
                                                    root.dropTargetWindowAddress = "";
                                                }
                                                onReleased: {
                                                    root.blockWorkspaceClick();
                                                    var movedBetweenWorkspaces = false;
                                                    var sourceWsId = root.dragSourceWorkspaceId > 0 ? root.dragSourceWorkspaceId : workspaceCard.wsId;
                                                    if (root.dropTargetWindowAddress !== "" && root.dropTargetWindowWorkspaceId === sourceWsId) {
                                                        root.reorderWindowInWorkspace(sourceWsId, root.draggedWindowAddress, root.dropTargetWindowAddress);
                                                    } else if (root.dropTargetWorkspaceId !== -1 && root.dropTargetWorkspaceId !== sourceWsId) {
                                                        root.moveWindowToWorkspace(root.draggedWindowAddress, root.dropTargetWorkspaceId, sourceWsId);
                                                        movedBetweenWorkspaces = true;
                                                    }

                                                    root.draggedWindowAddress = "";
                                                    root.dragSourceWorkspaceId = -1;
                                                    root.dropTargetWorkspaceId = -1;
                                                    root.dropTargetWindowWorkspaceId = -1;
                                                    root.dropTargetWindowAddress = "";
                                                    if (!movedBetweenWorkspaces) {
                                                        windowPreview.x = 0;
                                                        windowPreview.y = 0;
                                                    }
                                                }
                                                onCanceled: root.blockWorkspaceClick()
                                                onClicked: {
                                                    root.blockWorkspaceClick();
                                                    if (windowSlot.modelData.address)
                                                        Hyprland.dispatch("focuswindow address:" + windowSlot.modelData.address);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(10)

                Text {
                    Layout.fillWidth: true
                    text: "Tip: Alt+Tab gaat terug naar de vorige workspace."
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: root.s(12)
                    color: theme.overlay0
                }

                Text {
                    text: "Esc sluit"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: root.s(12)
                    font.weight: Font.Bold
                    color: theme.subtext0
                }
            }
        }
    }
}
