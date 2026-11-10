import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."

// Vensterwisselaar (Super+Ctrl+Tab): een rij afgeronde kaartjes met een
// voorbeeld van elk open venster, meest recent eerst, over alle werkruimtes.
// Ctrl ingedrukt houden en Tab tikken gaat verder (Shift+Tab terug); Ctrl
// loslaten springt naar het gekozen venster. Ook: pijltjes, Enter, klikken
// en typen om te filteren. Geparkeerde vensters staan in Super+W.
// Hyprland vangt Super+Ctrl+Tab zelf af, ook als dit paneel open is; de
// sneltoets roept dan window-carousel.sh aan, die /tmp/kingstra-switcher-step
// aanraakt, en via TmpWatch schuift de keuze één plek op.
FocusScope {
    id: root

    MatugenColors { id: mocha }

    property var windows: []
    property string query: ""
    property int selectedIndex: 1
    property bool chosen: false
    readonly property string bridge: Quickshell.env("HOME") + "/.config/quickshell/shellsurface/window-switcher.sh"
    readonly property int cardW: 220
    readonly property int cardH: 150
    readonly property int preferredPanelWidth: 1000
    readonly property int preferredPanelHeight: cardH + 120

    readonly property var filteredWindows: {
        let needle = String(query || "").toLowerCase().trim();
        let open = windows.filter(win => !win.parked);
        if (needle === "") return open;
        return open.filter(win => (String(win.title || "") + " " + String(win.className || "")).toLowerCase().indexOf(needle) >= 0);
    }

    // Wayland-toplevel per Hyprland-adres, voor het live voorbeeld.
    function toplevelFor(address) {
        let list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            let t = list[i];
            if (t && t.HyprlandToplevel && ("0x" + t.HyprlandToplevel.address) === String(address)) return t;
        }
        return null;
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function choose(win) {
        if (!win || chosen) return;
        chosen = true;
        Quickshell.execDetached(["bash", "-c", "bash \"$0\" focus \"$1\" \"$2\"; bash \"$3\" close",
            bridge, String(win.address), String(win.workspace),
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh"]);
    }

    function move(delta) {
        let n = filteredWindows.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        carousel.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    onFilteredWindowsChanged: selectedIndex = Math.min(query === "" ? 1 : 0, Math.max(0, filteredWindows.length - 1))

    Component.onCompleted: {
        loadProcess.running = true;
        forceActiveFocus();
    }

    // Elke nieuwe inhoud (een tijdstempel) is één stap verder. De eerste
    // lezing onthoudt alleen wat er al stond.
    property string lastStep: ""
    property bool stepSeen: false
    FileView {
        id: stepFile
        path: "/tmp/kingstra-switcher-step"
        printErrors: false
        watchChanges: true
        preload: true
        onInternalTextChanged: {
            let t = String(__text || "").trim();
            if (root.stepSeen && t !== "" && t !== root.lastStep) root.move(1);
            root.lastStep = t;
            root.stepSeen = true;
        }
        onLoadFailed: root.stepSeen = true
    }
    Timer {
        interval: TmpWatch.pollInterval(100)
        running: true
        repeat: true
        onTriggered: stepFile.reload()
    }
    Connections {
        target: TmpWatch
        function onChanged(path) { if (path === "/tmp/kingstra-switcher-step") stepFile.reload(); }
    }

    Process {
        id: loadProcess
        command: ["bash", root.bridge, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    root.windows = Array.isArray(parsed) ? parsed : [];
                } catch (error) {
                    root.windows = [];
                }
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.move(event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.move(1); event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.move(-1); event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.choose(root.filteredWindows[root.selectedIndex]); event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
            root.closePanel(); event.accepted = true;
        } else if (event.key === Qt.Key_Backspace) {
            root.query = root.query.slice(0, -1); event.accepted = true;
        } else if (event.text !== "" && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
                   && event.text.charCodeAt(0) >= 32) {
            root.query += event.text; event.accepted = true;
        }
    }
    // Ctrl of Super loslaten kiest, zoals Alt+Tab elders, maar alleen zolang
    // er niet getypt wordt (dan kies je met Enter).
    Keys.onReleased: event => {
        let modifierKey = event.key === Qt.Key_Control || event.key === Qt.Key_Meta
            || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R;
        if (modifierKey && !event.isAutoRepeat && root.query === "" && root.filteredWindows.length > 0) {
            root.choose(root.filteredWindows[root.selectedIndex]);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text { text: "󰕰"; font.family: ThemeConfig.iconFont; font.pixelSize: 17; color: mocha.accent2 }
            Text { text: root.query === "" ? "Wisselen" : "Zoeken: " + root.query; font.family: ThemeConfig.displayFont; font.pixelSize: 16; font.weight: Font.Black; color: mocha.text }
            Item { Layout.fillWidth: true }
            Text { text: "Tab verder · Ctrl los = wisselen · typ om te zoeken · Esc"; font.family: ThemeConfig.monoFont; font.pixelSize: 10; color: mocha.subtext0 }
        }

        ListView {
            id: carousel
            Layout.fillWidth: true
            Layout.preferredHeight: root.cardH + 44
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: root.filteredWindows
            currentIndex: root.selectedIndex
            highlightMoveDuration: ThemeConfig.duration(180)
            preferredHighlightBegin: width / 2 - root.cardW / 2
            preferredHighlightEnd: width / 2 + root.cardW / 2
            highlightRangeMode: ListView.ApplyRange

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool current: root.selectedIndex === index
                readonly property var toplevel: root.toplevelFor(modelData.address)
                width: root.cardW
                height: root.cardH + 40
                scale: current ? 1.0 : 0.92
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
                        captureSource: card.toplevel
                        live: card.current
                        opacity: hasContent ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
                    }
                    // Zonder beeld (andere werkruimte): de beginletter van de app.
                    Text {
                        anchors.centerIn: parent
                        visible: !preview.hasContent
                        text: String(card.modelData.className || "?").charAt(0).toUpperCase()
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 44
                        font.weight: Font.Black
                        color: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.7)
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        width: wsText.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.78)
                        Text { id: wsText; anchors.centerIn: parent; text: String(card.modelData.workspace); font.family: ThemeConfig.monoFont; font.pixelSize: 10; font.weight: Font.Bold; color: mocha.text }
                    }
                }
                Text {
                    anchors.top: frame.bottom
                    anchors.topMargin: 6
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: String(card.modelData.title || card.modelData.className || "Zonder titel")
                    elide: Text.ElideRight
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

            Text {
                anchors.centerIn: parent
                visible: carousel.count === 0
                text: root.windows.length === 0 ? "Geen open vensters" : "Geen resultaten"
                font.family: ThemeConfig.uiFont; font.pixelSize: 12; color: mocha.subtext0
            }
        }
    }
}
