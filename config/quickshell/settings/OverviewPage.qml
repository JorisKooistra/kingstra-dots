import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import "../"

// Overzicht: alles wat je vaak wisselt in één scherm. Mode, thema, indeling
// van deze werkruimte, scrollgedrag en wallpaper staan naast elkaar en zijn
// direct te veranderen; de andere tabbladen blijven voor de details.
Item {
    id: root
    signal pageRequested(string page)

    readonly property string home: Quickshell.env("HOME")
    readonly property string scripts: home + "/.config/hypr/scripts"
    readonly property string layoutHelper: scripts + "/workspace-layout.py"
    readonly property string werkvlakHelper: scripts + "/werkvlak-settings.py"
    readonly property int workspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    readonly property string screenName: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
    readonly property var profile: ScreenProfiles.profile(screenName)
    readonly property bool wide: width > 940

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

    MatugenColors { id: pageColors }
    readonly property var themeColors: pageColors

    function kingstra(args) {
        return ["bash", "-lc", "PATH=\"$HOME/.local/bin:$PATH\" kingstra " + args];
    }
    function readName(text) {
        try { return String(JSON.parse(text).name || ""); } catch (e) { return ""; }
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

    onWorkspaceChanged: inspectLayout()
    Component.onCompleted: {
        inspectLayout();
        werkvlakGet.running = true;
        wallpaperList.running = true;
    }
    Timer { interval: 2000; repeat: true; running: root.visible; onTriggered: root.inspectLayout() }
    // Een thema- of modewissel duurt even; de keuze knippert niet terug.
    Timer { id: pendingTimer; interval: 20000; onTriggered: { root.pendingMode = ""; root.pendingTheme = ""; } }

    FileView {
        path: root.home + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: { root.modeName = root.readName(text()); if (root.modeName === root.pendingMode) root.pendingMode = ""; }
    }
    FileView {
        path: root.home + "/.config/kingstra/state/theme.json"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: { root.themeName = root.readName(text()); if (root.themeName === root.pendingTheme) root.pendingTheme = ""; }
    }
    FileView {
        path: root.home + "/.cache/kingstra/last-image-wallpaper"
        watchChanges: true
        preload: true
        onFileChanged: reload()
        onLoaded: root.currentWallpaper = text().trim()
    }

    Process {
        id: inspectProcess
        stdout: StdioCollector { onStreamFinished: root.acceptLayout(this.text) }
    }
    Process {
        id: layoutProcess
        stdout: StdioCollector { onStreamFinished: root.acceptLayout(this.text) }
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
            "-printf '%T@ %p\\n' 2>/dev/null | sort -rn | head -n 48 | cut -d' ' -f2-"]
        stdout: StdioCollector {
            onStreamFinished: root.wallpapers = this.text.split("\n").filter(line => line.trim() !== "")
        }
    }

    component Action: Rectangle {
        id: button
        property string label: ""
        property bool chosen: false
        property bool busy: false
        property bool allowed: true
        signal triggered()
        implicitHeight: 34
        implicitWidth: caption.implicitWidth + 24
        radius: 8
        opacity: allowed ? 1 : 0.45
        scale: mouse.pressed ? 0.97 : 1.0
        Behavior on opacity { NumberAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
        Behavior on color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
        color: chosen || busy ? Qt.alpha(root.themeColors.primary, busy ? 0.12 : 0.2)
            : mouse.containsMouse ? root.themeColors.shellHoverFill : root.themeColors.shellRaisedFill
        border.width: 1
        border.color: chosen || busy ? root.themeColors.primary : root.themeColors.shellOutline
        Text {
            id: caption
            anchors.centerIn: parent
            text: button.busy ? button.label + "  …" : button.label
            color: root.themeColors.text
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.allowed
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
    component Heading: Text {
        color: root.themeColors.text
        font.family: ThemeConfig.uiFont
        font.pixelSize: 15
        font.bold: true
    }
    component Hint: Text {
        color: root.themeColors.subtext0
        font.family: ThemeConfig.uiFont
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    component Card: Rectangle {
        default property alias content: inner.data
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.preferredHeight: inner.implicitHeight + 32
        radius: 14
        color: Qt.alpha(root.themeColors.shellRaisedFill, 0.55)
        border.width: 1
        border.color: root.themeColors.shellOutline
        ColumnLayout {
            id: inner
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 22
        contentHeight: body.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: body
            width: parent.width
            spacing: 16

            Text {
                text: "Overzicht"
                color: root.themeColors.text
                font.family: ThemeConfig.uiFont
                font.pixelSize: 24
                font.bold: true
            }
            Hint {
                Layout.fillWidth: true
                text: "Alles wat je vaak wisselt op één plek. Een klik past het meteen toe; de andere tabbladen hebben de details."
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.wide ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                Card {
                    Heading { text: "Mode" }
                    Hint { Layout.fillWidth: true; text: "Geldt voor de hele desktop. Per scherm kies je een afwijkende mode in Bediening." }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [{id: "office", title: "Office"}, {id: "media", title: "Media"}, {id: "gaming", title: "Gaming"}]
                            delegate: Action {
                                required property var modelData
                                label: modelData.title
                                chosen: root.modeName === modelData.id && root.pendingMode === ""
                                busy: root.pendingMode === modelData.id
                                onTriggered: root.setMode(modelData.id)
                            }
                        }
                        Action { label: "Zen aan of uit"; onTriggered: Quickshell.execDetached(["bash", root.scripts + "/zen.sh", "toggle"]) }
                        Action { label: "Per scherm…"; onTriggered: root.pageRequested("bediening") }
                    }
                }

                Card {
                    Heading { text: "Indeling van werkruimte " + root.workspace }
                    Hint { Layout.fillWidth: true; text: "Ruimtelijk: tegels per plek en vrij verder scrollen naar elke kant." }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [{id: "tegels", title: "Tegelen"}, {id: "ruimtelijk", title: "Ruimtelijk werkvlak"}, {id: "scrollen", title: "Scrollstrook"}, {id: "50-50", title: "50 / 50"}, {id: "70-30", title: "70 / 30"}, {id: "focus", title: "Eén tegelijk"}]
                            delegate: Action {
                                required property var modelData
                                label: modelData.title
                                chosen: root.currentLayout === modelData.id
                                busy: layoutProcess.running && (layoutProcess.command || [])[3] === modelData.id
                                allowed: root.workspace > 0 && !layoutProcess.running
                                onTriggered: root.applyLayout(modelData.id)
                            }
                        }
                    }
                    Hint { text: root.layoutError; visible: text !== ""; color: root.themeColors.red; Layout.fillWidth: true }
                }

                Card {
                    Heading { text: "Thema" }
                    Flow {
                        Layout.fillWidth: true; spacing: 10
                        Repeater {
                            model: [{id: "matte", title: "Matte", preview: "matte"}, {id: "mono", title: "Mono", preview: "mono"}, {id: "mono-accent", title: "Mono accent", preview: "mono"}, {id: "neon", title: "Neon", preview: "neon"}, {id: "organic", title: "Organic", preview: "organic"}, {id: "paper", title: "Paper", preview: "paper"}]
                            delegate: Item {
                                id: themeTile
                                required property var modelData
                                readonly property bool chosen: root.themeName === modelData.id && root.pendingTheme === ""
                                readonly property bool busy: root.pendingTheme === modelData.id
                                width: 112; height: 92
                                scale: themeMouse.pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                                ClippingRectangle {
                                    id: themeFrame
                                    width: parent.width; height: 64
                                    radius: 10
                                    color: root.themeColors.shellRaisedFill
                                    border.width: themeTile.chosen || themeTile.busy ? 2 : 1
                                    border.color: themeTile.chosen || themeTile.busy ? root.themeColors.primary : root.themeColors.shellOutline
                                    Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                    Image {
                                        anchors.fill: parent
                                        source: root.fileUrl(root.home + "/.config/kingstra/themes/previews/" + themeTile.modelData.preview + ".jpg")
                                        sourceSize.width: 240
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        opacity: themeTile.busy ? 0.6 : 1
                                    }
                                }
                                Text {
                                    anchors.top: themeFrame.bottom; anchors.topMargin: 6
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: themeTile.busy ? themeTile.modelData.title + "  …" : themeTile.modelData.title
                                    color: themeTile.chosen ? root.themeColors.primary : root.themeColors.text
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 12
                                    font.bold: themeTile.chosen
                                }
                                MouseArea { id: themeMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setTheme(themeTile.modelData.id) }
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Action { label: "Kleuren en lettertypes…"; onTriggered: root.pageRequested("thema") }
                    }
                }

                Card {
                    Heading { text: "Scrollen en werkvlak" }
                    Hint { Layout.fillWidth: true; text: "Super+wiel scrolt binnen de werkruimte, Super+Shift+wiel wisselt van werkruimte, Super+Ctrl+linkermuis sleept vrij. Touchpad: vier vingers schuiven, knijpen zoomt. Aanraakscherm: twee vingers." }
                    Hint { text: "Breedte van een nieuw venster op een scrollstrook" }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [{v: 1.0, title: "Hele pagina"}, {v: 0.667, title: "Twee derde"}, {v: 0.5, title: "Half"}, {v: 0.333, title: "Een derde"}]
                            delegate: Action {
                                required property var modelData
                                label: modelData.title
                                chosen: root.near(root.werkvlak.column_width, modelData.v)
                                onTriggered: root.setWerkvlak("column_width", modelData.v)
                            }
                        }
                    }
                    Hint { Layout.fillWidth: true; text: "Ruimtelijk gebruikt Dwindle: splits en verhoudingen vrij aanpassen, zonder maximum per pagina." }
                    Hint { text: "Vastklikken na slepen" }
                    Flow {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: [{v: 0.0, title: "Nooit, helemaal vrij"}, {v: 0.2, title: "Licht"}, {v: 0.4, title: "Sterk"}]
                            delegate: Action {
                                required property var modelData
                                label: modelData.title
                                chosen: root.near(root.werkvlak.snap, modelData.v)
                                onTriggered: root.setWerkvlak("snap", modelData.v)
                            }
                        }
                        Action {
                            label: root.profile.wallpaperDrift ? "Wallpaper-effect: aan" : "Wallpaper-effect: uit"
                            chosen: root.profile.wallpaperDrift
                            allowed: !!root.screenName && !ScreenProfiles.busy
                            onTriggered: ScreenProfiles.action(["set", root.screenName, "wallpaperDrift", JSON.stringify(!root.profile.wallpaperDrift)])
                        }
                    }
                    Hint { text: root.werkvlakError; visible: text !== ""; color: root.themeColors.red; Layout.fillWidth: true }
                }
            }

            Card {
                Heading { text: "Wallpaper" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    ClippingRectangle {
                        Layout.preferredWidth: 220
                        Layout.preferredHeight: 124
                        radius: 12
                        color: root.themeColors.shellRaisedFill
                        border.width: 1
                        border.color: root.themeColors.shellOutline
                        Image {
                            anchors.fill: parent
                            source: root.fileUrl(root.currentWallpaper)
                            sourceSize.width: 440
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Hint { Layout.fillWidth: true; text: root.currentWallpaper ? root.currentWallpaper.split("/").pop() : "Nog geen wallpaper gekozen"; elide: Text.ElideMiddle; wrapMode: Text.NoWrap }
                        Hint { Layout.fillWidth: true; text: "Klik een afbeelding hieronder; de kleuren van het thema volgen de wallpaper." }
                        Flow {
                            Layout.fillWidth: true; spacing: 8
                            Action { label: "Willekeurig"; onTriggered: Quickshell.execDetached(["bash", root.scripts + "/wallpaper-random-safe.sh"]) }
                            Action { label: "Grote kiezer…"; onTriggered: Quickshell.execDetached(["bash", root.scripts + "/wallpaper-picker-safe.sh"]) }
                            Action { label: "Lijst vernieuwen"; onTriggered: wallpaperList.running = true }
                        }
                    }
                }
                Hint { visible: root.wallpapers.length === 0; Layout.fillWidth: true; text: "Geen afbeeldingen gevonden in je wallpapermap." }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: root.wallpapers
                        delegate: Item {
                            id: thumb
                            required property string modelData
                            readonly property bool chosen: modelData === root.currentWallpaper
                            width: 132; height: 76
                            scale: thumbMouse.pressed ? 0.96 : thumbMouse.containsMouse ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 9
                                color: root.themeColors.shellRaisedFill
                                border.width: thumb.chosen ? 2 : 1
                                border.color: thumb.chosen ? root.themeColors.primary : root.themeColors.shellOutline
                                Behavior on border.color { ColorAnimation { duration: ThemeConfig.duration(150) } }
                                Image {
                                    anchors.fill: parent
                                    source: root.fileUrl(thumb.modelData)
                                    sourceSize.width: 264
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            MouseArea { id: thumbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.setWallpaper(thumb.modelData) }
                        }
                    }
                }
            }
        }
    }
}
