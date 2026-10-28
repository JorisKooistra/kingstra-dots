import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Snap-indelingen, zoals Snap Layouts in Windows 11 en de tegels van KDE
// (Super+Z). Elke kaart toont een indeling voor de huidige werkruimte;
// klik een vak en het actieve venster komt daar. Het grote vak maakt het
// venster het hoofdvenster. De indelingen zijn gewone Hyprland-layouts
// (dwindle, master, scrolling, monocle), dus alles blijft getegeld.
//
// Toetsen: 1-7 of pijltjes + Enter kiezen, S = scrollen aan/uit,
// K = actief venster naar het kladblok, Esc sluit.
FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts"
    readonly property int preferredPanelWidth: 760
    readonly property int preferredPanelHeight: 430
    property string workspace: ""
    property string current: "tegels"
    property int selectedIndex: 0

    // Vakken in fracties van de kaart: x, y, w, h, en of het het hoofdvak is.
    readonly property var presets: [
        { id: "tegels", label: "Tegels", hint: "Standaard", zones: [[0, 0, .5, 1, true], [.5, 0, .5, .5], [.5, .5, .5, .5]] },
        { id: "50-50", label: "50 | 50", hint: "Twee helften", zones: [[0, 0, .5, 1, true], [.5, 0, .5, 1]] },
        { id: "70-30", label: "70 | 30", hint: "Groot en stapel", zones: [[0, 0, .68, 1, true], [.68, 0, .32, .5], [.68, .5, .32, .5]] },
        { id: "midden", label: "Midden groot", hint: "Brede schermen", zones: [[.25, 0, .5, 1, true], [0, 0, .25, 1], [.75, 0, .25, 1]] },
        { id: "kolommen", label: "Drie kolommen", hint: "Gelijke delen", zones: [[0, 0, .333, 1, true], [.333, 0, .334, 1], [.667, 0, .333, 1]] },
        { id: "scrollen", label: "Scrollen", hint: "Oneindige strook", scroll: true, zones: [[-.3, 0, .5, 1], [.25, 0, .5, 1, true], [.8, 0, .5, 1]] },
        { id: "focus", label: "Eén tegelijk", hint: "Rest erachter", stack: true, zones: [[0, 0, 1, 1, true]] }
    ]

    function close() {
        Quickshell.execDetached(["bash", scripts + "/qs_manager.sh", "close"]);
    }

    function choose(presetId, makeMain) {
        close();
        let cmd = "\"$0\"/layout-tool.sh apply " + presetId;
        if (makeMain) cmd += " && sleep 0.2 && \"$0\"/layout-tool.sh main";
        Quickshell.execDetached(["bash", "-c", cmd, scripts]);
    }

    function toggleScroll() {
        close();
        Quickshell.execDetached(["bash", scripts + "/layout-tool.sh", "scroll"]);
    }

    function sendToScratchpad() {
        close();
        Quickshell.execDetached(["bash", scripts + "/scratchpad.sh", "send"]);
    }

    Process {
        id: currentProc
        command: ["bash", root.scripts + "/layout-tool.sh", "current"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim());
                    root.workspace = String(d.workspace || "");
                    root.current = String(d.preset || "tegels");
                    for (let i = 0; i < root.presets.length; i++) {
                        if (root.presets[i].id === root.current) root.selectedIndex = i;
                    }
                } catch (e) {}
            }
        }
    }

    focus: true
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return; }
        if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) {
            root.selectedIndex = (root.selectedIndex + 1) % root.presets.length;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) {
            root.selectedIndex = (root.selectedIndex - 1 + root.presets.length) % root.presets.length;
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Down) { root.selectedIndex = Math.min(root.presets.length - 1, root.selectedIndex + 4); event.accepted = true; return; }
        if (event.key === Qt.Key_Up) { root.selectedIndex = Math.max(0, root.selectedIndex - 4); event.accepted = true; return; }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.choose(root.presets[root.selectedIndex].id, false);
            event.accepted = true;
            return;
        }
        let t = String(event.text || "").toLowerCase();
        if (t.length === 1 && t >= "1" && t <= String(root.presets.length)) {
            root.choose(root.presets[parseInt(t) - 1].id, false);
            event.accepted = true;
            return;
        }
        if (t === "s") { root.toggleScroll(); event.accepted = true; return; }
        if (t === "k") { root.sendToScratchpad(); event.accepted = true; return; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰕰"
                font.family: ThemeConfig.iconFont
                font.pixelSize: 20
                color: mocha.primary
            }
            Text {
                Layout.fillWidth: true
                text: "Indeling" + (root.workspace !== "" ? " voor werkruimte " + root.workspace : "")
                font.family: ThemeConfig.displayFont
                font.pixelSize: 17
                font.weight: Font.Bold
                color: mocha.text
            }
            Text {
                text: "Klik een vak om het venster daar te zetten"
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext0
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 4
            rowSpacing: 12
            columnSpacing: 12

            Repeater {
                model: root.presets
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool selected: root.selectedIndex === index
                    readonly property bool active: root.current === modelData.id

                    Layout.fillWidth: true
                    Layout.preferredHeight: 138
                    radius: Math.max(14, ThemeConfig.styleWidgetRadius)
                    color: cardHover.hovered || selected
                        ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.14)
                        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.7)
                    border.width: active ? 2 : 1
                    border.color: active ? mocha.primary
                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, selected ? 0.35 : 0.08)
                    scale: cardHover.hovered ? 1.025 : 1.0
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }

                    HoverHandler {
                        id: cardHover
                        onHoveredChanged: if (hovered) root.selectedIndex = card.index
                    }

                    // Mini-scherm met de vakken.
                    Rectangle {
                        id: screen
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 10
                        height: 78
                        radius: 9
                        color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.55)
                        clip: true

                        // Bij "Eén tegelijk": twee kaarten erachter.
                        Repeater {
                            model: card.modelData.stack ? 2 : 0
                            delegate: Rectangle {
                                required property int index
                                x: 6 + (2 - index) * 5
                                y: 4 + (2 - index) * 3
                                width: screen.width - 22
                                height: screen.height - 16
                                radius: 6
                                color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06 + index * 0.04)
                            }
                        }

                        Repeater {
                            model: card.modelData.zones
                            delegate: Rectangle {
                                id: zone
                                required property var modelData
                                readonly property real pad: 3
                                readonly property bool main: modelData.length > 4 && modelData[4] === true
                                x: modelData[0] * screen.width + pad
                                y: modelData[1] * screen.height + pad
                                width: modelData[2] * screen.width - pad * 2
                                height: modelData[3] * screen.height - pad * 2
                                radius: 6
                                color: zoneMouse.containsMouse
                                    ? mocha.primary
                                    : (main ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, card.selected ? 0.55 : 0.38)
                                            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, card.selected ? 0.22 : 0.14))
                                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

                                MouseArea {
                                    id: zoneMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.choose(card.modelData.id, zone.main)
                                }
                            }
                        }

                        // Pijltjes bij Scrollen: de strook loopt door.
                        Text {
                            visible: card.modelData.scroll === true
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰁍            󰁔"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 13
                            color: mocha.text
                        }
                    }

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        spacing: 6
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                text: card.modelData.label
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: mocha.text
                            }
                            Text {
                                text: card.active ? "Nu actief" : card.modelData.hint
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                color: card.active ? mocha.primary : mocha.subtext0
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 6
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: String(card.index + 1)
                                font.family: ThemeConfig.monoFont
                                font.pixelSize: 11
                                color: mocha.subtext0
                            }
                        }
                    }

                    // Klik buiten de vakken: alleen de indeling kiezen. Onder
                    // de vakken, zodat een klik op een vak niet dubbel telt.
                    MouseArea {
                        anchors.fill: parent
                        z: -1
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.choose(card.modelData.id, false)
                    }
                }
            }

            // Achtste kaart: kladblok.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 138
                radius: Math.max(14, ThemeConfig.styleWidgetRadius)
                color: padHover.hovered
                    ? Qt.rgba(mocha.tertiary.r, mocha.tertiary.g, mocha.tertiary.b, 0.16)
                    : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.7)
                border.width: 1
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                scale: padHover.hovered ? 1.025 : 1.0
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
                HoverHandler { id: padHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.sendToScratchpad() }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 10
                    height: 78
                    radius: 9
                    color: Qt.rgba(mocha.crust.r, mocha.crust.g, mocha.crust.b, 0.55)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                        width: parent.width * 0.7
                        height: parent.height * 0.62
                        bottomLeftRadius: 7
                        bottomRightRadius: 7
                        color: Qt.rgba(mocha.tertiary.r, mocha.tertiary.g, mocha.tertiary.b, padHover.hovered ? 0.7 : 0.4)
                        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                    }
                }
                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    spacing: 0
                    Text {
                        text: "Kladblok"
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: mocha.text
                    }
                    Text {
                        text: "K · venster als dropdown"
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 10
                        color: mocha.subtext0
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "1-7 kiezen  ·  Enter toepassen  ·  S scrollen aan/uit  ·  Super+` kladblok  ·  Super+Shift+` venster erin of eruit"
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            color: mocha.subtext0
            elide: Text.ElideRight
        }
    }
}
