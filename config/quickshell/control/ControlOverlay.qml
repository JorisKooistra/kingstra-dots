import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../"

// Bediening (Super+A): één overlay met alles wat je vaak wisselt, net als de
// thema- en modekiezer maar dan alles tegelijk. Thema, wallpaper, mode voor de
// hele desktop en per scherm, energieprofiel, indeling van de werkruimte,
// scrollgedrag en de rail per scherm staan naast elkaar en werken direct.
// De logica volgt Instellingen › Overzicht en › Bediening; de details blijven
// daar.
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
    readonly property string layoutHelper: scripts + "/workspace-layout.py"
    readonly property string werkvlakHelper: scripts + "/werkvlak-settings.py"

    // ── Gekozen scherm ──────────────────────────────────────────────────
    property string selectedName: ""
    readonly property var monitor: {
        let list = ScreenProfiles.monitors;
        for (let m of list) if (m.name === selectedName) return m;
        for (let m of list) if (m.focused) return m;
        return list.length ? list[0] : null;
    }
    readonly property string screenName: monitor ? monitor.name : ""
    readonly property var profile: ScreenProfiles.profile(screenName)
    readonly property int workspace: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 0
    readonly property var modeData: ScreenProfiles.state.presets[profile.mode] || ({})
    readonly property var modules: profile.rail.modules !== undefined ? profile.rail.modules : (modeData.modules || [])
    readonly property bool autohide: profile.rail.autohide !== undefined ? profile.rail.autohide : modeData.bar_autohide === true

    // ── Desktop ─────────────────────────────────────────────────────────
    property string modeName: ""
    property string themeName: ""
    property string pendingMode: ""
    property string pendingTheme: ""
    property string currentLayout: ""
    property string layoutError: ""
    property string currentWallpaper: ""
    property var wallpapers: []
    property var werkvlak: ({column_width: 1.0, snap: 0.2})
    property string werkvlakError: ""
    property string powerProfile: "balanced"
    property bool powerAvailable: false
    property bool shown: false

    function kingstra(args) {
        return ["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra " + args];
    }
    function readName(text) {
        try { return String(JSON.parse(text).name || ""); } catch (e) { return ""; }
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
    function setMode(name) {
        if (name === modeName) return;
        pendingMode = name;
        pendingTimer.restart();
        Quickshell.execDetached(kingstra("mode " + name));
    }
    function setTheme(name) {
        if (name === themeName) return;
        pendingTheme = name;
        pendingTimer.restart();
        Quickshell.execDetached(kingstra("theme " + name));
    }
    function setWallpaper(path) {
        currentWallpaper = path;
        Quickshell.execDetached(["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra wallpaper set \"$1\"", "_", path]);
    }
    function setPower(name) {
        if (!powerAvailable || name === powerProfile) return;
        powerProfile = name;
        Quickshell.execDetached(["powerprofilesctl", "set", name]);
    }
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
    function fileUrl(path) { return path ? "file://" + encodeURI(path) : ""; }

    onWorkspaceChanged: { currentLayout = ""; inspectLayout(); }
    Component.onCompleted: {
        inspectLayout();
        werkvlakGet.running = true;
        wallpaperList.running = true;
        powerReader.running = true;
        overlay.forceActiveFocus();
        revealTimer.start();
    }
    Timer { id: revealTimer; interval: 30; onTriggered: overlay.shown = true }
    Timer { interval: 2000; repeat: true; running: overlay.visible; onTriggered: overlay.inspectLayout() }
    Timer { interval: 4000; repeat: true; running: overlay.visible; onTriggered: if (!powerReader.running) powerReader.running = true }
    // Een thema- of modewissel duurt even; de keuze knippert niet terug.
    Timer { id: pendingTimer; interval: 20000; onTriggered: { overlay.pendingMode = ""; overlay.pendingTheme = ""; } }

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
        onLoaded: { overlay.themeName = overlay.readName(text()); if (overlay.themeName === overlay.pendingTheme) overlay.pendingTheme = ""; }
    }
    FileView {
        path: overlay.home + "/.cache/kingstra/last-image-wallpaper"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: overlay.currentWallpaper = text().trim()
    }

    Process {
        id: inspectProcess
        stdout: StdioCollector { onStreamFinished: overlay.acceptLayout(this.text) }
    }
    Process {
        id: layoutProcess
        stdout: StdioCollector {
            onStreamFinished: {
                overlay.acceptLayout(this.text);
                if (this.text.trim()) overlay.layoutError = "";
            }
        }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) overlay.layoutError = this.text.trim() }
    }
    Process {
        id: werkvlakGet
        command: ["python3", overlay.werkvlakHelper, "get"]
        stdout: StdioCollector { onStreamFinished: overlay.acceptWerkvlak(this.text) }
    }
    Process {
        id: werkvlakProcess
        stdout: StdioCollector { onStreamFinished: overlay.acceptWerkvlak(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) overlay.werkvlakError = this.text.trim() }
    }
    Process {
        id: powerReader
        command: ["bash", "-c", "command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get 2>/dev/null || echo none"]
        stdout: StdioCollector {
            onStreamFinished: {
                let value = this.text.trim();
                overlay.powerAvailable = value !== "" && value !== "none";
                if (overlay.powerAvailable) overlay.powerProfile = value;
            }
        }
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
            "-printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -n 60 | cut -d' ' -f2-"]
        stdout: StdioCollector {
            onStreamFinished: overlay.wallpapers = this.text.split("\n").filter(line => line.trim() !== "")
        }
    }

    Keys.onEscapePressed: (event) => {
        overlay.close();
        event.accepted = true;
    }

    // ── Bouwstenen ──────────────────────────────────────────────────────
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string glyph: ""
        property bool chosen: false
        property bool busy: false
        property bool allowed: true
        signal triggered()
        implicitHeight: overlay.s(32)
        implicitWidth: chipRow.implicitWidth + overlay.s(26)
        radius: height / 2
        opacity: allowed ? 1 : 0.45
        scale: chipMouse.pressed ? 0.96 : 1.0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(180) } }
        color: chosen || busy ? Qt.alpha(overlay.c.primary, busy ? 0.12 : 0.22)
            : chipMouse.containsMouse ? overlay.c.shellHoverFill : overlay.c.shellRaisedFill
        border.width: 1
        border.color: chosen || busy ? overlay.c.primary : overlay.c.shellOutline
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: overlay.s(6)
            Text {
                visible: chip.glyph !== ""
                text: chip.glyph
                color: chip.chosen ? overlay.c.primary : overlay.c.subtext1
                font.family: ThemeConfig.iconFont
                font.pixelSize: overlay.s(14)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: chip.busy ? chip.label + "  …" : chip.label
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
            enabled: chip.allowed
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.triggered()
        }
    }

    // Keuze uit een paar standen met een glijdende markering.
    component Segmented: Rectangle {
        id: seg
        property var options: []
        property string current: ""
        property bool allowed: true
        signal picked(string value)
        readonly property int activeIndex: {
            for (let i = 0; i < options.length; ++i) if (options[i].id === current) return i;
            return -1;
        }
        readonly property real slotWidth: options.length ? (width - overlay.s(8)) / options.length : 0
        Layout.fillWidth: true
        implicitHeight: overlay.s(40)
        radius: height / 2
        color: overlay.c.shellRaisedFill
        border.width: 1
        border.color: overlay.c.shellOutline
        opacity: allowed ? 1 : 0.45
        Rectangle {
            visible: seg.activeIndex >= 0
            x: overlay.s(4) + Math.max(0, seg.activeIndex) * seg.slotWidth
            y: overlay.s(4)
            width: seg.slotWidth
            height: seg.height - overlay.s(8)
            radius: height / 2
            color: Qt.alpha(overlay.c.primary, 0.24)
            border.width: 1
            border.color: overlay.c.primary
            Behavior on x { NumberAnimation { duration: ThemeConfig.duration(280); easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: ThemeConfig.duration(280); easing.type: Easing.OutCubic } }
        }
        Row {
            anchors.fill: parent
            anchors.margins: overlay.s(4)
            Repeater {
                model: seg.options
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    width: seg.slotWidth
                    height: parent.height
                    Row {
                        anchors.centerIn: parent
                        spacing: overlay.s(6)
                        Text {
                            visible: !!slot.modelData.glyph
                            text: slot.modelData.glyph || ""
                            color: slot.index === seg.activeIndex ? overlay.c.primary : overlay.c.subtext1
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: overlay.s(15)
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                        }
                        Text {
                            text: slot.modelData.title
                            color: slot.index === seg.activeIndex ? overlay.c.text : overlay.c.subtext0
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: overlay.s(12)
                            font.bold: slot.index === seg.activeIndex
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: ThemeConfig.duration(200) } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: seg.allowed
                        cursorShape: Qt.PointingHandCursor
                        onClicked: seg.picked(slot.modelData.id)
                    }
                }
            }
        }
    }

    component Heading: Row {
        id: heading
        property string glyph: ""
        property string label: ""
        spacing: overlay.s(8)
        Text {
            text: heading.glyph
            color: overlay.c.primary
            font.family: ThemeConfig.iconFont
            font.pixelSize: overlay.s(16)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: heading.label
            color: overlay.c.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: overlay.s(15)
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    component Hint: Text {
        color: overlay.c.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: overlay.s(11)
        wrapMode: Text.Wrap
    }
    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        Layout.preferredHeight: inner.implicitHeight + overlay.s(32)
        radius: overlay.s(18)
        color: Qt.alpha(overlay.c.shellRaisedFill, 0.55)
        border.width: 1
        border.color: overlay.c.shellOutline
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: overlay.s(16)
            spacing: overlay.s(10)
        }
    }
    // Kolom die met een kleine vertraging binnenglijdt.
    component Lane: Flickable {
        id: lane
        default property alias content: laneBody.data
        property int order: 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        contentHeight: laneBody.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        opacity: overlay.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(380 + lane.order * 90); easing.type: Easing.OutCubic } }
        transform: Translate {
            y: overlay.shown ? 0 : overlay.s(28)
            Behavior on y { NumberAnimation { duration: ThemeConfig.duration(520 + lane.order * 90); easing.type: Easing.OutExpo } }
        }
        ColumnLayout {
            id: laneBody
            width: lane.width
            spacing: overlay.s(14)
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
            anchors.margins: overlay.s(24)
            spacing: overlay.s(18)

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
                        text: "󰒓"
                        color: overlay.c.primary
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: overlay.s(20)
                    }
                }
                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Bediening"
                        color: overlay.c.text
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: overlay.s(22)
                        font.bold: true
                    }
                    Hint { text: "Alles wat je vaak wisselt, tegelijk. Een klik past het meteen toe." }
                }
                Item { Layout.fillWidth: true }
                Chip { glyph: "󰒓"; label: "Alle instellingen"; onTriggered: overlay.openSettings("overzicht") }
                Chip { glyph: "󰅖"; label: "Sluiten  ·  Esc"; onTriggered: overlay.close() }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: overlay.s(16)

                // ── Uiterlijk ───────────────────────────────────────────
                Lane {
                    order: 0

                    Card {
                        Heading { glyph: "󰏘"; label: "Thema" }
                        Flow {
                            id: themeFlow
                            Layout.fillWidth: true
                            spacing: overlay.s(10)
                            readonly property real tileWidth: (width - spacing * 2) / 3
                            Repeater {
                                model: [{id: "mono", title: "Mono", preview: "mono"}, {id: "mono-accent", title: "Mono accent", preview: "mono"}, {id: "neon", title: "Neon", preview: "neon"}, {id: "organic", title: "Organic", preview: "organic"}, {id: "paper", title: "Paper", preview: "paper"}]
                                delegate: Item {
                                    id: themeTile
                                    required property var modelData
                                    readonly property bool chosen: overlay.themeName === modelData.id && overlay.pendingTheme === ""
                                    readonly property bool busy: overlay.pendingTheme === modelData.id
                                    width: themeFlow.tileWidth
                                    height: themeFrame.height + overlay.s(24)
                                    scale: themeMouse.pressed ? 0.96 : themeMouse.containsMouse ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                                    ClippingRectangle {
                                        id: themeFrame
                                        width: parent.width
                                        height: Math.round(width * 0.6)
                                        radius: overlay.s(12)
                                        color: overlay.c.shellRaisedFill
                                        border.width: themeTile.chosen || themeTile.busy ? 2 : 1
                                        border.color: themeTile.chosen || themeTile.busy ? overlay.c.primary : overlay.c.shellOutline
                                        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                        Image {
                                            anchors.fill: parent
                                            source: overlay.fileUrl(overlay.home + "/.config/kingstra/themes/previews/" + themeTile.modelData.preview + ".jpg")
                                            sourceSize.width: 260
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            opacity: themeTile.busy ? 0.6 : 1
                                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(200) } }
                                        }
                                    }
                                    Text {
                                        anchors.top: themeFrame.bottom
                                        anchors.topMargin: overlay.s(5)
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: themeTile.busy ? themeTile.modelData.title + "  …" : themeTile.modelData.title
                                        color: themeTile.chosen ? overlay.c.primary : overlay.c.text
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: overlay.s(12)
                                        font.bold: themeTile.chosen
                                        elide: Text.ElideRight
                                    }
                                    MouseArea {
                                        id: themeMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: overlay.setTheme(themeTile.modelData.id)
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        Heading { glyph: "󰸉"; label: "Wallpaper" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: overlay.s(12)
                            ClippingRectangle {
                                Layout.preferredWidth: overlay.s(150)
                                Layout.preferredHeight: overlay.s(86)
                                radius: overlay.s(12)
                                color: overlay.c.shellRaisedFill
                                border.width: 1
                                border.color: overlay.c.shellOutline
                                Image {
                                    anchors.fill: parent
                                    source: overlay.fileUrl(overlay.currentWallpaper)
                                    sourceSize.width: 320
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: overlay.s(8)
                                Hint {
                                    Layout.fillWidth: true
                                    text: overlay.currentWallpaper ? overlay.currentWallpaper.split("/").pop() : "Nog geen wallpaper gekozen"
                                    elide: Text.ElideMiddle
                                    wrapMode: Text.NoWrap
                                }
                                Flow {
                                    Layout.fillWidth: true
                                    spacing: overlay.s(6)
                                    Chip { glyph: "󰒝"; label: "Willekeurig"; onTriggered: Quickshell.execDetached(["bash", overlay.scripts + "/wallpaper-random-safe.sh"]) }
                                    Chip { glyph: "󰋩"; label: "Grote kiezer"; onTriggered: overlay.closeThen(["bash", overlay.scripts + "/wallpaper-picker-safe.sh"]) }
                                }
                            }
                        }
                        Hint { visible: overlay.wallpapers.length === 0; Layout.fillWidth: true; text: "Geen afbeeldingen gevonden in je wallpapermap." }
                        GridView {
                            id: wallGrid
                            visible: overlay.wallpapers.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: overlay.s(250)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            cellWidth: width / 3
                            cellHeight: Math.round(cellWidth * 0.6)
                            model: overlay.wallpapers
                            delegate: Item {
                                id: thumb
                                required property string modelData
                                readonly property bool chosen: modelData === overlay.currentWallpaper
                                width: wallGrid.cellWidth
                                height: wallGrid.cellHeight
                                ClippingRectangle {
                                    anchors.fill: parent
                                    anchors.margins: overlay.s(4)
                                    radius: overlay.s(10)
                                    color: overlay.c.shellRaisedFill
                                    border.width: thumb.chosen ? 2 : 1
                                    border.color: thumb.chosen ? overlay.c.primary : overlay.c.shellOutline
                                    scale: thumbMouse.pressed ? 0.95 : thumbMouse.containsMouse ? 1.03 : 1.0
                                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Image {
                                        anchors.fill: parent
                                        source: overlay.fileUrl(thumb.modelData)
                                        sourceSize.width: 240
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                MouseArea {
                                    id: thumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: overlay.setWallpaper(thumb.modelData)
                                }
                            }
                        }
                    }
                }

                // ── Mode, schermen en energie ───────────────────────────
                Lane {
                    order: 1

                    Card {
                        Heading { glyph: "󰾅"; label: "Mode  ·  hele desktop" }
                        Segmented {
                            options: [{id: "office", title: "Office", glyph: "󰈙"}, {id: "media", title: "Media", glyph: "󰝚"}, {id: "gaming", title: "Gaming", glyph: "󰊴"}]
                            current: overlay.pendingMode !== "" ? overlay.pendingMode : overlay.modeName
                            onPicked: (value) => overlay.setMode(value)
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Chip { glyph: "󰚀"; label: "Zen aan of uit"; onTriggered: Quickshell.execDetached(["bash", overlay.scripts + "/zen.sh", "toggle"]) }
                            Hint { visible: overlay.pendingMode !== ""; text: "Mode wordt toegepast…"; height: overlay.s(32); verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    Card {
                        Heading { glyph: "󰍹"; label: overlay.screenName ? "Scherm  ·  " + overlay.screenName : "Schermen" }
                        Item {
                            id: screenMap
                            Layout.fillWidth: true
                            Layout.preferredHeight: overlay.s(110)
                            readonly property var box: {
                                let list = ScreenProfiles.monitors;
                                let x0 = 0, y0 = 0, x1 = 1, y1 = 1;
                                for (let m of list) {
                                    let f = Number(m.scale) || 1;
                                    x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y);
                                    x1 = Math.max(x1, m.x + m.width / f);
                                    y1 = Math.max(y1, m.y + m.height / f);
                                }
                                return {x: x0, y: y0, w: x1 - x0, h: y1 - y0};
                            }
                            readonly property real ratio: Math.min(width / box.w, height / box.h)
                            readonly property real shiftX: (width - box.w * ratio) / 2
                            Repeater {
                                model: ScreenProfiles.monitors
                                delegate: Rectangle {
                                    id: display
                                    required property var modelData
                                    readonly property bool picked: modelData.name === overlay.screenName
                                    x: screenMap.shiftX + (modelData.x - screenMap.box.x) * screenMap.ratio + 3
                                    y: (modelData.y - screenMap.box.y) * screenMap.ratio + 3
                                    width: Math.max(20, modelData.width / (modelData.scale || 1) * screenMap.ratio - 6)
                                    height: Math.max(20, modelData.height / (modelData.scale || 1) * screenMap.ratio - 6)
                                    radius: overlay.s(10)
                                    color: picked ? Qt.alpha(overlay.c.primary, 0.22) : displayMouse.containsMouse ? overlay.c.shellHoverFill : overlay.c.shellRaisedFill
                                    border.color: picked ? overlay.c.primary : overlay.c.shellOutline
                                    border.width: picked ? 2 : 1
                                    clip: true
                                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
                                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(180) } }
                                    Text {
                                        anchors.centerIn: parent
                                        width: parent.width - 10
                                        horizontalAlignment: Text.AlignHCenter
                                        text: display.modelData.name + "\n" + ScreenProfiles.profile(display.modelData.name).mode
                                        color: overlay.c.text
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: overlay.s(11)
                                        elide: Text.ElideRight
                                    }
                                    MouseArea {
                                        id: displayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: overlay.selectedName = display.modelData.name
                                    }
                                }
                            }
                        }
                        Hint { Layout.fillWidth: true; text: "Mode van dit scherm: rail, verbergen, muziek en meldingen. Volg neemt de desktopmode over." }
                        Segmented {
                            options: [{id: "inherit", title: "Volg"}, {id: "office", title: "Office"}, {id: "media", title: "Media"}, {id: "gaming", title: "Gaming"}]
                            current: overlay.profile.inherited ? "inherit" : overlay.profile.mode
                            allowed: !!overlay.screenName && !ScreenProfiles.busy
                            onPicked: (value) => ScreenProfiles.action(["mode", overlay.screenName, value])
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Chip {
                                glyph: "󰘖"
                                label: overlay.profile.wallpaperDrift ? "Wallpaper-effect: aan" : "Wallpaper-effect: uit"
                                chosen: overlay.profile.wallpaperDrift
                                allowed: !!overlay.screenName && !ScreenProfiles.busy
                                onTriggered: overlay.setScreen("wallpaperDrift", !overlay.profile.wallpaperDrift)
                            }
                            Chip { glyph: "󰍹"; label: "Schermindeling"; onTriggered: overlay.openSettings("beeldschermen") }
                        }
                        Hint { text: ScreenProfiles.errorText; visible: text !== ""; color: overlay.c.red; Layout.fillWidth: true }
                    }

                    Card {
                        Heading { glyph: "󰓅"; label: "Energieprofiel" }
                        Segmented {
                            options: [{id: "power-saver", title: "Zuinig", glyph: "󰌪"}, {id: "balanced", title: "Gebalanceerd", glyph: "󰾅"}, {id: "performance", title: "Prestaties", glyph: "󰓅"}]
                            current: overlay.powerAvailable ? overlay.powerProfile : ""
                            allowed: overlay.powerAvailable
                            onPicked: (value) => overlay.setPower(value)
                        }
                        Hint { visible: !overlay.powerAvailable; Layout.fillWidth: true; text: "power-profiles-daemon draait niet; het profiel is nu niet te wisselen." }
                    }
                }

                // ── Werkvlak en rail ────────────────────────────────────
                Lane {
                    order: 2

                    Card {
                        Heading { glyph: "󰕰"; label: "Indeling  ·  werkruimte " + overlay.workspace }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Repeater {
                                model: [{id: "tegels", title: "Tegelen", glyph: "󰕴"}, {id: "ruimtelijk", title: "Ruimtelijk werkvlak", glyph: "󰊢"}, {id: "scrollen", title: "Scrollstrook", glyph: "󰁔"}, {id: "50-50", title: "50 / 50", glyph: "󰕭"}, {id: "70-30", title: "70 / 30", glyph: "󰕬"}, {id: "focus", title: "Eén tegelijk", glyph: "󰊓"}]
                                delegate: Chip {
                                    required property var modelData
                                    glyph: modelData.glyph
                                    label: modelData.title
                                    chosen: overlay.currentLayout === modelData.id
                                    busy: layoutProcess.running && (layoutProcess.command || [])[3] === modelData.id
                                    allowed: overlay.workspace > 0 && !layoutProcess.running
                                    onTriggered: overlay.applyLayout(modelData.id)
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Chip { glyph: "󰕮"; label: "Werkvlakkaart  ·  Super+Tab"; onTriggered: overlay.closeThen(["bash", overlay.scripts + "/overview-toggle.sh"]) }
                        }
                        Hint { text: overlay.layoutError; visible: text !== ""; color: overlay.c.red; Layout.fillWidth: true }
                    }

                    Card {
                        Heading { glyph: "󰁔"; label: "Scrollen en werkvlak" }
                        Hint { Layout.fillWidth: true; text: "Breedte van een nieuw venster op een scrollstrook" }
                        Segmented {
                            options: [{id: "1", title: "Heel"}, {id: "0.667", title: "⅔"}, {id: "0.5", title: "½"}, {id: "0.333", title: "⅓"}]
                            current: {
                                for (let v of ["1", "0.667", "0.5", "0.333"])
                                    if (overlay.near(overlay.werkvlak.column_width, v)) return v;
                                return "";
                            }
                            allowed: !werkvlakProcess.running
                            onPicked: (value) => overlay.setWerkvlak("column_width", Number(value))
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Hint { text: "Vastklikken na slepen"; Layout.fillWidth: true }
                            Hint {
                                readonly property real v: snapSlider.dragging ? snapSlider.live : Number(overlay.werkvlak.snap)
                                text: v < 0.01 ? "helemaal vrij" : v < 0.27 ? "licht" : v < 0.37 ? "middel" : "sterk"
                                color: overlay.c.primary
                            }
                        }
                        // Schuif voor de snap-sterkte (0 = nooit, 0.45 = bijna altijd).
                        Item {
                            id: snapSlider
                            Layout.fillWidth: true
                            Layout.preferredHeight: overlay.s(28)
                            readonly property real maxValue: 0.45
                            property bool dragging: false
                            property real live: 0
                            readonly property real fraction: Math.max(0, Math.min(1, (dragging ? live : Number(overlay.werkvlak.snap)) / maxValue))
                            function valueAt(px) {
                                return Math.round(Math.max(0, Math.min(1, (px - knob.width / 2) / (width - knob.width))) * maxValue * 100) / 100;
                            }
                            Rectangle {
                                id: track
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: overlay.s(8)
                                radius: height / 2
                                color: overlay.c.shellRaisedFill
                                border.width: 1
                                border.color: overlay.c.shellOutline
                                Rectangle {
                                    width: knob.x + knob.width / 2
                                    height: parent.height
                                    radius: height / 2
                                    color: Qt.alpha(overlay.c.primary, 0.55)
                                }
                            }
                            Rectangle {
                                id: knob
                                width: overlay.s(22)
                                height: width
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: snapSlider.fraction * (snapSlider.width - width)
                                color: overlay.c.primary
                                border.width: 2
                                border.color: overlay.c.mantle
                                scale: snapMouse.pressed ? 1.15 : snapMouse.containsMouse ? 1.06 : 1.0
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutBack } }
                                Behavior on x { enabled: !snapSlider.dragging; NumberAnimation { duration: ThemeConfig.duration(220); easing.type: Easing.OutCubic } }
                            }
                            MouseArea {
                                id: snapMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !werkvlakProcess.running
                                cursorShape: Qt.PointingHandCursor
                                onPressed: (mouse) => { snapSlider.live = snapSlider.valueAt(mouse.x); snapSlider.dragging = true; }
                                onPositionChanged: (mouse) => { if (pressed) snapSlider.live = snapSlider.valueAt(mouse.x); }
                                onReleased: {
                                    let value = snapSlider.live;
                                    snapSlider.dragging = false;
                                    if (!overlay.near(value, overlay.werkvlak.snap)) overlay.setWerkvlak("snap", value);
                                }
                                onCanceled: snapSlider.dragging = false
                            }
                        }
                        Hint { Layout.fillWidth: true; text: "Super+wiel scrolt binnen de werkruimte, Super+Shift+wiel wisselt van werkruimte, Super+Ctrl+linkermuis sleept vrij." }
                        Hint { text: overlay.werkvlakError; visible: text !== ""; color: overlay.c.red; Layout.fillWidth: true }
                    }

                    Card {
                        Heading { glyph: "󰕮"; label: "Rail  ·  " + (overlay.screenName || "scherm") + "  ·  " + overlay.profile.mode }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Chip {
                                glyph: "󰘕"
                                label: overlay.autohide ? "Automatisch verbergen: aan" : "Automatisch verbergen: uit"
                                chosen: overlay.autohide
                                allowed: !!overlay.screenName && !ScreenProfiles.busy
                                onTriggered: overlay.setScreen("rail.autohide", !overlay.autohide)
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Repeater {
                                model: [{id: "workspaces", title: "Werkruimtes"}, {id: "clock", title: "Klok"}, {id: "updates", title: "Updates"}, {id: "cpu_temp", title: "Systeem"}, {id: "network", title: "Netwerk"}, {id: "battery", title: "Batterij"}, {id: "volume", title: "Geluid"}, {id: "bluetooth", title: "Bluetooth"}, {id: "notifications", title: "Meldingen"}, {id: "media_controls", title: "Media"}]
                                delegate: Chip {
                                    required property var modelData
                                    label: modelData.title
                                    chosen: overlay.modules.indexOf(modelData.id) >= 0
                                    allowed: !!overlay.screenName && !ScreenProfiles.busy
                                    onTriggered: overlay.toggleModule(modelData.id)
                                }
                            }
                        }
                        Flow {
                            Layout.fillWidth: true
                            spacing: overlay.s(6)
                            Chip { glyph: "󰑓"; label: "Herstel voor deze mode"; allowed: !!overlay.screenName && !ScreenProfiles.busy; onTriggered: ScreenProfiles.action(["reset", overlay.screenName]) }
                            Chip { glyph: "󰒓"; label: "Meer en muziek…"; onTriggered: overlay.openSettings("bediening") }
                        }
                    }
                }
            }
        }
    }
}
