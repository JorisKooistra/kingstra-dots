import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../"

// Sfeer (Super+A): drie rijen, verder niets. Thema, wallpaper en "wat ga je
// doen" (de stand van de hele desktop, plus zen). Een klik past het meteen
// toe; het eiland biedt daarna "Ongedaan maken".
//
// Wat hier vroeger ook stond, heeft een vaste plek in Instellingen gekregen:
// zijbalk, indeling, scrollen, vanzelf en speler onder Bureaublad, per scherm
// onder Schermen, energie in Snelle instellingen (en Systeem).
//
// Toetsen: pijltjes of Tab lopen door de rij, omhoog/omlaag wisselt van rij,
// 1–3 springt naar een rij, Enter of spatie kiest, Esc sluit.
Item {
    id: overlay
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    MatugenColors { id: overlayColors }
    readonly property var c: overlayColors

    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr/scripts"
    readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")

    readonly property var themes: [
        {id: "matte", title: "Matte", preview: "matte"},
        {id: "mono", title: "Mono", preview: "mono"},
        {id: "mono-accent", title: "Mono accent", preview: "mono"},
        {id: "neon", title: "Neon", preview: "neon"},
        {id: "organic", title: "Organic", preview: "organic"},
        {id: "paper", title: "Paper", preview: "paper"}
    ]
    // Stand van de hele desktop, in gewone woorden. Zen is een schakelaar
    // bovenop de stand.
    readonly property var activities: [
        {id: "office", title: "Werken", detail: "Rustig, alles op zijn plek", glyph: "󰈙"},
        {id: "media", title: "Kijken en luisteren", detail: "Speler groot, meldingen zacht", glyph: "󰝚"},
        {id: "gaming", title: "Spelen", detail: "Effecten uit, niet storen aan", glyph: "󰊴"},
        {id: "zen", title: "Zen", detail: "Alleen het venster waar je in werkt", glyph: "󰚀"}
    ]

    property string modeName: ""
    property string themeName: ""
    property string pendingMode: ""
    property string pendingTheme: ""
    property string currentWallpaper: ""
    property var wallpapers: []
    property var customized: []
    property bool zenOn: false
    property string autoGame: ""
    property bool shown: false

    // Toetsenbordfocus: rij 0 thema, 1 wallpaper, 2 wat ga je doen.
    property int row: 0
    property var cursor: [0, 0, 0]
    readonly property var rowCounts: [themes.length + 1, wallpapers.length + 2, activities.length]
    function setCursor(r, i) {
        let next = cursor.slice();
        next[r] = Math.max(0, Math.min(rowCounts[r] - 1, i));
        cursor = next;
    }

    function kingstra(args) {
        return ["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra " + args];
    }
    function feedback(icon, title, detail, undo) {
        Quickshell.execDetached(["bash", scripts + "/feedback.sh", "--undo", undo, icon, title, detail]);
    }
    function readName(text) {
        try { return String(JSON.parse(text).name || ""); } catch (e) { return ""; }
    }
    function titleOf(list, id) {
        for (let item of list) if (item.id === id) return item.title;
        return id;
    }
    function close() {
        Quickshell.execDetached(["bash", scripts + "/qs_manager.sh", "close"]);
    }
    // Eerst de overlay dicht, dan pas de grote kiezer of Instellingen: die
    // willen allebei het toetsenbord.
    function closeThen(command) {
        Quickshell.execDetached(["bash", "-c", "\"$1\" close; sleep 0.2; shift; exec \"$@\"", "_", scripts + "/qs_manager.sh"].concat(command));
    }
    function openSettings(page) {
        closeThen(["bash", scripts + "/qs_manager.sh", "open", "settings", page]);
    }
    function setTheme(name) {
        if (name === themeName || pendingTheme !== "") return;
        let before = themeName;
        pendingTheme = name;
        pendingTimer.restart();
        Quickshell.execDetached(kingstra("theme " + name));
        if (before !== "")
            feedback("󰏘", "Thema " + titleOf(themes, name), "Was " + titleOf(themes, before), "kingstra theme " + before);
    }
    function setMode(name) {
        if (name === modeName || pendingMode !== "") return;
        let before = modeName;
        pendingMode = name;
        pendingTimer.restart();
        Quickshell.execDetached(kingstra("mode " + name));
        if (before !== "")
            feedback("󰾅", titleOf(activities, name), "Was " + titleOf(activities, before), "kingstra mode " + before);
    }
    function toggleZen() {
        zenOn = !zenOn;
        Quickshell.execDetached(["bash", scripts + "/zen.sh", "toggle"]);
    }
    function setWallpaper(path) {
        if (path === currentWallpaper) return;
        let before = currentWallpaper;
        currentWallpaper = path;
        Quickshell.execDetached(["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra wallpaper set \"$1\"", "_", path]);
        if (before !== "")
            feedback("󰸉", "Nieuwe wallpaper", path.split("/").pop(), "kingstra wallpaper set '" + before.replace(/'/g, "'\\''") + "'");
    }
    function randomWallpaper() {
        Quickshell.execDetached(["bash", scripts + "/wallpaper-random-safe.sh"]);
    }
    function allWallpapers() {
        closeThen(["bash", scripts + "/wallpaper-picker-safe.sh"]);
    }
    function activate(r, i) {
        row = r;
        setCursor(r, i);
        if (r === 0) {
            if (i < themes.length) setTheme(themes[i].id);
            else openSettings("uiterlijk");
        } else if (r === 1) {
            if (i === 0) randomWallpaper();
            else if (i <= wallpapers.length) setWallpaper(wallpapers[i - 1]);
            else allWallpapers();
        } else {
            let a = activities[i];
            if (a.id === "zen") toggleZen(); else setMode(a.id);
        }
    }
    function fileUrl(path) { return path ? "file://" + encodeURI(path) : ""; }

    Component.onCompleted: {
        wallpaperList.running = true;
        overridesList.running = true;
        zenProbe.running = true;
        overlay.forceActiveFocus();
        revealTimer.start();
    }
    Timer { id: revealTimer; interval: 30; onTriggered: overlay.shown = true }
    // Een thema- of modewissel duurt even; de keuze knippert niet terug.
    Timer { id: pendingTimer; interval: 20000; onTriggered: { overlay.pendingMode = ""; overlay.pendingTheme = ""; } }
    Timer { interval: 1500; repeat: true; running: overlay.visible; onTriggered: if (!zenProbe.running) zenProbe.running = true }

    FileView {
        path: overlay.home + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: { overlay.modeName = overlay.readName(text()); if (overlay.modeName === overlay.pendingMode) overlay.pendingMode = ""; }
    }
    FileView {
        path: overlay.home + "/.config/kingstra/state/theme.json"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: {
            overlay.themeName = overlay.readName(text());
            if (overlay.themeName === overlay.pendingTheme) overlay.pendingTheme = "";
            if (!overridesList.running) overridesList.running = true;
        }
    }
    FileView {
        path: overlay.home + "/.cache/kingstra/last-image-wallpaper"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: overlay.currentWallpaper = text().trim()
    }
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kingstra-auto-mode.json"
        watchChanges: true
        preload: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { overlay.autoGame = String(JSON.parse(text() || "{}").game || ""); } catch (e) {}
        }
    }

    Process {
        id: zenProbe
        command: ["bash", "-c", "[ -f \"${XDG_STATE_HOME:-$HOME/.local/state}/kingstra/zen.json\" ] && echo on || echo off"]
        stdout: StdioCollector { onStreamFinished: overlay.zenOn = this.text.trim() === "on" }
    }
    // Thema's met eigen aanpassingen (Instellingen › Uiterlijk) krijgen een stip.
    Process {
        id: overridesList
        command: ["bash", "-c", "ls \"$1\" 2>/dev/null | sed -n 's/\\.json$//p'", "_", overlay.stateHome + "/kingstra/theme-overrides"]
        stdout: StdioCollector { onStreamFinished: overlay.customized = this.text.split("\n").filter(line => line !== "") }
    }
    // Zelfde map als kingstra-wallpaper: skwd-wall-config, anders ~/Pictures/Wallpapers.
    Process {
        id: wallpaperList
        command: ["bash", "-c",
            "cfg=\"${XDG_CONFIG_HOME:-$HOME/.config}/skwd-wall/config.json\"; " +
            "dir=\"${KINGSTRA_WALLPAPER_DIR:-}\"; " +
            "[ -z \"$dir\" ] && [ -r \"$cfg\" ] && dir=$(jq -r '.paths.wallpaper // \"\"' \"$cfg\" 2>/dev/null); " +
            "[ -z \"$dir\" ] && dir=\"$HOME/Pictures/Wallpapers\"; " +
            "dir=\"${dir/#\\~/$HOME}\"; [ -d \"$dir\" ] || exit 0; " +
            "find -L \"$dir\" -maxdepth 2 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) " +
            "-printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -n 24 | cut -d' ' -f2-"]
        stdout: StdioCollector {
            onStreamFinished: overlay.wallpapers = this.text.split("\n").filter(line => line.trim() !== "")
        }
    }

    Keys.onPressed: (event) => {
        let r = overlay.row, i = overlay.cursor[r];
        if (event.key === Qt.Key_Escape) { overlay.close(); }
        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) { overlay.setCursor(r, i - 1); }
        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) { overlay.setCursor(r, i + 1); }
        else if (event.key === Qt.Key_Up) { overlay.row = Math.max(0, r - 1); }
        else if (event.key === Qt.Key_Down) { overlay.row = Math.min(2, r + 1); }
        else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_3) { overlay.row = event.key - Qt.Key_1; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { overlay.activate(r, i); }
        else return;
        event.accepted = true;
    }

    // ── Bouwstenen ──────────────────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string glyph: ""
        signal triggered()
        implicitHeight: overlay.s(34)
        implicitWidth: chipRow.implicitWidth + overlay.s(28)
        radius: height / 2
        scale: chipMouse.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
        color: chipMouse.containsMouse ? overlay.c.shellHoverFill : overlay.c.shellRaisedFill
        border.width: 1
        border.color: overlay.c.shellOutline
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: overlay.s(7)
            Text {
                visible: chip.glyph !== ""
                text: chip.glyph
                color: overlay.c.subtext1
                font.family: ThemeConfig.iconFont
                font.pixelSize: overlay.s(14)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.label
                color: overlay.c.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: overlay.s(12)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.triggered()
        }
    }

    // Eén rij: kop met nummer en uitleg, daaronder een horizontale strook.
    // Schuift met een kleine vertraging per rij binnen.
    component Strip: ColumnLayout {
        id: strip
        property int order: 0
        property string label: ""
        property string hint: ""
        default property alias content: stripBody.data
        readonly property bool active: overlay.row === order
        Layout.fillWidth: true
        spacing: overlay.s(10)
        opacity: overlay.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(360 + strip.order * 90); easing.type: Easing.OutCubic } }
        transform: Translate {
            y: overlay.shown ? 0 : overlay.s(24)
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(500 + strip.order * 90); easing.type: Easing.OutExpo } }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: overlay.s(10)
            Rectangle {
                Layout.preferredWidth: overlay.s(24)
                Layout.preferredHeight: overlay.s(24)
                radius: width / 2
                color: strip.active ? overlay.c.primary : overlay.c.shellRaisedFill
                border.width: 1
                border.color: strip.active ? overlay.c.primary : overlay.c.shellOutline
                Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                Text {
                    anchors.centerIn: parent
                    text: String(strip.order + 1)
                    color: strip.active ? overlay.c.base : overlay.c.subtext0
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: overlay.s(11)
                    font.bold: true
                }
            }
            Text {
                text: strip.label
                color: overlay.c.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: overlay.s(15)
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: strip.hint
                color: overlay.c.subtext0
                font.family: ThemeConfig.uiFont
                font.pixelSize: overlay.s(11)
                elide: Text.ElideRight
            }
        }
        Item {
            id: stripBody
            Layout.fillWidth: true
            Layout.preferredHeight: childrenRect.height
        }
    }

    // Tegel met een gladde focus- en keuzerand.
    component Tile: Item {
        id: tile
        property bool chosen: false
        property bool busy: false
        property bool focused: false
        property string label: ""
        property string sublabel: ""
        property string glyph: ""
        property string image: ""
        property bool dot: false
        property real frameHeight: overlay.s(96)
        signal triggered()
        height: frame.height + (label !== "" && sublabel === "" ? overlay.s(26) : 0)
        scale: tileMouse.pressed ? 0.96 : tileMouse.containsMouse || focused ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(170); easing.type: Easing.OutQuart } }

        ClippingRectangle {
            id: frame
            width: parent.width
            height: tile.frameHeight
            radius: overlay.s(16)
            color: tile.chosen ? Qt.alpha(overlay.c.primary, 0.18) : tileMouse.containsMouse ? overlay.c.shellHoverFill : Qt.alpha(overlay.c.surface1, 0.4)
            border.width: tile.chosen || tile.busy || tile.focused ? 2 : 1
            border.color: tile.chosen || tile.busy ? overlay.c.primary : tile.focused ? Qt.alpha(overlay.c.primary, 0.6) : overlay.c.shellOutline
            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(180) } }
            Image {
                anchors.fill: parent
                visible: tile.image !== ""
                source: tile.image
                sourceSize.width: 320
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                opacity: tile.busy ? 0.55 : 1
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
            }
            // Tegel zonder plaatje: icoon, titel en één regel uitleg.
            ColumnLayout {
                visible: tile.image === ""
                anchors.fill: parent
                anchors.margins: overlay.s(14)
                spacing: overlay.s(4)
                Text {
                    text: tile.glyph
                    color: tile.chosen ? overlay.c.primary : overlay.c.subtext1
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: overlay.s(tile.sublabel !== "" ? 24 : 22)
                    Layout.alignment: tile.sublabel !== "" ? Qt.AlignLeft : Qt.AlignHCenter
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                }
                Item { Layout.fillHeight: true }
                Text {
                    visible: tile.sublabel !== ""
                    Layout.fillWidth: true
                    text: tile.busy ? tile.label + "  …" : tile.label
                    color: overlay.c.text
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: overlay.s(14)
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    visible: tile.sublabel !== ""
                    Layout.fillWidth: true
                    text: tile.sublabel
                    color: overlay.c.subtext0
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: overlay.s(11)
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            Rectangle {
                visible: tile.dot
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: overlay.s(8)
                width: overlay.s(10)
                height: width
                radius: width / 2
                color: overlay.c.primary
                border.width: 2
                border.color: overlay.c.mantle
            }
        }
        Text {
            visible: tile.label !== "" && tile.sublabel === ""
            anchors.top: frame.bottom
            anchors.topMargin: overlay.s(6)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: tile.busy ? tile.label + "  …" : tile.label
            color: tile.chosen ? overlay.c.primary : overlay.c.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: overlay.s(12)
            font.bold: tile.chosen
            elide: Text.ElideRight
        }
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.triggered()
        }
    }

    // ── Paneel ──────────────────────────────────────────────────────────
    Rectangle {
        id: panel
        anchors.fill: parent
        radius: overlay.s(26)
        color: Qt.rgba(overlay.c.mantle.r, overlay.c.mantle.g, overlay.c.mantle.b, 0.94)
        border.width: 1
        border.color: Qt.rgba(overlay.c.surface2.r, overlay.c.surface2.g, overlay.c.surface2.b, 0.7)
        scale: overlay.shown ? 1.0 : 0.985
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(420); easing.type: Easing.OutBack } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(300) } }

        // Klikken naast een knop houdt de focus in de overlay (Esc blijft werken).
        MouseArea { anchors.fill: parent; onClicked: overlay.forceActiveFocus() }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: overlay.s(28)
            spacing: overlay.s(24)

            // Kop
            RowLayout {
                Layout.fillWidth: true
                spacing: overlay.s(12)
                opacity: overlay.shown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(300); easing.type: Easing.OutCubic } }
                Rectangle {
                    Layout.preferredWidth: overlay.s(42)
                    Layout.preferredHeight: overlay.s(42)
                    radius: width / 2
                    color: Qt.alpha(overlay.c.primary, 0.18)
                    Text {
                        anchors.centerIn: parent
                        text: "󰏘"
                        color: overlay.c.primary
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: overlay.s(20)
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Sfeer"
                        color: overlay.c.text
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: overlay.s(22)
                        font.bold: true
                    }
                    Text {
                        text: "Klik is meteen toepassen. Spijt? Ongedaan maken staat rechtsboven."
                        color: overlay.c.subtext0
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: overlay.s(11)
                    }
                }
                Item { Layout.fillWidth: true }
                Chip { glyph: "󰒓"; label: "Instellingen…"; onTriggered: overlay.openSettings("start") }
                Chip { glyph: "󰅖"; label: "Esc"; onTriggered: overlay.close() }
            }

            // ── 1 · Thema ───────────────────────────────────────────────
            Strip {
                order: 0
                label: "Thema"
                hint: "Kleuren, vormen en letters. Je wallpaper kleurt mee."
                ListView {
                    id: themeList
                    width: parent.width
                    height: overlay.s(132)
                    orientation: ListView.Horizontal
                    spacing: overlay.s(14)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: overlay.cursor[0]
                    highlightMoveDuration: ThemeConfig.duration(260)
                    model: overlay.themes.length + 1
                    delegate: Tile {
                        id: themeTile
                        required property int index
                        readonly property var theme: index < overlay.themes.length ? overlay.themes[index] : null
                        width: overlay.s(168)
                        frameHeight: overlay.s(100)
                        label: theme ? theme.title : "Aanpassen…"
                        glyph: "󰏘"
                        image: theme ? overlay.fileUrl(overlay.home + "/.config/kingstra/themes/previews/" + theme.preview + ".jpg") : ""
                        chosen: theme !== null && overlay.themeName === theme.id && overlay.pendingTheme === ""
                        busy: theme !== null && overlay.pendingTheme === theme.id
                        dot: theme !== null && overlay.customized.indexOf(theme.id) >= 0
                        focused: overlay.row === 0 && overlay.cursor[0] === index
                        onTriggered: overlay.activate(0, index)
                    }
                }
            }

            // ── 2 · Wallpaper ───────────────────────────────────────────
            Strip {
                order: 1
                label: "Wallpaper"
                hint: overlay.wallpapers.length === 0 ? "Geen afbeeldingen gevonden in je wallpapermap." : "Je nieuwste " + overlay.wallpapers.length + ". Alle… opent de grote kiezer."
                ListView {
                    id: wallList
                    width: parent.width
                    height: overlay.s(132)
                    orientation: ListView.Horizontal
                    spacing: overlay.s(14)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    currentIndex: overlay.cursor[1]
                    highlightMoveDuration: ThemeConfig.duration(260)
                    model: overlay.wallpapers.length + 2
                    delegate: Tile {
                        required property int index
                        readonly property bool first: index === 0
                        readonly property bool last: index === overlay.wallpapers.length + 1
                        readonly property string path: !first && !last ? overlay.wallpapers[index - 1] : ""
                        width: overlay.s(168)
                        frameHeight: overlay.s(100)
                        label: first ? "Willekeurig" : last ? "Alle…" : ""
                        glyph: first ? "󰒝" : "󰋩"
                        image: path !== "" ? overlay.fileUrl(path) : ""
                        chosen: path !== "" && path === overlay.currentWallpaper
                        focused: overlay.row === 1 && overlay.cursor[1] === index
                        onTriggered: overlay.activate(1, index)
                    }
                }
            }

            // ── 3 · Wat ga je doen ──────────────────────────────────────
            Strip {
                order: 2
                label: "Wat ga je doen"
                hint: overlay.autoGame !== "" ? "Spelen staat vanzelf aan voor " + overlay.autoGame + " en gaat terug als het spel sluit."
                    : "Past de hele desktop aan. Zen kan bij elke stand."
                RowLayout {
                    width: parent.width
                    spacing: overlay.s(14)
                    Repeater {
                        model: overlay.activities
                        delegate: Tile {
                            required property var modelData
                            required property int index
                            readonly property bool isZen: modelData.id === "zen"
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            frameHeight: overlay.s(112)
                            label: modelData.title
                            sublabel: isZen ? (overlay.zenOn ? "Staat aan. Klik om terug te gaan." : modelData.detail) : modelData.detail
                            glyph: modelData.glyph
                            chosen: isZen ? overlay.zenOn : overlay.modeName === modelData.id && overlay.pendingMode === ""
                            busy: !isZen && overlay.pendingMode === modelData.id
                            focused: overlay.row === 2 && overlay.cursor[2] === index
                            onTriggered: overlay.activate(2, index)
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
