import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// Scherm delen: de kiezer die verschijnt als Teams, de browser of OBS wil
// meekijken. Kies een scherm, een werkruimte of één venster, met live
// voorbeeld. share-picker.sh (de custom picker van xdg-desktop-portal-
// hyprland) zet de keuzes klaar en wacht op ons antwoord.
// Toetsen: Tab of 1/2/3 wisselt de soort, pijltjes kiezen, Enter deelt, Esc
// annuleert.
FocusScope {
    id: root

    MatugenColors { id: mocha }

    readonly property string requestPath: "/tmp/kingstra-share-request.json"
    readonly property string answerPath: "/tmp/kingstra-share-answer"
    readonly property int preferredPanelWidth: 920
    readonly property int preferredPanelHeight: 400
    readonly property int cardW: 250
    readonly property int cardH: 150

    property var request: ({ screens: [], workspaces: [], windows: [] })
    property string kind: "screen"     // screen | workspace | window
    property int selectedIndex: 0
    property bool answered: false

    readonly property var kinds: {
        let out = [{ id: "screen", label: "Scherm", icon: "󰍹" }];
        if ((request.workspaces || []).length > 0) out.push({ id: "workspace", label: "Werkruimte", icon: "󰕰" });
        if ((request.windows || []).length > 0) out.push({ id: "window", label: "Venster", icon: "󰖯" });
        return out;
    }
    readonly property var items: kind === "workspace" ? (request.workspaces || [])
        : (kind === "window" ? (request.windows || []) : (request.screens || []))

    function screenFor(name) {
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i];
        return null;
    }
    function toplevelFor(address) {
        if (!address) return null;
        let list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            if (t && t.HyprlandToplevel && ("0x" + t.HyprlandToplevel.address).toLowerCase() === String(address).toLowerCase()) return t;
        }
        return null;
    }
    function keyFor(item) {
        if (kind === "screen") return "screen:" + item.name;
        if (kind === "window") return "window:" + item.handle;
        return String(item.key || "");
    }
    // closePanel false: het paneel is al weg (of er opent iets anders).
    function answer(text, closePanel) {
        if (answered) return;
        answered = true;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$2\" > \"$1\"; [ \"$4\" = 1 ] && bash \"$3\" close",
            "kq-share", answerPath, text, Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh",
            closePanel === false ? "0" : "1"]);
    }
    function choose(item) { if (item) answer(keyFor(item)); }
    function setKind(id) {
        if (kind === id) return;
        kind = id;
        selectedIndex = 0;
    }
    function cycleKind(delta) {
        let ids = kinds.map(k => k.id);
        let i = ids.indexOf(kind);
        setKind(ids[(i + delta + ids.length) % ids.length]);
    }
    function move(delta) {
        let n = items.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        grid.positionViewAtIndex(selectedIndex, GridView.Contain);
    }

    Component.onCompleted: forceActiveFocus()
    // Paneel weg zonder keuze (klik ernaast, ander paneel): niet delen.
    Component.onDestruction: if (!answered) answer("cancel", false)

    FileView {
        path: root.requestPath
        preload: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.answered = false;
            try {
                let data = JSON.parse(text() || "{}");
                root.request = {
                    screens: Array.isArray(data.screens) ? data.screens : [],
                    workspaces: Array.isArray(data.workspaces) ? data.workspaces : [],
                    windows: Array.isArray(data.windows) ? data.windows : []
                };
                let focused = root.request.screens.findIndex(s => s.focused);
                root.selectedIndex = Math.max(0, focused);
            } catch (e) {}
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { root.answer("cancel"); event.accepted = true; }
        else if (event.key === Qt.Key_Tab) { root.cycleKind(1); event.accepted = true; }
        else if (event.key === Qt.Key_Backtab) { root.cycleKind(-1); event.accepted = true; }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) {
            let k = root.kinds[event.key - Qt.Key_1];
            if (k) root.setKind(k.id);
            event.accepted = true;
        }
        else if (event.key === Qt.Key_Right) { root.move(1); event.accepted = true; }
        else if (event.key === Qt.Key_Left) { root.move(-1); event.accepted = true; }
        else if (event.key === Qt.Key_Down) { root.move(Math.max(1, Math.floor(grid.width / grid.cellWidth))); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { root.move(-Math.max(1, Math.floor(grid.width / grid.cellWidth))); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.choose(root.items[root.selectedIndex]); event.accepted = true; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "󰹑"; font.family: ThemeConfig.iconFont; font.pixelSize: 17; color: mocha.red }
            Text { text: "Wat wil je delen?"; font.family: ThemeConfig.displayFont; font.pixelSize: 16; font.weight: Font.Black; color: mocha.text }
            Item { Layout.fillWidth: true }
            Repeater {
                model: root.kinds
                delegate: Rectangle {
                    id: tab
                    required property var modelData
                    required property int index
                    readonly property bool on: root.kind === modelData.id
                    implicitWidth: tabRow.implicitWidth + 22
                    implicitHeight: 30
                    radius: 15
                    color: on ? Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.24)
                        : (tabMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : "transparent")
                    border.width: on ? 1 : 0
                    border.color: mocha.accent2
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(160) } }
                    Row {
                        id: tabRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: tab.modelData.icon; font.family: ThemeConfig.iconFont; font.pixelSize: 13; color: mocha.text; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: tab.modelData.label; font.family: ThemeConfig.uiFont; font.pixelSize: 12; font.weight: tab.on ? Font.DemiBold : Font.Normal; color: mocha.text; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: String(tab.index + 1); font.family: ThemeConfig.monoFont; font.pixelSize: 9; color: mocha.subtext0; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setKind(tab.modelData.id) }
                }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            cellWidth: root.cardW + 14
            cellHeight: root.cardH + 46
            model: root.items
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool current: root.selectedIndex === index
                readonly property var screen: root.kind === "screen" ? root.screenFor(modelData.name) : null
                readonly property var toplevel: root.kind === "window" ? root.toplevelFor(modelData.address) : null
                width: root.cardW
                height: root.cardH + 40
                scale: current ? 1.0 : 0.94
                Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(200); easing.type: Easing.OutCubic } }

                Rectangle {
                    id: frame
                    width: parent.width
                    height: root.cardH
                    radius: Math.max(10, Math.min(18, ThemeConfig.styleWidgetRadius))
                    color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.72)
                    border.width: card.current ? 2 : 1
                    border.color: card.current ? mocha.accent2 : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(160) } }

                    ScreencopyView {
                        id: preview
                        anchors.fill: parent
                        anchors.margins: 4
                        captureSource: card.screen !== null ? card.screen : card.toplevel
                        live: card.current
                        opacity: hasContent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !preview.hasContent
                        text: root.kind === "workspace" ? String(card.modelData.name || "?")
                            : String((root.kind === "window" ? card.modelData.className : card.modelData.name) || "?").charAt(0).toUpperCase()
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 44
                        font.weight: Font.Black
                        color: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.7)
                    }
                }
                Text {
                    anchors.top: frame.bottom
                    anchors.topMargin: 6
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: root.kind === "screen"
                        ? String(card.modelData.name) + (card.modelData.width ? " · " + card.modelData.width + "×" + card.modelData.height : "")
                        : (root.kind === "workspace" ? "Werkruimte " + String(card.modelData.name)
                            : String(card.modelData.title || card.modelData.className || "Venster"))
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    font.weight: card.current ? Font.DemiBold : Font.Normal
                    color: card.current ? mocha.text : mocha.subtext0
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.selectedIndex = card.index
                    onClicked: root.choose(card.modelData)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: "Een werkruimte delen laat ook vensters zien die je er later naartoe sleept."
                visible: root.kind === "workspace"
                font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0
            }
            Item { Layout.fillWidth: true; visible: root.kind !== "workspace" }
            Text { text: "Tab soort · Enter delen · Esc annuleren"; font.family: ThemeConfig.monoFont; font.pixelSize: 10; color: mocha.subtext0 }
        }
    }
}
