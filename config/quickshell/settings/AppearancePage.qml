import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// Uiterlijk: maak het actieve thema van jou met vijf knoppen. Aanpassingen
// komen niet in het thema zelf maar in een eigen bestand per thema
// (~/.local/state/kingstra/theme-overrides), zodat een update ze niet wist
// en "Origineel terug" altijd werkt. Alle losse variabelen blijven onder
// Geavanceerd.
Item {
    id: root
    signal pageRequested(string page)
    property real unit: 1.0

    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr/scripts"
    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")
    readonly property var themeTitles: ({matte: "Matte", mono: "Mono", "mono-accent": "Mono accent", neon: "Neon", organic: "Organic", paper: "Paper"})

    property string themeId: ""
    property var themeData: ({})
    property bool customized: false
    property bool busy: false
    property string errorText: ""

    // Wat de knoppen nu tonen: tijdens toepassen al de nieuwe keuze.
    property var pending: ({})

    readonly property var fontChoices: {
        let installed = Qt.fontFamilies();
        let wanted = ["Inter", "IBM Plex Sans", "Fira Sans", "Nunito", "Noto Sans", "Space Grotesk"];
        let out = [];
        for (let f of wanted) if (installed.indexOf(f) !== -1 && out.length < 4) out.push({id: f, title: f});
        let current = value("fonts", "ui_font", "");
        if (current !== "" && !out.some(o => o.id === current)) out.unshift({id: current, title: current});
        return out;
    }

    MatugenColors { id: pageColors }
    readonly property var c: pageColors

    function value(section, key, fallback) {
        let s = themeData[section];
        return s && s[key] !== undefined ? s[key] : fallback;
    }
    // Huidige stand per knop, uit de themawaarden.
    readonly property string accentNow: pending.accent !== undefined ? pending.accent : String(Math.min(3, Math.max(0, Number(value("matugen", "color_index", 0)) || 0)))
    readonly property string modeNow: pending.mode !== undefined ? pending.mode : String(value("matugen", "mode", "dark"))
    readonly property string roundNow: {
        if (pending.round !== undefined) return pending.round;
        let r = Number(value("appearance", "border_radius", 12));
        return r <= 7 ? "strak" : r <= 17 ? "zacht" : "rond";
    }
    readonly property string spaceNow: {
        if (pending.space !== undefined) return pending.space;
        let d = String(value("style_profile", "density", "comfortable"));
        return d === "compact" ? "compact" : d === "airy" ? "ruim" : "normaal";
    }
    readonly property string fontNow: pending.font !== undefined ? pending.font : String(value("fonts", "ui_font", ""))

    readonly property var roundValues: ({strak: [4, 8], zacht: [12, 16], rond: [22, 24]})
    readonly property var spaceValues: ({compact: [2, 6, "compact", 10], normaal: [5, 12, "comfortable", 14], ruim: [8, 20, "airy", 18]})

    // Sleutel/waarde-paren voor kingstra-theme-update per knop.
    function pairsFor(knob, choice) {
        if (knob === "accent") return ["matugen.color_index", choice];
        if (knob === "mode") return ["matugen.mode", choice];
        if (knob === "round") {
            let r = roundValues[choice];
            return ["appearance.border_radius", String(r[0]), "style_profile.widget_radius", String(r[1])];
        }
        if (knob === "space") {
            let v = spaceValues[choice];
            return ["appearance.gaps_in", String(v[0]), "appearance.gaps_out", String(v[1]),
                    "style_profile.density", v[2], "style_profile.panel_padding", String(v[3])];
        }
        if (knob === "font") return ["fonts.ui_font", choice];
        return [];
    }
    function nowFor(knob) {
        return knob === "accent" ? accentNow : knob === "mode" ? modeNow : knob === "round" ? roundNow : knob === "space" ? spaceNow : fontNow;
    }
    function quote(text) { return "'" + String(text).replace(/'/g, "'\\''") + "'"; }
    function pick(knob, choice, label) {
        if (busy || themeId === "" || nowFor(knob) === choice) return;
        let before = nowFor(knob);
        let next = Object.assign({}, pending);
        next[knob] = choice;
        pending = next;
        busy = true;
        errorText = "";
        let pairs = pairsFor(knob, choice);
        let undoPairs = pairsFor(knob, before).map(quote).join(" ");
        let undo = quote(scripts + "/theme-update-safe.sh") + " " + quote(themeId) + " " + undoPairs + " && kingstra theme " + quote(themeId);
        applyProc.feedbackTitle = label;
        applyProc.undo = undo;
        applyProc.command = ["bash", "-lc",
            "PATH=\"$HOME/.local/bin:$PATH\"; \"$1\" \"$2\" \"${@:3}\" && kingstra theme \"$2\" >/dev/null",
            "_", scripts + "/theme-update-safe.sh", themeId].concat(pairs);
        applyProc.running = true;
    }
    function resetTheme() {
        if (busy || themeId === "") return;
        busy = true;
        errorText = "";
        pending = ({});
        applyProc.feedbackTitle = "Origineel terug";
        applyProc.undo = "";
        applyProc.command = ["bash", "-lc",
            "PATH=\"$HOME/.local/bin:$PATH\"; \"$1\" --reset \"$2\" && kingstra theme \"$2\" >/dev/null",
            "_", scripts + "/theme-update-safe.sh", themeId];
        applyProc.running = true;
    }
    function reload() {
        if (themeId === "") return;
        readProc.command = [scripts + "/theme-read-safe.sh", "--json", configHome + "/kingstra/themes/" + themeId + ".toml"];
        readProc.running = true;
        customProc.running = true;
    }

    FileView {
        path: root.configHome + "/kingstra/state/theme.json"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: {
            try { root.themeId = String(JSON.parse(text()).name || ""); } catch (e) {}
            root.reload();
        }
    }
    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.themeData = JSON.parse(this.text); } catch (e) {}
                if (!applyProc.running) root.pending = ({});
            }
        }
    }
    Process {
        id: customProc
        command: ["test", "-s", root.stateHome + "/kingstra/theme-overrides/" + root.themeId + ".json"]
        onExited: (code) => root.customized = code === 0
    }
    Process {
        id: applyProc
        property string feedbackTitle: ""
        property string undo: ""
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim().split("\n").pop() }
        onExited: (code) => {
            root.busy = false;
            root.reload();
            if (code === 0 && feedbackTitle !== "") {
                let args = ["bash", root.scripts + "/feedback.sh"];
                if (undo !== "") args = args.concat(["--undo", undo]);
                Quickshell.execDetached(args.concat(["󰏘", feedbackTitle, "Toegepast op " + (root.themeTitles[root.themeId] || root.themeId)]));
            }
        }
    }

    component Note: Text {
        Layout.fillWidth: true
        color: root.c.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight + 24
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 16

            Text { text: "Uiterlijk"; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 24; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Note {
                    text: root.themeId !== "" ? "Je past " + (root.themeTitles[root.themeId] || root.themeId) + " aan. Ander thema of wallpaper kies je met Super+A."
                        : "Thema wordt geladen…"
                }
                SimpleChip {
                    colors: root.c
                    glyph: "󰏘"
                    label: "Sfeer openen"
                    onTriggered: Quickshell.execDetached(["bash", root.scripts + "/qs_manager.sh", "toggle", "bediening"])
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                SimpleCard {
                    colors: root.c
                    Layout.alignment: Qt.AlignTop
                    glyph: "󰏘"
                    heading: "Maak het van jou"
                    hint: root.busy ? "Wordt toegepast…" : "Elke keuze werkt meteen. Het thema zelf blijft heel."
                    SimpleChoice {
                        colors: root.c
                        label: "Accentkleur"
                        hint: "Elke keuze haalt een andere kleur uit je wallpaper."
                        options: [{id: "0", title: "Kleur 1"}, {id: "1", title: "Kleur 2"}, {id: "2", title: "Kleur 3"}, {id: "3", title: "Kleur 4"}]
                        current: root.accentNow
                        allowed: !root.busy
                        onPicked: (v) => root.pick("accent", v, "Accentkleur " + (Number(v) + 1))
                    }
                    SimpleChoice {
                        colors: root.c
                        label: "Licht of donker"
                        options: [{id: "dark", title: "Donker", glyph: "󰖔"}, {id: "light", title: "Licht", glyph: "󰖙"}]
                        current: root.modeNow
                        allowed: !root.busy
                        onPicked: (v) => root.pick("mode", v, v === "light" ? "Licht" : "Donker")
                    }
                    SimpleChoice {
                        colors: root.c
                        label: "Rondheid"
                        hint: "Hoeken van vensters, panelen en knoppen."
                        options: [{id: "strak", title: "Strak"}, {id: "zacht", title: "Zacht"}, {id: "rond", title: "Rond"}]
                        current: root.roundNow
                        allowed: !root.busy
                        onPicked: (v) => root.pick("round", v, "Rondheid: " + v)
                    }
                    SimpleChoice {
                        colors: root.c
                        label: "Ruimte"
                        hint: "Tussen vensters en binnen panelen."
                        options: [{id: "compact", title: "Compact"}, {id: "normaal", title: "Normaal"}, {id: "ruim", title: "Ruim"}]
                        current: root.spaceNow
                        allowed: !root.busy
                        onPicked: (v) => root.pick("space", v, "Ruimte: " + v)
                    }
                    SimpleChoice {
                        visible: root.fontChoices.length > 1
                        colors: root.c
                        label: "Lettertype"
                        options: root.fontChoices
                        current: root.fontNow
                        allowed: !root.busy
                        onPicked: (v) => root.pick("font", v, "Lettertype " + v)
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        SimpleChip {
                            colors: root.c
                            glyph: "󰑓"
                            label: root.customized ? "Origineel terug" : "Dit is het origineel"
                            allowed: root.customized && !root.busy
                            onTriggered: root.resetTheme()
                        }
                    }
                    Note { text: root.errorText; visible: text !== ""; color: root.c.red }
                }

                // Voorbeeld: een klein venster en een paneel met de gekozen
                // rondheid, ruimte en letter. Geeft vooraf een idee; het echte
                // resultaat zie je meteen na de klik.
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 280
                    Layout.preferredHeight: 300
                    visible: body.width > 760
                    readonly property var r: root.roundValues[root.roundNow] || [12, 16]
                    readonly property var g: root.spaceValues[root.spaceNow] || [5, 12, "comfortable", 14]
                    radius: 18
                    color: root.c.crust
                    border.width: 1
                    border.color: root.c.shellOutline
                    clip: true
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 12
                        text: "Voorbeeld"
                        color: root.c.subtext0
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                    }
                    Row {
                        id: previewWindows
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: 36 + parent.g[1] / 2
                        anchors.leftMargin: 12 + parent.g[1] / 2
                        anchors.rightMargin: 12 + parent.g[1] / 2
                        height: 150
                        spacing: parent.g[0] * 2
                        Repeater {
                            model: 2
                            Rectangle {
                                required property int index
                                width: (previewWindows.width - previewWindows.spacing) / 2
                                height: previewWindows.height
                                radius: previewWindows.parent.r[0]
                                color: root.c.base
                                border.width: 1
                                border.color: index === 0 ? root.c.primary : root.c.surface1
                                Behavior on radius { NumberAnimation { duration: ThemeConfig.duration(260); easing.type: Easing.OutCubic } }
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 6
                                    Text { text: index === 0 ? "Notities" : "Muziek"; color: root.c.text; font.family: root.fontNow || ThemeConfig.uiFont; font.pixelSize: 12; font.bold: true }
                                    Repeater {
                                        model: 3
                                        Rectangle { required property int index; width: parent.width * (0.9 - index * 0.2); height: 6; radius: 3; color: root.c.surface1 }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12 + parent.g[1] / 2
                        height: 64
                        radius: parent.r[1]
                        color: Qt.alpha(root.c.surface0, 0.9)
                        border.width: 1
                        border.color: root.c.shellOutline
                        Behavior on radius { NumberAnimation { duration: ThemeConfig.duration(260); easing.type: Easing.OutCubic } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Repeater {
                                model: ["Wi-Fi", "Geluid", "Licht"]
                                Rectangle {
                                    required property string modelData
                                    required property int index
                                    width: 64
                                    height: 32
                                    radius: Math.min(16, previewWindows.parent.r[1])
                                    color: index === 0 ? Qt.alpha(root.c.primary, 0.85) : root.c.shellRaisedFill
                                    Text { anchors.centerIn: parent; text: parent.modelData; color: index === 0 ? root.c.base : root.c.text; font.family: root.fontNow || ThemeConfig.uiFont; font.pixelSize: 11 }
                                }
                            }
                        }
                    }
                }
            }

            AdvancedSection {
                title: "Geavanceerd"
                icon: "󰒓"
                hint: "Kleurstijl en contrast, lettergroottes, vensters, strook en effecten"
                unit: root.unit
                Note { text: "Hier staat elke themavariabele los. Ook deze wijzigingen gaan in je eigen aanpassingen, dus Origineel terug haalt ze weer weg." }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    SimpleChip { colors: root.c; glyph: "󰏘"; label: "Kleurstijl en contrast…"; onTriggered: root.pageRequested("thema") }
                    SimpleChip { colors: root.c; glyph: "󰒓"; label: "Alle onderdelen…"; onTriggered: root.pageRequested("aanpassen") }
                }
            }
        }
    }
}
