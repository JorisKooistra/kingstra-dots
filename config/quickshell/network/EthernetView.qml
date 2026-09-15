import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Bedraad netwerk is status/informatie, geen radio die je aan of uit zet.
// Deze view houdt die rol bewust compact en voorkomt dat een ethernetklik in
// de Wi-Fi/Bluetooth-radar terechtkomt.
Item {
    id: root

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(value) { return scaler.s(value); }

    MatugenColors { id: mocha }

    property var ethernet: ({ power: "off", connected: null })
    readonly property var connection: ethernet && ethernet.connected ? ethernet.connected : null
    readonly property bool connected: connection !== null

    Process {
        id: ethernetPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/network/eth_panel_logic.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ethernet = JSON.parse(this.text.trim()); } catch (error) {}
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!ethernetPoller.running) ethernetPoller.running = true
    }

    Rectangle {
        anchors.fill: parent
        radius: root.s(Math.max(14, ThemeConfig.styleWidgetRadius))
        color: "transparent"
        clip: true

        Rectangle {
            width: parent.width * 0.9
            height: width
            radius: width / 2
            x: parent.width * 0.30
            y: parent.height * 0.43
            color: mocha.green
            opacity: root.connected ? 0.075 : 0.025
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(26)
            spacing: root.s(16)

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(14)

                Rectangle {
                    Layout.preferredWidth: root.s(48)
                    Layout.preferredHeight: root.s(48)
                    radius: root.s(16)
                    color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, root.connected ? 0.20 : 0.08)
                    border.width: 1
                    border.color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, root.connected ? 0.48 : 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: "󰈀"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: root.s(24)
                        color: root.connected ? mocha.green : mocha.overlay0
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root.connected ? (root.connection.name || "Bedrade verbinding") : "Bedraad netwerk"
                        elide: Text.ElideRight
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: root.s(19)
                        font.weight: Font.Bold
                        color: mocha.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.connected ? "Ethernet · verbonden" : "Geen kabelverbinding actief"
                        elide: Text.ElideRight
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: root.s(12)
                        color: root.connected ? mocha.green : mocha.subtext0
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root.s(10)
                    Layout.preferredHeight: root.s(10)
                    radius: width / 2
                    color: root.connected ? mocha.green : mocha.overlay0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: mocha.shellDivider
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(184)
                radius: root.s(Math.max(12, ThemeConfig.styleWidgetRadius))
                color: mocha.shellRaisedFill
                border.width: 1
                border.color: mocha.shellOutline

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.s(18)
                    spacing: root.s(12)

                    Text {
                        text: root.connected ? "Verbindingsdetails" : "Ethernet wacht op een verbinding"
                        font.family: ThemeConfig.monoFont
                        font.pixelSize: root.s(12)
                        font.weight: Font.Bold
                        color: mocha.text
                    }

                    DetailRow { icon: "󰩟"; label: "IP-adres"; value: root.connected ? (root.connection.ip || "—") : "—" }
                    DetailRow { icon: "󰖟"; label: "Snelheid"; value: root.connected ? (root.connection.speed || "Onbekend") : "—" }
                    DetailRow { icon: "󰒋"; label: "Interface"; value: root.connected ? (root.connection.id || "—") : "—" }
                    DetailRow { icon: "󰑬"; label: "MAC-adres"; value: root.connected ? (root.connection.mac || "—") : "—" }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                Layout.fillWidth: true
                text: root.connected
                    ? "Bedraad netwerk wordt automatisch door NetworkManager beheerd."
                    : "Sluit een ethernetkabel aan; deze weergave ververst automatisch."
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.family: ThemeConfig.uiFont
                font.pixelSize: root.s(11)
                color: mocha.subtext0
            }
        }
    }

    component DetailRow: RowLayout {
        property string icon: ""
        property string label: ""
        property string value: ""
        Layout.fillWidth: true
        spacing: root.s(10)
        Text {
            text: parent.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.s(15)
            color: mocha.green
        }
        Text {
            text: parent.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: root.s(11)
            color: mocha.subtext0
            Layout.preferredWidth: root.s(74)
        }
        Text {
            text: parent.value
            elide: Text.ElideRight
            font.family: ThemeConfig.monoFont
            font.pixelSize: root.s(11)
            font.weight: Font.Medium
            color: mocha.text
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
        }
    }
}
