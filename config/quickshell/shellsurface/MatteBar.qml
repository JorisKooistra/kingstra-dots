import QtQuick
import Quickshell.Hyprland
import ".."

// Drie losse eilanden. Alleen de pillen krijgen een input-region; de ruimte
// ertussen blijft wallpaper en laat muisklikken door naar de vensters.
Item {
    id: bar
    required property var chrome
    required property var mocha
    property bool active: false
    property bool revealed: true
    readonly property bool hovered: leftHover.hovered || workspaceHover.hovered || rightHover.hovered
    readonly property int pillY: revealed ? 8 : (chrome.stripOnBottom ? height - 2 : -pillHeight + 2)
    readonly property Item leftHitRegion: leftPill
    readonly property Item centerHitRegion: workspacePill
    readonly property Item rightHitRegion: rightPill
    readonly property int inset: 10
    readonly property int pillHeight: 28
    readonly property color fill: Qt.rgba(mocha.mantle.r, mocha.mantle.g, mocha.mantle.b, 0.96)
    readonly property color ink: mocha.subtext0
    visible: active

    function openFrom(item, target) {
        let p = item.mapToItem(chrome, item.width / 2, item.height);
        chrome.lastTriggerX = p.x;
        chrome.lastTriggerY = p.y;
        chrome.hoverRequest = false;
        chrome.togglePanel(target);
    }

    component QuietButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        property string tip: ""
        property string target: ""
        property bool lit: false
        implicitWidth: label !== "" ? labelText.implicitWidth + 10 : 24
        implicitHeight: 24
        radius: 6
        color: mouse.containsMouse ? bar.mocha.shellHoverFill : "transparent"
        Text {
            id: labelText
            anchors.centerIn: parent
            text: button.label !== "" ? button.label : button.icon
            font.family: button.label !== "" ? ThemeConfig.monoFont : ThemeConfig.iconFont
            font.pixelSize: button.label !== "" ? 11 : 13
            font.weight: Font.Normal
            color: button.lit ? bar.mocha.accent1 : bar.ink
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bar.chrome.showTooltip(button, button.tip, false)
            onExited: bar.chrome.hideTooltip(button.tip)
            onClicked: bar.openFrom(button, button.target)
        }
    }

    Rectangle {
        id: leftPill
        HoverHandler { id: leftHover }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        x: bar.inset; y: bar.pillY
        width: bar.active ? leftRow.width + 12 : 0
        height: bar.active ? bar.pillHeight : 0
        radius: 8; color: bar.fill
        Row {
            id: leftRow
            anchors.centerIn: parent
            spacing: 3
            QuietButton { icon: "󰒓"; tip: "Controlecentrum"; target: "tophover" }
            QuietButton { visible: bar.chrome.moduleEnabled("clock"); label: bar.chrome.timeText; tip: "Agenda"; target: "calendar" }
            QuietButton {
                visible: bar.chrome.moduleEnabled("notifications")
                icon: NotificationService.dnd ? "󰂛" : "󰂚"
                lit: NotificationService.count > 0
                tip: bar.chrome.notificationTooltip; target: "notifications"
            }
        }
    }

    Rectangle {
        id: workspacePill
        HoverHandler { id: workspaceHover }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        x: Math.round((bar.width - width) / 2); y: bar.pillY
        width: bar.active && bar.chrome.moduleEnabled("workspaces") ? dots.width + 20 : 0
        visible: width > 0
        height: bar.active ? bar.pillHeight : 0
        radius: 8; color: bar.fill
        Row {
            id: dots
            anchors.centerIn: parent
            spacing: 0
            Repeater {
                model: bar.chrome.workspaceCount
                Item {
                    id: workspace
                    required property int index
                    readonly property int workspaceId: index + 1
                    readonly property bool selected: {
                        let monitor = bar.chrome.monitorForScreen;
                        return monitor && monitor.activeWorkspace && monitor.activeWorkspace.id === workspaceId;
                    }
                    readonly property bool occupied: {
                        let values = Hyprland.workspaces.values;
                        for (let ws of values) if (ws.id === workspaceId && ws.toplevels.values.length > 0) return true;
                        return false;
                    }
                    width: 17; height: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 8; height: 8; radius: 4
                        color: workspace.selected ? bar.mocha.accent2
                            : (wsMouse.containsMouse ? bar.mocha.subtext0 : workspace.occupied ? bar.mocha.overlay0 : bar.mocha.surface2)
                        opacity: workspace.selected || workspace.occupied || wsMouse.containsMouse ? 1 : 0.5
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: bar.chrome.showTooltip(workspace, bar.chrome.workspaceTooltip(workspace.workspaceId), false)
                        onExited: bar.chrome.hideTooltip(bar.chrome.workspaceTooltip(workspace.workspaceId))
                        onClicked: bar.chrome.switchWorkspace(workspace.workspaceId)
                        onWheel: wheel => {
                            bar.chrome.handleWorkspaceWheel(wheel.angleDelta.y, bar.chrome.workspaceCount);
                            wheel.accepted = true;
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: rightPill
        HoverHandler { id: rightHover }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        x: bar.width - width - bar.inset; y: bar.pillY
        width: bar.active ? rightRow.width + 12 : 0
        height: bar.active ? bar.pillHeight : 0
        radius: 8; color: bar.fill
        Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: 2
            QuietButton {
                visible: bar.chrome.mediaVisible
                icon: "󰝚"; tip: bar.chrome.audioTooltip; target: "audiomedia"
            }
            QuietButton { visible: bar.chrome.moduleEnabled("volume"); icon: bar.chrome.isMuted ? "󰖁" : "󰕾"; tip: bar.chrome.audioTooltip; target: "audiomedia" }
            QuietButton {
                visible: bar.chrome.moduleEnabled("network")
                icon: bar.chrome.hasWifi ? (bar.chrome.isWifiOn ? "󰤨" : "󰤮") : "󰈀"
                tip: "Netwerk en snelle instellingen"; target: "quicksettings"
            }
            QuietButton { visible: bar.chrome.hasBluetooth && bar.chrome.isBtOn; icon: "󰂯"; tip: "Bluetooth"; target: "quicksettings" }
            QuietButton { visible: bar.chrome.hasBattery; label: bar.chrome.batCap + "%"; tip: "Batterij"; target: "battery" }
            QuietButton { icon: "󰇘"; tip: "Menu en overige bediening"; target: "menu" }
        }
    }
}
