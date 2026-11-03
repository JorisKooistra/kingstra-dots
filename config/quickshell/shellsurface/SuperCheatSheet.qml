import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Spiekbriefje: verschijnt als je Super even vasthoudt zonder iets anders te
// doen, en verdwijnt bij loslaten. Hyprland (lua/super-hold.lua) bepaalt
// wanneer; dit leest alleen /tmp/kingstra-superhold ("<n> <tijd> show DP-1"
// of "<n> <tijd> hide"). Volledig doorklikbaar: het staat niet in de
// input-mask en pakt nooit toetsenbordfocus. Super+F1 toont alles.
Item {
    id: root

    required property var shellWindow
    required property var mocha

    property bool shown: false
    property bool primed: false
    property string lastLine: ""

    readonly property var groups: [
        {title: "Openen", glyph: "󰏌", rows: [
            ["Enter", "Terminal"], ["Ctrl+Enter", "Starter"], ["E", "Bestanden"], ["B", "Browser"],
            ["V", "Klembord"], [".", "Emoji"], ["H vasthouden", "Dicteren"]]},
        {title: "Vensters", glyph: "󰖯", rows: [
            ["Q", "Sluiten"], ["F", "Volledig scherm"], ["T", "Zwevend"], ["Pijlen", "Focus"],
            ["Shift+pijlen", "Verplaatsen"], ["1 … 9", "Werkruimte"], ["Tab", "Overzicht"],
            ["W", "Alle vensters"], ["Z", "Indeling"], ["−", "Parkeren"]]},
        {title: "Shell", glyph: "󰕮", rows: [
            ["A", "Sfeer"], ["N", "Meldingen"], ["Ctrl+I", "Instellingen"], ["Ctrl+Space", "Menu"],
            ["Ctrl+L", "Vergrendelen"], ["Ctrl+⌫", "Afsluiten"], ["F1", "Alle sneltoetsen"]]},
        // Het ruimtelijk werkvlak: touchpad en muis naast elkaar, zodat de
        // gebaren te vinden zijn zonder de documentatie te lezen.
        {title: "Werkvlak", glyph: "󰕰", rows: [
            ["2 vingers", "Meeschuiven"], ["Wiel", "Plek verder"], ["Ctrl+wiel", "Zoomen"],
            ["Ctrl+slepen", "Vrij schuiven"], ["Shift+wiel", "Werkruimte"]],
         note: "Zonder Super: knijpen zoomt,\nvier vingers schuiven,\ndrie vingers wisselen werkruimte."}
    ]

    anchors.fill: parent
    z: 60
    opacity: shown ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }

    function apply(raw) {
        let line = String(raw || "").trim();
        if (line === "" || line === lastLine) return;
        lastLine = line;
        let parts = line.split(/\s+/);
        // Na een herstart van de shell nooit een oud "show" naspelen.
        if (!primed) { primed = true; if (parts[2] === "show") return; }
        if (parts[2] === "show") {
            let name = parts.length > 3 ? parts[3] : "";
            let mine = shellWindow && shellWindow.screen ? shellWindow.screen.name : "";
            shown = name === "" || name === mine;
            if (shown) safety.restart();
        } else {
            shown = false;
        }
    }

    FileView {
        id: stateFile
        path: "/tmp/kingstra-superhold"
        printErrors: false
        watchChanges: true
        preload: true
        onInternalTextChanged: root.apply(__text)
    }
    // FileView mist soms een schrijfactie; alleen kort nalezen.
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: stateFile.reload()
    }
    // Mocht een loslaat-gebeurtenis zoekraken (bv. vergrendelscherm): na
    // twintig seconden ruimt het briefje zichzelf op.
    Timer { id: safety; interval: 20000; onTriggered: root.shown = false }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, layout.implicitWidth + 56)
        height: layout.implicitHeight + 52
        radius: Math.max(18, ThemeConfig.styleWidgetRadius + 6)
        color: Qt.rgba(root.mocha.surface0.r, root.mocha.surface0.g, root.mocha.surface0.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.38)
        scale: root.shown ? 1.0 : 0.96
        Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("medium"); easing.type: ThemeConfig.easingToken("emphasized") } }

        ColumnLayout {
            id: layout
            anchors.centerIn: parent
            spacing: 16

            RowLayout {
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 11
                    color: Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.16)
                    Text { anchors.centerIn: parent; text: "󰌌"; font.family: ThemeConfig.iconFont; font.pixelSize: 18; color: root.mocha.primary }
                }
                ColumnLayout {
                    spacing: 1
                    Text { text: "Super +"; font.family: ThemeConfig.displayFont; font.pixelSize: 17; font.weight: Font.Black; color: root.mocha.text }
                    Text { text: "Super+Shift doet het meteen, Super+Ctrl laat je kiezen. Laat Super los om te sluiten."; font.family: ThemeConfig.uiFont; font.pixelSize: 11; color: root.mocha.subtext0 }
                }
            }

            RowLayout {
                spacing: 28
                Repeater {
                    model: root.groups
                    delegate: ColumnLayout {
                        id: group
                        required property var modelData
                        Layout.alignment: Qt.AlignTop
                        spacing: 6
                        RowLayout {
                            spacing: 6
                            Text { text: group.modelData.glyph; font.family: ThemeConfig.iconFont; font.pixelSize: 13; color: root.mocha.primary }
                            Text { text: group.modelData.title; font.family: ThemeConfig.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.mocha.subtext0 }
                        }
                        Repeater {
                            model: group.modelData.rows
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 10
                                Rectangle {
                                    Layout.preferredWidth: Math.max(104, keyText.implicitWidth + 18)
                                    Layout.preferredHeight: 24
                                    radius: 8
                                    color: Qt.rgba(root.mocha.surface1.r, root.mocha.surface1.g, root.mocha.surface1.b, 0.85)
                                    border.width: 1
                                    border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.10)
                                    Text {
                                        id: keyText
                                        anchors.centerIn: parent
                                        text: modelData[0]
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: root.mocha.text
                                    }
                                }
                                Text {
                                    Layout.preferredWidth: 118
                                    text: modelData[1]
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 12
                                    color: root.mocha.text
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        Text {
                            visible: !!group.modelData.note
                            Layout.topMargin: 4
                            Layout.maximumWidth: 232
                            text: group.modelData.note || ""
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: root.mocha.subtext0
                            wrapMode: Text.WordWrap
                            lineHeight: 1.15
                        }
                    }
                }
            }
        }
    }
}
