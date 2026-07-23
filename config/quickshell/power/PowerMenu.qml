import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import ".."

Item {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 16
    readonly property int panelRadius: Math.max(18, ThemeConfig.styleWidgetRadius + 6)
    readonly property int itemRadius: Math.max(12, Math.round(panelRadius * 0.62))
    readonly property int actionHeight: 48
    readonly property bool hasWifi: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return true;
        }
        return false;
    }
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null
    readonly property bool bluetoothOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    property bool idleInhibited: false
    readonly property bool idleSettingsEnabled: !idleInhibited

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function runAndClose(command) {
        closePanel();
        Quickshell.execDetached(["bash", "-lc", command]);
    }

    function refreshIdleInhibit() {
        if (!idleStatusProc.running) idleStatusProc.running = true;
    }

    function idleInhibitCommand(action) {
        let safeAction = String(action || "status").replace(/'/g, "'\"'\"'");
        return "kingstra_idle_action='" + safeAction + "'; " +
            "if command -v kingstra-idle-inhibit >/dev/null 2>&1; then " +
            "kingstra-idle-inhibit \"$kingstra_idle_action\"; " +
            "elif [ -x \"$HOME/.local/bin/kingstra-idle-inhibit\" ]; then " +
            "\"$HOME/.local/bin/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "elif [ -x \"$HOME/.config/shared/scripts/kingstra-idle-inhibit\" ]; then " +
            "\"$HOME/.config/shared/scripts/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "else " +
            "\"$HOME/kingstra-dots/config/shared/scripts/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "fi";
    }

    function setIdleSettingsEnabled(enabled) {
        root.idleInhibited = !enabled;
        Quickshell.execDetached(["bash", "-lc", root.idleInhibitCommand(enabled ? "off" : "on")]);
        idleRefreshTimer.restart();
    }

    Process {
        id: idleStatusProc
        command: ["bash", "-lc", root.idleInhibitCommand("status")]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.idleInhibited = this.text.trim() === "on"
        }
    }

    Timer {
        id: idleRefreshTimer
        interval: 450
        repeat: false
        onTriggered: root.refreshIdleInhibit()
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.refreshIdleInhibit()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: root.itemRadius
                color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: "󰐥"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 19
                    color: mocha.red
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    Layout.fillWidth: true
                    text: "Afsluitmenu"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: Qt.formatDateTime(new Date(), "ddd d MMM, HH:mm")
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            visible: true
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 66 : 0
            radius: root.itemRadius
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.28)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ToggleTile {
                    visible: root.hasWifi
                    Layout.fillWidth: true
                    icon: root.wifiOn ? "󰤨" : "󰤮"
                    label: "Wi-Fi"
                    active: root.wifiOn
                    accent: mocha.blue
                    onTriggered: Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
                }

                ToggleTile {
                    visible: root.hasBluetooth
                    Layout.fillWidth: true
                    icon: root.bluetoothOn ? "󰂱" : "󰂲"
                    label: "Bluetooth"
                    active: root.bluetoothOn
                    accent: mocha.mauve
                    onTriggered: Quickshell.execDetached([
                        "bash",
                        Quickshell.env("HOME") + "/.config/quickshell/network/bluetooth_panel_logic.sh",
                        "--toggle"
                    ])
                }

                ToggleTile {
                    Layout.fillWidth: true
                    icon: root.idleSettingsEnabled ? "󰾪" : "󰅶"
                    label: "Idle-instellingen"
                    subtitle: root.idleSettingsEnabled ? "Aan" : "Uit, scherm blijft aan"
                    active: root.idleSettingsEnabled
                    showSwitch: true
                    accent: mocha.yellow
                    onTriggered: root.setIdleSettingsEnabled(!root.idleSettingsEnabled)
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            ActionRow {
                icon: "󰌾"
                label: "Vergrendelen"
                accent: mocha.yellow
                onTriggered: root.runAndClose("if [ -x \"$HOME/.config/hypr/scripts/lock.sh\" ]; then \"$HOME/.config/hypr/scripts/lock.sh\"; else loginctl lock-session; fi")
            }
            ActionRow {
                icon: "󰒲"
                label: "Sluimerstand"
                accent: mocha.blue
                onTriggered: root.runAndClose("systemctl suspend")
            }
            ActionRow {
                icon: "󰍃"
                label: "Uitloggen"
                accent: mocha.peach
                onTriggered: root.runAndClose("hyprctl dispatch exit")
            }
            ActionRow {
                icon: "󰑓"
                label: "Herstarten"
                holdToTrigger: true
                accent: mocha.mauve
                onTriggered: root.runAndClose("systemctl reboot")
            }
            ActionRow {
                icon: "󰐥"
                label: "Afsluiten"
                holdToTrigger: true
                accent: mocha.red
                onTriggered: root.runAndClose("systemctl poweroff -i")
            }
        }
    }

    component ToggleTile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property bool showSwitch: false
        property color accent: mocha.primary
        signal triggered()

        Layout.preferredHeight: showSwitch ? 50 : 42
        radius: root.itemRadius
        color: active
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.24)
            : (mouse.containsMouse ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.40) : "transparent")
        border.width: 1
        border.color: active
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                text: tile.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 16
                color: tile.active ? tile.accent : mocha.subtext0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: tile.subtitle === "" ? 12 : 11
                    font.weight: Font.DemiBold
                    color: mocha.text
                    elide: Text.ElideRight
                }

                Text {
                    visible: tile.subtitle !== ""
                    Layout.fillWidth: true
                    text: tile.subtitle
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 9
                    color: tile.active ? tile.accent : mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: tile.showSwitch
                Layout.preferredWidth: 34
                Layout.preferredHeight: 18
                radius: height / 2
                color: tile.active
                    ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.42)
                    : Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.50)
                border.width: 1
                border.color: tile.active
                    ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.62)
                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    x: tile.active ? parent.width - width - 2 : 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: tile.active ? tile.accent : mocha.subtext0
                    Behavior on x { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                }
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.triggered()
        }
    }

    component ActionRow: Rectangle {
        id: action
        property string icon: ""
        property string label: ""
        property bool holdToTrigger: false
        property bool armed: false
        property color accent: mocha.primary
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: root.actionHeight
        radius: root.itemRadius
        color: mouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.14)
            : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.20)
        border.width: 1
        border.color: mouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.40)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12

            Text {
                text: action.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 17
                color: action.accent
            }
            Text {
                Layout.fillWidth: true
                text: action.armed ? "Vasthouden..." : action.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: mocha.text
                elide: Text.ElideRight
            }
            Text {
                visible: action.holdToTrigger
                text: "hold"
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                color: mocha.subtext0
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            pressAndHoldInterval: 1200
            onPressed: action.armed = action.holdToTrigger
            onReleased: action.armed = false
            onCanceled: action.armed = false
            onClicked: if (!action.holdToTrigger) action.triggered()
            onPressAndHold: {
                if (action.holdToTrigger) action.triggered();
            }
        }
    }
}
