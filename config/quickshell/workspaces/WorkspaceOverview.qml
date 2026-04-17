import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    property string draggedWindowAddress: ""
    property string dropTargetWindowAddress: ""
    property var windows: []
    property var gridOrder: ({})
    readonly property string gridStateScript: Quickshell.env("HOME") + "/.config/quickshell/workspaces/workspace-grid-state.sh"

    function s(value) {
        return scaler.s(value);
    }

    function workspaceIdAt(index) {
        return groupBase + index + 1;
    }

    function windowsForWorkspace(wsId) {
        return windows.filter(function(win) {
            return win.workspace && win.workspace.id === wsId && win.title !== "qs-master";
        });
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

    function removeAddressFromOrder(wsId, address) {
        var addresses = addressOrderForWorkspace(wsId).filter(function(item) {
            return item !== address;
        });
        setWorkspaceOrder(wsId, addresses);
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

        var addresses = addressOrderForWorkspace(wsId);
        var draggedIndex = addresses.indexOf(draggedAddress);
        var targetIndex = addresses.indexOf(targetAddress);
        if (draggedIndex === -1 || targetIndex === -1)
            return;

        addresses.splice(draggedIndex, 1);
        targetIndex = addresses.indexOf(targetAddress);
        addresses.splice(targetIndex, 0, draggedAddress);
        setWorkspaceOrder(wsId, addresses);
    }

    function switchWorkspace(wsId) {
        Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh close && hyprctl dispatch workspace " + wsId]);
    }

    function moveWindowToWorkspace(address, wsId, sourceWsId) {
        if (!address || wsId < 1)
            return;

        if (sourceWsId && sourceWsId !== wsId) {
            removeAddressFromOrder(sourceWsId, address);
            appendAddressToOrder(wsId, address);
        }

        Hyprland.dispatch("movetoworkspacesilent " + wsId + ", address:" + address);
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

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(this.text || "[]");
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
                            onClicked: root.switchWorkspace(workspaceCard.wsId)
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

                            Flow {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: root.s(6)

                                Repeater {
                                    model: workspaceCard.wsWindows.slice(0, 6)

                                    delegate: Item {
                                        id: windowSlot
                                        required property var modelData
                                        readonly property string windowAddress: String(modelData.address || "")
                                        width: root.s(82)
                                        height: root.s(42)

                                        Rectangle {
                                            id: windowChip
                                            width: windowSlot.width
                                            height: windowSlot.height
                                            radius: root.s(8)
                                            color: dragMouse.pressed
                                                ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.28)
                                                : Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.8)
                                            border.width: 1
                                            border.color: root.dropTargetWindowAddress === windowSlot.windowAddress
                                                ? Qt.rgba(theme.teal.r, theme.teal.g, theme.teal.b, 0.82)
                                                : Qt.rgba(theme.text.r, theme.text.g, theme.text.b, 0.10)
                                            z: dragMouse.drag.active ? 50 : 1

                                            Drag.active: dragMouse.drag.active
                                            Drag.hotSpot.x: width / 2
                                            Drag.hotSpot.y: height / 2

                                            Behavior on border.color { ColorAnimation { duration: 140 } }

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

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: root.s(6)
                                                spacing: root.s(6)

                                                Image {
                                                    Layout.preferredWidth: root.s(18)
                                                    Layout.preferredHeight: root.s(18)
                                                    sourceSize.width: width
                                                    sourceSize.height: height
                                                    fillMode: Image.PreserveAspectFit
                                                    smooth: true
                                                    source: "image://icon/" + root.windowIcon(windowSlot.modelData)
                                                }

                                                Text {
                                                    Layout.fillWidth: true
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
                                                drag.target: windowChip
                                                drag.threshold: root.s(8)
                                                onPressed: {
                                                    root.draggedWindowAddress = windowSlot.windowAddress;
                                                    root.dropTargetWorkspaceId = workspaceCard.wsId;
                                                    root.dropTargetWindowWorkspaceId = -1;
                                                    root.dropTargetWindowAddress = "";
                                                }
                                                onReleased: {
                                                    if (root.dropTargetWindowAddress !== "" && root.dropTargetWindowWorkspaceId === workspaceCard.wsId) {
                                                        root.reorderWindowInWorkspace(workspaceCard.wsId, root.draggedWindowAddress, root.dropTargetWindowAddress);
                                                    } else if (root.dropTargetWorkspaceId !== -1 && root.dropTargetWorkspaceId !== workspaceCard.wsId) {
                                                        root.moveWindowToWorkspace(root.draggedWindowAddress, root.dropTargetWorkspaceId, workspaceCard.wsId);
                                                    }

                                                    root.draggedWindowAddress = "";
                                                    root.dropTargetWorkspaceId = -1;
                                                    root.dropTargetWindowWorkspaceId = -1;
                                                    root.dropTargetWindowAddress = "";
                                                    windowChip.x = 0;
                                                    windowChip.y = 0;
                                                }
                                                onClicked: {
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
