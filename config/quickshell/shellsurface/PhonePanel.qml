import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Telefoon (KDE Connect): per gekoppelde telefoon de batterij en vier
// knoppen: laten afgaan, klembord sturen, bestand sturen en een testbericht.
// Meldingen van de telefoon komen vanzelf in het meldingencentrum.
// Alles via je eigen netwerk, niets via internet (phone.py).
Item {
    id: root

    MatugenColors { id: mocha }

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/phone.py"
    readonly property int pad: 16
    readonly property int radius: Math.max(10, Math.min(18, ThemeConfig.styleWidgetRadius))
    readonly property int preferredPanelWidth: 400
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

    property bool loaded: false
    property bool installed: true
    property var devices: []
    property string busy: ""

    function refresh() { if (!statusProc.running) statusProc.running = true; }
    function act(action, dev) {
        busy = action + ":" + dev.id;
        actProc.command = ["python3", script, action, dev.id];
        actProc.running = true;
    }
    function batteryIcon(dev) {
        if (dev.battery < 0) return "󰂑";
        if (dev.charging) return "󰂄";
        let steps = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(9, Math.floor(dev.battery / 10)))];
    }

    Component.onCompleted: refresh()

    Process {
        id: statusProc
        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim() || "{}");
                    root.installed = data.installed !== false;
                    root.devices = Array.isArray(data.devices) ? data.devices : [];
                } catch (e) {
                    root.devices = [];
                }
                root.loaded = true;
            }
        }
    }
    Process {
        id: actProc
        onExited: (code) => {
            let what = root.busy.split(":")[0];
            root.busy = "";
            if (code !== 0 && what !== "share")
                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/feedback.sh",
                    "󰄜", "Telefoon niet bereikt", "Staat KDE Connect open op je telefoon, op hetzelfde netwerk?", "3500"]);
            root.refresh();
        }
    }
    // Zolang het paneel open is: batterij en bereikbaarheid bijhouden.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "󰄜"; font.family: ThemeConfig.iconFont; font.pixelSize: 17; color: mocha.accent2 }
            Text { text: "Telefoon"; font.family: ThemeConfig.displayFont; font.pixelSize: 16; font.weight: Font.Black; color: mocha.text }
            Item { Layout.fillWidth: true }
            Rectangle {
                visible: root.installed
                implicitWidth: setLabel.implicitWidth + 18
                implicitHeight: 24
                radius: 12
                color: setMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10) : "transparent"
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(140) } }
                Text { id: setLabel; anchors.centerIn: parent; text: "Koppelen…"; font.family: ThemeConfig.uiFont; font.pixelSize: 11; color: mocha.subtext0 }
                MouseArea { id: setMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["python3", root.script, "app"]) }
            }
        }

        Text {
            visible: !root.installed || (root.loaded && root.devices.length === 0)
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: !root.installed
                ? "KDE Connect is nog niet geïnstalleerd. De updater zet hem erbij (kingstra update)."
                : "Nog geen telefoon. Installeer KDE Connect op je telefoon (Play Store of F-Droid), zorg dat hij op hetzelfde netwerk zit en kies Koppelen…"
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            color: mocha.subtext0
        }
        Text {
            visible: root.installed && !root.loaded
            text: "Zoeken…"
            font.family: ThemeConfig.uiFont; font.pixelSize: 11; color: mocha.subtext0
        }

        Repeater {
            model: root.devices
            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property bool usable: modelData.reachable && modelData.paired
                Layout.fillWidth: true
                implicitHeight: cardCol.implicitHeight + 20
                radius: root.radius
                color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, usable ? 0.55 : 0.30)
                border.width: 1
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

                ColumnLayout {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            text: card.modelData.type === "tablet" ? "󰓶" : "󰄜"
                            font.family: ThemeConfig.iconFont; font.pixelSize: 20
                            color: card.usable ? mocha.accent1 : mocha.subtext0
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: String(card.modelData.name || "Telefoon")
                                elide: Text.ElideRight
                                font.family: ThemeConfig.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
                                color: mocha.text
                            }
                            Text {
                                text: !card.modelData.paired ? "Niet gekoppeld"
                                    : (!card.modelData.reachable ? "Niet in de buurt" : "Verbonden")
                                font.family: ThemeConfig.uiFont; font.pixelSize: 10
                                color: mocha.subtext0
                            }
                        }
                        Text {
                            visible: card.usable && card.modelData.battery >= 0
                            text: root.batteryIcon(card.modelData) + " " + card.modelData.battery + "%"
                            font.family: ThemeConfig.iconFont; font.pixelSize: 12
                            color: card.modelData.battery <= 15 && !card.modelData.charging ? mocha.red : mocha.text
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        visible: card.usable || (card.modelData.reachable && !card.modelData.paired)
                        Repeater {
                            model: card.usable
                                ? [
                                    { a: "ring", icon: "󰂞", label: "Laten afgaan" },
                                    { a: "clipboard", icon: "󰅍", label: "Klembord sturen" },
                                    { a: "share", icon: "󰈙", label: "Bestand sturen" },
                                    { a: "ping", icon: "󰍡", label: "Testbericht" }
                                ]
                                : [{ a: "pair", icon: "󰌹", label: "Koppelen" }]
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool working: root.busy === modelData.a + ":" + card.modelData.id
                                implicitWidth: chipRow.implicitWidth + 18
                                implicitHeight: 28
                                radius: 14
                                color: chipMouse.containsMouse
                                    ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.22)
                                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(140) } }
                                opacity: working ? 0.6 : 1
                                Row {
                                    id: chipRow
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: chip.modelData.icon; font.family: ThemeConfig.iconFont; font.pixelSize: 13; color: mocha.text; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: chip.working ? "Bezig…" : chip.modelData.label; font.family: ThemeConfig.uiFont; font.pixelSize: 11; color: mocha.text; anchors.verticalCenter: parent.verticalCenter }
                                }
                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (root.busy === "") root.act(chip.modelData.a, card.modelData)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
