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

    // Wallpaperkiezer (Super+Ctrl+W): vaste keuzes. Wisselen tijdens het
    // kiezen (weergave, sorteren, filters) kan in de kiezer zelf.
    readonly property string pickerBackend: home + "/.config/quickshell/wallpaper/backend.py"
    readonly property var defaultHiddenSources: ["goodfon", "hdqwalls", "pixabay", "wallpaperscraft", "wallpaperswide", "wallpaperscom"]
    property var picker: ({})
    readonly property var hiddenSources: picker.hiddenSources !== undefined ? picker.hiddenSources : defaultHiddenSources
    property string pickerError: ""
    property var pickerQueue: []

    function setPicker(key, value) {
        let next = Object.assign({}, picker);
        if (key === "hiddenSources") {
            let hidden = hiddenSources.slice(), index = hidden.indexOf(value);
            if (index >= 0) hidden.splice(index, 1); else hidden.push(value);
            next.hiddenSources = hidden;
        } else next[key] = key === "backdrop" ? value === "true" : key === "hexRows" ? Number(value) : value;
        picker = next;
        pickerError = "";
        pickerQueue = pickerQueue.concat([[key, String(value)]]);
        runPickerQueue();
    }
    function runPickerQueue() {
        if (pickerProcess.running || !pickerQueue.length) return;
        let job = pickerQueue[0];
        pickerQueue = pickerQueue.slice(1);
        pickerProcess.command = ["python3", pickerBackend, "preferences", job[0], job[1]];
        pickerProcess.running = true;
    }

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
    FileView {
        id: pickerFile
        path: root.home + "/.config/kingstra/wallpaper-picker.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (pickerProcess.running || root.pickerQueue.length) return;
            try { root.picker = JSON.parse(text() || "{}"); } catch (e) {}
        }
    }
    Process {
        id: pickerProcess
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.pickerError = this.text.trim() }
        stdout: StdioCollector {
            onStreamFinished: {
                let match = this.text.match(/"event": "error", "message": "([^"]*)"/);
                if (match) root.pickerError = match[1];
            }
        }
        onExited: root.runPickerQueue()
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
            Note { text: "Hoe je desktop werkt. Thema en wallpaper kies je met Super+A; de wallpaperkiezer stel je hieronder in." }

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

            SimpleCard {
                colors: root.c
                glyph: "󰸉"
                heading: "Wallpapers"
                hint: "Vaste keuzes voor de wallpaperkiezer (Super+Ctrl+W). Geldt vanaf de volgende keer dat je hem opent."
                SimpleChoice {
                    colors: root.c
                    label: "Weergave bij openen"
                    hint: "In de kiezer kun je altijd even wisselen; de laatste keuze blijft bewaard."
                    options: [{id: "wall", title: "Raster"}, {id: "hex", title: "Hexagons"}, {id: "slices", title: "Slices"}, {id: "mosaic", title: "Mozaïek"}, {id: "coverflow", title: "Coverflow"}, {id: "orbit", title: "Orbit"}]
                    current: root.picker.mode || "hex"
                    onPicked: (value) => root.setPicker("mode", value)
                }
                SimpleChoice {
                    colors: root.c
                    label: "Sorteren"
                    options: [{id: "color", title: "Kleur"}, {id: "date", title: "Nieuwste"}, {id: "name", title: "Naam"}]
                    current: root.picker.sort || "color"
                    onPicked: (value) => root.setPicker("sort", value)
                }
                SimpleSwitch {
                    colors: root.c
                    label: "Sfeer achter de kaarten"
                    hint: "Een vage versie van de gekozen wallpaper als achtergrond van de kiezer."
                    checked: root.picker.backdrop !== false
                    onToggled: (on) => root.setPicker("backdrop", on ? "true" : "false")
                }
                SimpleSwitch {
                    colors: root.c
                    label: "Geen AI-beelden"
                    hint: "Verbergt wat de bron als AI markeert. Niet elke bron levert die labels."
                    checked: root.picker.excludeAi === true
                    onToggled: (on) => root.setPicker("excludeAi", on ? "true" : "false")
                }
                SimpleChoice {
                    colors: root.c
                    label: "Video's opslaan op"
                    hint: "Grotere of zwaardere video's worden bij opslaan omgezet; het origineel gaat naar de prullenbak. Elke video speelt op elk scherm apart, dus groter dan je scherm kost alleen rekenkracht."
                    options: [{id: "auto", title: "Mijn schermen"}, {id: "1080", title: "1080p"}, {id: "1440", title: "1440p"}, {id: "2160", title: "4K"}, {id: "0", title: "Origineel"}]
                    current: root.picker.videoHeight || "auto"
                    onPicked: (value) => root.setPicker("videoHeight", value)
                }
                SimpleChoice {
                    colors: root.c
                    label: "Beelden per seconde"
                    options: [{id: "30", title: "30"}, {id: "60", title: "60"}, {id: "0", title: "Origineel"}]
                    current: root.picker.videoFps || "30"
                    onPicked: (value) => root.setPicker("videoFps", value)
                }
                Note { text: "Bronnen in de kiezer"; color: root.c.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                Note { text: "Je collectie en Wallhaven staan er altijd. Uitgezette bronnen blijven werken; ze staan alleen niet meer als tab." }
                Flow {
                    Layout.fillWidth: true
                    spacing: 7
                    Repeater {
                        model: [{id: "moewalls", title: "MoeWalls (video)"}, {id: "pixabayvideo", title: "Pixabay video"}, {id: "nasa", title: "NASA"}, {id: "commons", title: "Commons"}, {id: "alphacoders", title: "Alpha Coders"}, {id: "backiee", title: "backiee"}, {id: "wallpaperscraft", title: "WallpapersCraft"}, {id: "wallpaperswide", title: "WallpapersWide"}, {id: "wallpaperscom", title: "Wallpapers.com"}, {id: "pixabay", title: "Pixabay foto's (max. 1280 px)"}, {id: "goodfon", title: "GoodFon"}, {id: "hdqwalls", title: "HDQwalls (link)"}]
                        delegate: SimpleChip {
                            required property var modelData
                            colors: root.c
                            label: modelData.title
                            glyph: chosen ? "󰄬" : ""
                            chosen: root.hiddenSources.indexOf(modelData.id) < 0
                            onTriggered: root.setPicker("hiddenSources", modelData.id)
                        }
                    }
                }
                AdvancedSection {
                    title: "Hexagons"
                    icon: "󰋙"
                    hint: "Aantal rijen in de hexagonweergave"
                    unit: root.unit
                    SimpleChoice {
                        colors: root.c
                        label: "Rijen"
                        options: [{id: "1", title: "1"}, {id: "2", title: "2"}, {id: "3", title: "3"}, {id: "4", title: "4"}, {id: "5", title: "5"}]
                        current: root.picker.hexRows ? String(root.picker.hexRows) : "2"
                        onPicked: (value) => root.setPicker("hexRows", value)
                    }
                }
                Note { text: root.pickerError; visible: text !== ""; color: root.c.red }
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
                Note { text: "Super+wiel scrolt binnen de werkruimte, Super+Shift+wiel wisselt van werkruimte, Super+Ctrl+linkermuis sleept vrij. Touchpad: drie vingers schuiven, knijpen zoomt. Aanraakscherm: twee vingers." }
                Note { text: root.werkvlakError; visible: text !== ""; color: root.c.red }
            }
        }
    }
}
