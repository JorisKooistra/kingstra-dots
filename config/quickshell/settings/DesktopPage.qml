import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../"

// Bureaublad: hoe je desktop werkt. Zijbalk, indeling, wat vanzelf gebeurt
// en de speler. Bovenaan alleen gewone keuzes; scrollen en vastklikken
// staan onder Geavanceerd. Per scherm iets anders? Schermen › Per scherm.
Item {
    id: root
    signal pageRequested(string page)
    property real unit: 1.0

    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr/scripts"
    readonly property string layoutHelper: scripts + "/workspace-layout.py"
    readonly property string werkvlakHelper: scripts + "/werkvlak-settings.py"
    readonly property int workspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property string screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property var profile: ScreenProfiles.profile(screenName)
    readonly property var modeData: ScreenProfiles.state.presets[profile.mode] || ({})
    readonly property var modules: profile.rail.modules !== undefined ? profile.rail.modules : (modeData.modules || [])
    readonly property bool autohide: profile.rail.autohide !== undefined ? profile.rail.autohide : modeData.bar_autohide === true
    readonly property var standNames: ({office: "Werken", media: "Kijken en luisteren", gaming: "Spelen"})
    readonly property string standName: standNames[profile.mode] || profile.mode

    property string currentLayout: ""
    property string layoutError: ""
    property var werkvlak: ({column_width: 1.0, snap: 0.2})
    property string werkvlakError: ""
    property var autoRules: ({ game: true, battery: true, share: true })
    property string autoGame: ""
    property bool autoBattery: false
    property bool autoShare: false
    property bool autoHasBattery: false

    MatugenColors { id: pageColors }
    readonly property var c: pageColors

    function setScreen(field, value) {
        if (!screenName) return;
        ScreenProfiles.action(["set", screenName, field, JSON.stringify(value)]);
    }
    function toggleModule(id) {
        let next = modules.slice(), index = next.indexOf(id);
        if (index >= 0) next.splice(index, 1); else next.push(id);
        setScreen("rail.modules", next);
    }
    function inspectLayout() {
        if (!workspace || inspectProcess.running || layoutProcess.running) return;
        inspectProcess.command = ["python3", layoutHelper, "inspect", String(workspace)];
        inspectProcess.running = true;
    }
    function applyLayout(preset) {
        if (!workspace || layoutProcess.running) return;
        layoutError = "";
        layoutProcess.command = ["python3", layoutHelper, "apply", preset, String(workspace)];
        layoutProcess.running = true;
    }
    function acceptLayout(text) {
        try {
            let preset = JSON.parse(text).preset || "";
            if (preset !== currentLayout) currentLayout = preset;
        } catch (e) {}
    }
    function setWerkvlak(key, value) {
        if (werkvlakProcess.running) return;
        let next = Object.assign({}, werkvlak);
        next[key] = value;
        werkvlak = next;
        werkvlakError = "";
        werkvlakProcess.command = ["python3", werkvlakHelper, "set", key, String(value)];
        werkvlakProcess.running = true;
    }
    function acceptWerkvlak(text) {
        try {
            let data = JSON.parse(text);
            if (data && data.column_width !== undefined) werkvlak = data;
        } catch (e) {}
    }
    function near(a, b) { return Math.abs(Number(a) - Number(b)) < 0.01; }
    function setAutoRule(rule, on) {
        let next = Object.assign({}, autoRules);
        next[rule] = on;
        autoRules = next;
        Quickshell.execDetached([home + "/.local/bin/kingstra-auto-mode", "set", rule, on ? "on" : "off"]);
    }

    onWorkspaceChanged: { currentLayout = ""; inspectLayout(); }
    Component.onCompleted: { inspectLayout(); werkvlakGet.running = true; }
    Timer { interval: 2000; repeat: true; running: root.visible; onTriggered: root.inspectLayout() }

    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kingstra-auto-mode.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                let d = JSON.parse(text() || "{}");
                if (d.rules) root.autoRules = d.rules;
                root.autoGame = String(d.game || "");
                root.autoBattery = d.battery === true;
                root.autoShare = d.share === true;
                root.autoHasBattery = d.hasBattery === true;
            } catch (e) {}
        }
    }
    Process {
        id: inspectProcess
        stdout: StdioCollector { onStreamFinished: root.acceptLayout(this.text) }
    }
    Process {
        id: layoutProcess
        stdout: StdioCollector {
            onStreamFinished: {
                root.acceptLayout(this.text);
                if (this.text.trim()) root.layoutError = "";
            }
        }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.layoutError = this.text.trim() }
    }
    Process {
        id: werkvlakGet
        command: ["python3", root.werkvlakHelper, "get"]
        stdout: StdioCollector { onStreamFinished: root.acceptWerkvlak(this.text) }
    }
    Process {
        id: werkvlakProcess
        stdout: StdioCollector { onStreamFinished: root.acceptWerkvlak(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.werkvlakError = this.text.trim() }
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

            Text { text: "Bureaublad"; color: root.c.text; font.family: ThemeConfig.uiFont; font.pixelSize: 24; font.bold: true }
            Note { text: "Hoe je desktop werkt. Thema en wallpaper kies je met Super+A." }

            SimpleCard {
                colors: root.c
                glyph: "󰕮"
                heading: "Zijbalk"
                hint: root.screenName ? "Geldt voor " + root.screenName + " in de stand " + root.standName + "." : "Geen scherm gevonden."
                SimpleSwitch {
                    colors: root.c
                    label: "Verbergen als je hem niet gebruikt"
                    hint: "Raak de rand van het scherm aan om hem terug te halen."
                    checked: root.autohide
                    allowed: !!root.screenName && !ScreenProfiles.busy
                    blockedReason: "Even geduld, de vorige wijziging wordt nog bewaard."
                    onToggled: (on) => root.setScreen("rail.autohide", on)
                }
                Note { text: "Wat staat erin"; color: root.c.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: [{id: "workspaces", title: "Werkruimtes"}, {id: "clock", title: "Klok"}, {id: "volume", title: "Geluid"}, {id: "network", title: "Netwerk"}, {id: "bluetooth", title: "Bluetooth"}, {id: "battery", title: "Batterij"}, {id: "notifications", title: "Meldingen"}, {id: "media_controls", title: "Media"}, {id: "updates", title: "Updates"}, {id: "cpu_temp", title: "Systeem"}]
                        delegate: SimpleChip {
                            required property var modelData
                            colors: root.c
                            label: modelData.title
                            glyph: chosen ? "󰄬" : ""
                            chosen: root.modules.indexOf(modelData.id) >= 0
                            allowed: !!root.screenName && !ScreenProfiles.busy
                            onTriggered: root.toggleModule(modelData.id)
                        }
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    SimpleChip { colors: root.c; glyph: "󰕮"; label: "Volgorde, tweede zijbalk en eigen apps…"; onTriggered: root.pageRequested("rail") }
                    SimpleChip { colors: root.c; glyph: "󰍹"; label: "Per scherm anders…"; onTriggered: root.pageRequested("perscherm") }
                    SimpleChip { colors: root.c; glyph: "󰑓"; label: "Standaard herstellen"; allowed: !!root.screenName && !ScreenProfiles.busy; onTriggered: ScreenProfiles.action(["reset", root.screenName]) }
                }
            }

            SimpleCard {
                colors: root.c
                glyph: "󰕰"
                heading: "Indeling van werkruimte " + root.workspace
                hint: "Tegelen zet vensters naast elkaar. De scrollstrook schuift ze als kolommen. Ruimtelijk laat je ze vrij neerzetten."
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: [{id: "tegels", title: "Tegelen", glyph: "󰕴"}, {id: "scrollen", title: "Scrollstrook", glyph: "󰁔"}, {id: "ruimtelijk", title: "Ruimtelijk", glyph: "󰊢"}, {id: "50-50", title: "50 / 50", glyph: "󰕭"}, {id: "70-30", title: "70 / 30", glyph: "󰕬"}, {id: "focus", title: "Eén tegelijk", glyph: "󰊓"}]
                        delegate: SimpleChip {
                            required property var modelData
                            colors: root.c
                            glyph: modelData.glyph
                            label: modelData.title
                            chosen: root.currentLayout === modelData.id
                            allowed: root.workspace > 0 && !layoutProcess.running
                            onTriggered: root.applyLayout(modelData.id)
                        }
                    }
                }
                Note { text: root.layoutError; visible: text !== ""; color: root.c.red }
            }

            SimpleCard {
                colors: root.c
                glyph: "󰁪"
                heading: "Vanzelf"
                hint: root.autoGame !== "" ? "Nu: Spelen staat aan voor " + root.autoGame + "."
                    : root.autoShare ? "Nu: je deelt je scherm, meldingen zijn stil."
                    : root.autoBattery ? "Nu: zuinig op batterij."
                    : "Gaat vanzelf aan en zet alles terug zodra de aanleiding weg is."
                SimpleSwitch {
                    colors: root.c
                    label: "Naar Spelen als een spel start"
                    hint: "Effecten uit en niet storen aan; terug naar je stand als het spel sluit."
                    checked: root.autoRules.game !== false
                    onToggled: (on) => root.setAutoRule("game", on)
                }
                SimpleSwitch {
                    visible: root.autoHasBattery
                    colors: root.c
                    label: "Zuinig op batterij"
                    hint: "Energiebesparing en minder effecten zolang de stekker eruit is."
                    checked: root.autoRules.battery !== false
                    onToggled: (on) => root.setAutoRule("battery", on)
                }
                SimpleSwitch {
                    colors: root.c
                    label: "Niet storen als je je scherm deelt"
                    hint: "In Teams, de browser of een opname. Meldingen komen daarna gewoon binnen."
                    checked: root.autoRules.share !== false
                    onToggled: (on) => root.setAutoRule("share", on)
                }
            }

            SimpleCard {
                colors: root.c
                glyph: "󰝚"
                heading: "Speler op het bureaublad"
                hint: "Klik op de speler voor de grote weergave. Geldt voor dit thema."
                SimpleChoice {
                    colors: root.c
                    options: [{id: "theme", title: "Bij thema"}, {id: "vinyl", title: "Plaat"}, {id: "cassette", title: "Cassette"}, {id: "discman", title: "Discman"}, {id: "cover", title: "Hoes"}]
                    current: PlayerChoice.current !== "" ? PlayerChoice.current : "theme"
                    onPicked: (value) => PlayerChoice.set(value)
                }
            }

            AdvancedSection {
                title: "Geavanceerd"
                icon: "󰒓"
                hint: "Breedte op de scrollstrook, vastklikken na slepen en gebaren"
                unit: root.unit
                SimpleChoice {
                    colors: root.c
                    label: "Breedte van een nieuw venster op de scrollstrook"
                    options: [{id: "1", title: "Heel"}, {id: "0.667", title: "⅔"}, {id: "0.5", title: "½"}, {id: "0.333", title: "⅓"}]
                    current: {
                        for (let v of ["1", "0.667", "0.5", "0.333"])
                            if (root.near(root.werkvlak.column_width, v)) return v;
                        return "";
                    }
                    allowed: !werkvlakProcess.running
                    onPicked: (value) => root.setWerkvlak("column_width", Number(value))
                }
                SimpleChoice {
                    colors: root.c
                    label: "Vastklikken na slepen"
                    hint: "Hoe sterk een gesleept venster naar een vak of rand trekt."
                    options: [{id: "0", title: "Nooit"}, {id: "0.2", title: "Licht"}, {id: "0.32", title: "Middel"}, {id: "0.42", title: "Sterk"}]
                    current: {
                        let v = Number(root.werkvlak.snap);
                        return v < 0.01 ? "0" : v < 0.27 ? "0.2" : v < 0.37 ? "0.32" : "0.42";
                    }
                    allowed: !werkvlakProcess.running
                    onPicked: (value) => root.setWerkvlak("snap", Number(value))
                }
                Note { text: "Super+wiel scrolt binnen de werkruimte, Super+Shift+wiel wisselt van werkruimte, Super+Ctrl+linkermuis sleept vrij. Touchpad: vier vingers schuiven, knijpen zoomt. Aanraakscherm: twee vingers." }
                Note { text: root.werkvlakError; visible: text !== ""; color: root.c.red }
            }
        }
    }
}
