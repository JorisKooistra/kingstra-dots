import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: root
    focus: true

    Scaler { id: scaler; currentWidth: Screen.width }
    function s(val) { return scaler.s(val); }

    // -------------------------------------------------------------------------
    // KEYBOARD SHORTCUTS
    // -------------------------------------------------------------------------
    Keys.onEscapePressed: {
        if (editingIndex >= 0) { editingIndex = -1; }
        else { closeSequence.start(); }
        event.accepted = true;
    }
    Keys.onTabPressed: { currentTab = (currentTab + 1) % tabNames.length; event.accepted = true; }
    Keys.onBacktabPressed: { currentTab = (currentTab - 1 + tabNames.length) % tabNames.length; event.accepted = true; }

    MatugenColors { id: _theme }

    // -------------------------------------------------------------------------
    // COLORS
    // -------------------------------------------------------------------------
    readonly property color base: _theme.base
    readonly property color mantle: _theme.mantle
    readonly property color crust: _theme.crust
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color subtext1: _theme.subtext1
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color overlay0: _theme.overlay0
    readonly property color mauve: _theme.mauve
    readonly property color pink: _theme.pink
    readonly property color blue: _theme.blue
    readonly property color sapphire: _theme.sapphire
    readonly property color green: _theme.green
    readonly property color peach: _theme.peach
    readonly property color yellow: _theme.yellow
    readonly property color red: _theme.red
    readonly property int themedRadius: root.s(Math.max(12, ThemeConfig.borderRadius))
    readonly property int themedInnerRadius: root.s(Math.max(8, ThemeConfig.borderRadius - 4))
    readonly property string uiFontFamily: ThemeConfig.uiFont
    readonly property string monoFontFamily: ThemeConfig.monoFont
    readonly property string displayFontFamily: ThemeConfig.displayFont
    readonly property real themedLetterSpacing: ThemeConfig.letterSpacing
    readonly property int themedFontWeight: ThemeConfig.fontWeight
    readonly property color popupFill: Qt.rgba(root.base.r, root.base.g, root.base.b, ThemeConfig.popupOpacity)
    readonly property color popupPanelFill: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, Math.min(0.88, ThemeConfig.popupOpacity * 0.55))
    readonly property color popupPanelHoverFill: Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, Math.min(0.94, ThemeConfig.popupOpacity * 0.72))

    property real colorBlend: 0.0
    SequentialAnimation on colorBlend {
        loops: Animation.Infinite; running: true
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }
    property color ambientPurple: Qt.tint(root.mauve, Qt.rgba(root.pink.r, root.pink.g, root.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(root.blue, Qt.rgba(root.sapphire.r, root.sapphire.g, root.sapphire.b, colorBlend))

    // -------------------------------------------------------------------------
    // STATE
    // -------------------------------------------------------------------------
    property int currentTab: 0
    property var tabNames: ["About", "Keybinds", "Weather & Time", "Theme"]
    property var tabIcons: ["", "󰌌", "󰖐", "󰏘"]

    property real introBase: 0.0
    property real introSidebar: 0.0
    property real introContent: 0.0

    // Keybinds state
    ListModel { id: keybindsModel }
    property int editingIndex: -1
    property string keybindFilter: ""

    // Catalog van bekende acties zonder vaste keybinding — worden als "Niet ingesteld" getoond
    readonly property var keybindCatalog: [
        { label: "Kleurenkiezer",    cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "hyprpicker -r -n -f hex",              t: "bind", ln: 0, mods: "", key: "" },
        { label: "Schermopname",     cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "wf-recorder",                          t: "bind", ln: 0, mods: "", key: "" },
        { label: "Uitlogmenu",       cat: "core",  file: "80-binds-core.conf",  d: "exec", args: "wlogout",                               t: "bind", ln: 0, mods: "", key: "" },
        { label: "Emoji-kiezer",     cat: "apps",  file: "81-binds-apps.conf",  d: "exec", args: "walker --modules emojis",               t: "bind", ln: 0, mods: "", key: "" }
    ]

    // Settings file
    property var settingsData: ({})

    // Load settings via Process in plaats van FileView
    Process {
        id: loadSettingsProc
        command: ["bash", "-c", "cat ~/.config/quickshell/settings/settings.json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.settingsData = JSON.parse(this.text); } catch(e) {}
            }
        }
    }

    // Keybinds laden via Process → StdioCollector (geen temp-bestand race-conditie)
    Process {
        id: loadKeybindsProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/settings/read_keybinds.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text);
                    root.mergeKeybinds(data);
                } catch(e) {
                    root.mergeKeybinds([]);
                }
            }
        }
    }

    // Weather state
    property string selectedUnit: "metric"

    // Theme state
    property string activeThemeName: ""
    property string activeThemeIcon: "󰏘"
    property string activeThemeId: ""
    property var themeAppearance: ({})
    property var activeThemeData: ({})

    function refreshActiveTheme() {
        loadThemeProc.running = true;
    }

    function themeSection(themeData, name) {
        if (themeData && themeData[name]) return themeData[name];
        return ({});
    }

    function themeValue(themeData, sectionName, key, fallback) {
        let section = themeSection(themeData, sectionName);
        let value = section[key];
        return value !== undefined && value !== "" ? value : fallback;
    }

    function formatSchemeLabel(value) {
        let cleaned = String(value || "scheme-tonal-spot").replace(/^scheme-/, "");
        let parts = cleaned.split("-");
        for (let i = 0; i < parts.length; i++) {
            if (parts[i].length > 0) parts[i] = parts[i].charAt(0).toUpperCase() + parts[i].slice(1);
        }
        return parts.join(" ");
    }

    Component.onCompleted: {
        // Laad settings via Process
        loadSettingsProc.running = true;
        // Laad keybinds via Process
        loadKeybindsProc.running = true;
        // Load weather .env values
        loadEnvProc.running = true;
        // Load active theme info
        refreshActiveTheme();
        startupSequence.start();
    }

    // Load weather .env on open
    Process {
        id: loadEnvProc
        command: ["bash", "-c", "if [ -f ~/.config/quickshell/calendar/.env ]; then cat ~/.config/quickshell/calendar/.env; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.startsWith("#") || line === "") continue;
                    let eq = line.indexOf("=");
                    if (eq < 0) continue;
                    let k = line.substring(0, eq).trim();
                    let v = line.substring(eq + 1).trim().replace(/^["']|["']$/g, "");
                    if (k === "OPENWEATHER_KEY" && v) apiKeyInput.text = v;
                    else if (k === "OPENWEATHER_LAT" && v) latInput.text = v;
                    else if (k === "OPENWEATHER_LON" && v) lonInput.text = v;
                    else if (k === "OPENWEATHER_UNIT" && v) root.selectedUnit = v;
                }
            }
        }
    }

    // Load active theme info
    Process {
        id: loadThemeProc
        command: ["bash", "-c", "$HOME/.local/bin/kingstra-theme-switch --current"]
        stdout: StdioCollector {
            onStreamFinished: {
                let active = this.text.trim();
                if (active !== "") {
                    loadThemeDetailProc.themeId = active;
                    loadThemeDetailProc.running = true;
                }
            }
        }
    }
    Process {
        id: loadThemeDetailProc
        property string themeId: ""
        command: ["bash", "-c", "$HOME/.local/bin/kingstra-theme-read --json \"${XDG_CONFIG_HOME:-$HOME/.config}/kingstra/themes/" + themeId + ".toml\""]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim());
                    let meta = data.meta || {};
                    root.activeThemeId = loadThemeDetailProc.themeId;
                    root.activeThemeData = data;
                    root.activeThemeName = meta.name || loadThemeDetailProc.themeId;
                    root.activeThemeIcon = meta.icon || "󰏘";
                    root.themeAppearance = data.appearance || {};
                } catch(e) {}
            }
        }
    }

    SequentialAnimation {
        id: startupSequence
        PauseAnimation { duration: 50 }
        NumberAnimation { target: root; property: "introBase"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        NumberAnimation { target: root; property: "introSidebar"; to: 1.0; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: 350; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
            NumberAnimation { target: root; property: "introSidebar"; to: 0.0; duration: 150; easing.type: Easing.InExpo }
        }
        NumberAnimation { target: root; property: "introBase"; to: 0.0; duration: 200; easing.type: Easing.InQuart }
        ScriptAction { script: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]) }
    }

    // -------------------------------------------------------------------------
    // HELPER: save settings.json
    // -------------------------------------------------------------------------
    function saveSettings(timeFormat, dateFormat) {
        var path = Quickshell.env("HOME") + "/.config/quickshell/settings/settings.json";
        var json = JSON.stringify({ timeFormat: timeFormat, dateFormat: dateFormat }, null, 4);
        var cmd = "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > " + path;
        Quickshell.execDetached(["bash", "-c", cmd]);
        notify("Settings", "Date & time format saved");
    }

    function saveWeatherConfig() {
        var file = Quickshell.env("HOME") + "/.config/quickshell/calendar/.env";
        var cmds = [
            "mkdir -p $(dirname " + file + ")",
            "echo 'OPENWEATHER_KEY=" + apiKeyInput.text + "' > " + file,
            "echo 'OPENWEATHER_UNIT=" + root.selectedUnit + "' >> " + file,
            "echo 'OPENWEATHER_LAT=" + latInput.text + "' >> " + file,
            "echo 'OPENWEATHER_LON=" + lonInput.text + "' >> " + file,
            "echo 'OPENWEATHER_CITY_ID=' >> " + file
        ];
        Quickshell.execDetached(["bash", "-c", cmds.join(" && ")]);
        notify("Weather", "API configuration saved");
        // Trigger immediate weather refresh by clearing cache
        weatherRefreshTimer.start();
    }

    Timer {
        id: weatherRefreshTimer; interval: 500
        onTriggered: {
            Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/quickshell/weather/weather.json 2>/dev/null; bash ~/.config/quickshell/calendar/weather.sh &"]);
        }
    }

    // Voeg catalogus-acties toe die nog niet gebonden zijn
    function mergeKeybinds(rawData) {
        keybindsModel.clear();
        var boundKeys = {};
        for (var i = 0; i < rawData.length; i++) {
            rawData[i].bound = true;
            keybindsModel.append(rawData[i]);
            boundKeys[rawData[i].d + "|" + rawData[i].args] = true;
        }
        for (var j = 0; j < keybindCatalog.length; j++) {
            var entry = keybindCatalog[j];
            if (!boundKeys[entry.d + "|" + entry.args]) {
                keybindsModel.append({
                    file: entry.file, cat: entry.cat, ln: 0,
                    t: entry.t, mods: "", key: "",
                    d: entry.d, args: entry.args,
                    label: entry.label, bound: false
                });
            }
        }
    }

    function saveKeybind(index, newMods, newKey) {
        var item = keybindsModel.get(index);
        var line = (item.t || "bind") + " = " + newMods + ", " + newKey + ", " + item.d;
        if (item.args) line += ", " + item.args;
        if (item.label) line += "   # " + item.label;
        var script = Quickshell.env("HOME") + "/.config/quickshell/settings/write_keybind.sh";
        if (item.bound) {
            Quickshell.execDetached(["bash", script, "--update", item.file, item.ln.toString(), line]);
        } else {
            Quickshell.execDetached(["bash", script, "--add", item.file, line]);
            keybindsModel.setProperty(index, "bound", true);
        }
        keybindsModel.setProperty(index, "mods", newMods);
        keybindsModel.setProperty(index, "key", newKey);
        editingIndex = -1;
    }

    function removeKeybind(index) {
        var item = keybindsModel.get(index);
        if (!item.bound) return;
        var script = Quickshell.env("HOME") + "/.config/quickshell/settings/write_keybind.sh";
        Quickshell.execDetached(["bash", script, "--remove", item.file, item.ln.toString()]);
        keybindsModel.setProperty(index, "bound", false);
        keybindsModel.setProperty(index, "mods", "");
        keybindsModel.setProperty(index, "key", "");
        editingIndex = -1;
    }

    function notify(title, msg) {
        Quickshell.execDetached(["notify-send", title, msg]);
    }

    function runUpdateBootstrap() {
        var bootstrapUrl = "https://raw.githubusercontent.com/JorisKooistra/kingstra-dots/main/bootstrap.sh";
        var command = "bash <(curl -fsSL " + bootstrapUrl + ")";
        Quickshell.execDetached(["kitty", "--hold", "bash", "-lc", command]);
        notify("Settings", "Update gestart in terminal");
    }

    // -------------------------------------------------------------------------
    // BACKGROUND
    // -------------------------------------------------------------------------
    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            anchors.fill: parent; radius: root.themedRadius
            color: root.popupFill; border.color: root.surface0; border.width: Math.max(1, ThemeConfig.borderWidth)
            clip: true

            property real time: 0
            NumberAnimation on time { from: 0; to: Math.PI * 2; duration: 20000; loops: Animation.Infinite; running: true }

            Rectangle {
                width: root.s(600); height: root.s(600); radius: root.s(300)
                x: parent.width * 0.6 + Math.cos(parent.time) * root.s(100)
                y: parent.height * 0.1 + Math.sin(parent.time * 1.5) * root.s(100)
                color: root.ambientPurple; opacity: 0.04
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
            }
            Rectangle {
                width: root.s(700); height: root.s(700); radius: root.s(350)
                x: parent.width * 0.1 + Math.sin(parent.time * 0.8) * root.s(150)
                y: parent.height * 0.4 + Math.cos(parent.time * 1.2) * root.s(100)
                color: root.ambientBlue; opacity: 0.03
                layer.enabled: true; layer.effect: MultiEffect { blurEnabled: true; blurMax: 90; blur: 1.0 }
            }
        }
    }

    // -------------------------------------------------------------------------
    // MAIN LAYOUT
    // -------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(20)

        // =====================================================================
        // SIDEBAR
        // =====================================================================
        Rectangle {
            Layout.fillHeight: true; Layout.preferredWidth: root.s(220)
            radius: root.themedInnerRadius; color: root.popupPanelFill
            border.color: root.surface1; border.width: 1
            opacity: introSidebar
            transform: Translate { x: root.s(-30) * (1.0 - introSidebar) }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(10)

                // Header
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(60)
                    RowLayout {
                        anchors.fill: parent; spacing: root.s(12)
                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: root.s(36); height: root.s(36); radius: root.s(10)
                            color: root.ambientPurple
                            Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.base }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                            Text { text: "Settings"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text }
                            Text { text: "kingstra-dots"; font.family: root.uiFontFamily; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(11); color: root.subtext0 }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(root.surface1, 0.5); Layout.bottomMargin: root.s(10) }

                // Tab buttons
                Repeater {
                    model: root.tabNames.length
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                        property bool isActive: root.currentTab === index
                        color: isActive ? root.popupPanelHoverFill : (tabMa.containsMouse ? root.popupPanelFill : "transparent")
                        Behavior on color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: root.s(15); spacing: root.s(12)
                            Item {
                                Layout.preferredWidth: root.s(24); Layout.alignment: Qt.AlignVCenter
                                Text { anchors.centerIn: parent; text: root.tabIcons[index]; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: parent.parent.parent.isActive ? root.ambientPurple : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                            }
                            Text { text: root.tabNames[index]; font.family: root.uiFontFamily; font.weight: parent.parent.isActive ? root.themedFontWeight : Font.Medium; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(13); color: parent.parent.isActive ? root.text : root.subtext0; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; Behavior on color { ColorAnimation { duration: 150 } } }
                        }

                        Rectangle {
                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                            width: root.s(3); height: parent.isActive ? root.s(20) : 0; radius: root.s(2)
                            color: root.ambientPurple
                            Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        }

                        MouseArea { id: tabMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.currentTab = index }
                    }
                }

                Item { Layout.fillHeight: true }

                // Close button
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.s(44); radius: root.s(8)
                    color: closeHover.containsMouse ? Qt.alpha(root.red, 0.1) : "transparent"
                    border.color: closeHover.containsMouse ? root.red : root.surface1; border.width: 1
                    scale: closeHover.pressed ? 0.95 : (closeHover.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: closeHover.containsMouse ? root.red : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                    MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: closeSequence.start() }
                }
            }
        }

        // =====================================================================
        // CONTENT AREA
        // =====================================================================
        Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            opacity: introContent; scale: 0.95 + (0.05 * introContent)
            transform: Translate { y: root.s(20) * (1.0 - introContent) }

            // =================================================================
            // TAB 0: ABOUT
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 0
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ListModel {
                    id: systemModel
                    ListElement { pkg: "Hyprland";    role: "Wayland Compositor";     icon: "";  clr: "blue";   link: "https://hyprland.org/" }
                    ListElement { pkg: "Quickshell";  role: "Desktop Shell (QML)";    icon: "󰣆"; clr: "mauve";  link: "https://git.outfoxxed.me/outfoxxed/quickshell" }
                    ListElement { pkg: "Walker";      role: "App Launcher";           icon: "";  clr: "green";  link: "https://github.com/abenz1267/walker" }
                    ListElement { pkg: "Kitty";       role: "Terminal Emulator";       icon: "󰄛"; clr: "yellow"; link: "https://sw.kovidgoyal.net/kitty/" }
                    ListElement { pkg: "SwayNC";      role: "Notification Center";     icon: "󰂚"; clr: "pink";   link: "https://github.com/ErikReider/SwayNotificationCenter" }
                    ListElement { pkg: "Matugen";     role: "Material You Theming";    icon: "󰏘"; clr: "peach";  link: "https://github.com/InioX/matugen" }
                }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(20)

                    // Author block — JorisKooistra
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(80); radius: root.s(12)
                        color: authorMa.containsMouse ? Qt.alpha(root.surface1, 0.6) : Qt.alpha(root.surface0, 0.4)
                        border.color: authorMa.containsMouse ? root.mauve : root.surface1; border.width: 1
                        scale: authorMa.pressed ? 0.98 : (authorMa.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }

                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(15)
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(48); height: root.s(48); radius: root.s(10)
                                color: root.surface0; border.color: root.surface2; border.width: 1
                                Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(28); color: root.text }
                            }
                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter; spacing: root.s(2)
                                Text { text: "Created by"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; font.weight: Font.Medium }
                                Row {
                                    spacing: root.s(1)
                                    Repeater {
                                        model: [
                                            { l: "J", c: root.blue },
                                            { l: "o", c: root.sapphire },
                                            { l: "r", c: root.green },
                                            { l: "i", c: root.yellow },
                                            { l: "s", c: root.peach },
                                            { l: "K", c: root.red },
                                            { l: "o", c: root.mauve },
                                            { l: "o", c: root.pink },
                                            { l: "i", c: root.blue },
                                            { l: "s", c: root.sapphire },
                                            { l: "t", c: root.green },
                                            { l: "r", c: root.yellow },
                                            { l: "a", c: root.peach }
                                        ]
                                        Text {
                                            text: modelData.l; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(22); color: modelData.c
                                            property real hoverOffset: authorMa.containsMouse ? root.s(-4) : 0
                                            transform: Translate { y: hoverOffset }
                                            Behavior on hoverOffset { NumberAnimation { duration: 300 + (index * 25); easing.type: Easing.OutBack } }
                                        }
                                    }
                                }
                            }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: root.s(32); height: root.s(32); radius: root.s(8)
                                color: authorMa.containsMouse ? root.surface1 : "transparent"
                                Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: authorMa.containsMouse ? root.mauve : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                            }
                        }
                        MouseArea { id: authorMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/JorisKooistra/kingstra-dots"]) }
                    }

                    Text { text: "System Components"; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(28); color: root.text; Layout.topMargin: root.s(5) }

                    GridLayout {
                        Layout.fillWidth: true; columns: 2; rowSpacing: root.s(15); columnSpacing: root.s(15)
                        Repeater {
                            model: systemModel
                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: root.s(70); radius: root.s(10)
                                color: sysCardMa.containsMouse ? Qt.alpha(root[model.clr], 0.14) : root.popupPanelFill
                                border.color: sysCardMa.containsMouse ? root[model.clr] : root.surface1; border.width: 1
                                scale: sysCardMa.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on border.color { ColorAnimation { duration: 200 } }

                                Item {
                                    anchors.fill: parent; anchors.margins: root.s(15)
                                    Item {
                                        id: sysIconBox; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        width: root.s(40); height: root.s(40)
                                        Text { anchors.centerIn: parent; text: model.icon; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(24); color: root[model.clr] }
                                    }
                                    Column {
                                        anchors.left: sysIconBox.right; anchors.leftMargin: root.s(15); anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: root.s(2)
                                        Text { text: model.pkg; font.family: root.displayFontFamily; font.weight: root.themedFontWeight; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(15); color: root.text }
                                        Text { text: model.role; font.family: root.uiFontFamily; font.letterSpacing: root.themedLetterSpacing; font.pixelSize: root.s(12); color: root.subtext0 }
                                    }
                                }
                                MouseArea { id: sysCardMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Quickshell.execDetached(["xdg-open", model.link]) }
                            }
                        }
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignLeft
                        Layout.preferredWidth: root.s(220)
                        Layout.preferredHeight: root.s(48)
                        radius: root.themedInnerRadius
                        color: updateMa.containsMouse ? Qt.alpha(root.green, 0.14) : root.popupPanelFill
                        border.color: updateMa.containsMouse ? root.green : root.surface1
                        border.width: 1
                        scale: updateMa.pressed ? 0.98 : (updateMa.containsMouse ? 1.01 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: root.s(12)
                            spacing: root.s(10)

                            Text {
                                text: "󰚰"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: root.s(18)
                                color: updateMa.containsMouse ? root.green : root.subtext0
                            }
                            Text {
                                text: "Update uitvoeren"
                                font.family: root.uiFontFamily
                                font.weight: root.themedFontWeight
                                font.letterSpacing: root.themedLetterSpacing
                                font.pixelSize: root.s(12)
                                color: root.text
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            id: updateMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.runUpdateBootstrap()
                        }
                    }

                    Item { Layout.fillHeight: true }
                }
            }

            // =================================================================
            // TAB 1: KEYBINDINGS
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Keybindings"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text; Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: root.s(36); Layout.preferredHeight: root.s(36); radius: root.s(8)
                            color: reloadMa.containsMouse ? root.surface1 : Qt.alpha(root.surface0, 0.6)
                            border.color: reloadMa.containsMouse ? root.blue : root.surface1; border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰑓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: reloadMa.containsMouse ? root.blue : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                            MouseArea { id: reloadMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { keybindsModel.clear(); loadKeybindsProc.running = true; } }
                        }
                    }

                    // Search bar
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(40); radius: root.s(8)
                        color: root.surface0; border.color: filterInput.activeFocus ? root.blue : root.surface2; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.subtext0 }
                            TextInput {
                                id: filterInput; Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                clip: true; selectByMouse: true
                                onTextChanged: root.keybindFilter = text.toLowerCase()
                                Text { text: "Filter keybindings..."; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Keybind list
                    ScrollView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentWidth: availableWidth; clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: parent.width; spacing: root.s(6)

                            Repeater {
                                model: keybindsModel

                                Rectangle {
                                    id: bindRow
                                    Layout.fillWidth: true; radius: root.s(8)
                                    visible: {
                                        if (!root.keybindFilter) return true;
                                        var txt = (model.mods + " " + model.key + " " + model.d + " " + model.args + " " + model.label).toLowerCase();
                                        return txt.indexOf(root.keybindFilter) >= 0;
                                    }
                                    Layout.preferredHeight: visible ? (isEditing ? root.s(90) : root.s(46)) : 0
                                    Layout.topMargin: visible ? 0 : -root.s(6)

                                    property bool isEditing: root.editingIndex === index
                                    property string editMods: model.mods
                                    property string editKey: model.key

                                    color: isEditing ? Qt.alpha(root.blue, 0.08) : (bindMa.containsMouse ? root.surface1 : Qt.alpha(root.surface0, 0.4))
                                    border.color: isEditing ? root.blue : (bindMa.containsMouse ? root.peach : "transparent"); border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

                                    ColumnLayout {
                                        anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(6)

                                        // Display row
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: root.s(10)

                                            // Key badges
                                            Item {
                                                Layout.preferredWidth: root.s(200); Layout.minimumWidth: root.s(200)
                                                Layout.fillHeight: true

                                                // Unbound
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !model.bound
                                                    width: unboundTxt.implicitWidth + root.s(16); height: root.s(26); radius: root.s(4)
                                                    color: Qt.alpha(root.overlay0, 0.12); border.color: Qt.alpha(root.overlay0, 0.3); border.width: 1
                                                    Text { id: unboundTxt; anchors.centerIn: parent; text: "Niet ingesteld"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0 }
                                                }

                                                // Bound
                                                Row {
                                                    anchors.verticalCenter: parent.verticalCenter; spacing: root.s(6)
                                                    visible: model.bound
                                                    Rectangle {
                                                        width: k1t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k1t; anchors.centerIn: parent; text: model.mods; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                    Text { text: "+"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.overlay0; anchors.verticalCenter: parent.verticalCenter; visible: model.key !== "" }
                                                    Rectangle {
                                                        visible: model.key !== ""
                                                        width: k2t.implicitWidth + root.s(14); height: root.s(26); radius: root.s(4)
                                                        color: root.surface0; border.color: root.surface2; border.width: 1
                                                        Text { id: k2t; anchors.centerIn: parent; text: model.key; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.peach }
                                                    }
                                                }
                                            }

                                            // Action label
                                            Text {
                                                text: model.label || (model.d + (model.args ? " " + model.args : ""))
                                                font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                                Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                                elide: Text.ElideRight; clip: true
                                            }

                                            // Edit icon
                                            Rectangle {
                                                Layout.preferredWidth: root.s(28); Layout.preferredHeight: root.s(28); radius: root.s(6)
                                                color: editBtnMa.containsMouse ? root.surface1 : "transparent"
                                                visible: !bindRow.isEditing
                                                Text { anchors.centerIn: parent; text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: editBtnMa.containsMouse ? root.blue : root.subtext0 }
                                                MouseArea { id: editBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { bindRow.editMods = model.mods; bindRow.editKey = model.key; root.editingIndex = index; } }
                                            }
                                        }

                                        // Edit row (only visible when editing)
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: root.s(8)
                                            visible: bindRow.isEditing

                                            Text { text: "Mods:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(200); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: modsEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: modsEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editMods; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editMods = text
                                                }
                                            }

                                            Text { text: "Key:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0 }
                                            Rectangle {
                                                Layout.preferredWidth: root.s(120); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: root.surface0; border.color: keyEdit.activeFocus ? root.blue : root.surface2; border.width: 1
                                                TextInput {
                                                    id: keyEdit; anchors.fill: parent; anchors.margins: root.s(6)
                                                    verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.text
                                                    text: bindRow.editKey; selectByMouse: true; clip: true
                                                    onTextChanged: bindRow.editKey = text
                                                }
                                            }

                                            Item { Layout.fillWidth: true }

                                            // Save button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: saveBMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                                Text { anchors.centerIn: parent; text: "Opslaan"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.base }
                                                MouseArea { id: saveBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveKeybind(index, bindRow.editMods, bindRow.editKey) }
                                            }
                                            // Remove button (alleen bij bestaande bind)
                                            Rectangle {
                                                Layout.preferredWidth: root.s(30); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                visible: model.bound
                                                color: removeBMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: removeBMa.containsMouse ? root.red : root.surface1; border.width: 1
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                                Text { anchors.centerIn: parent; text: "󰆴"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: removeBMa.containsMouse ? root.red : root.subtext0; Behavior on color { ColorAnimation { duration: 150 } } }
                                                MouseArea { id: removeBMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.removeKeybind(index) }
                                            }
                                            // Cancel button
                                            Rectangle {
                                                Layout.preferredWidth: root.s(70); Layout.preferredHeight: root.s(30); radius: root.s(4)
                                                color: cancelMa.containsMouse ? Qt.alpha(root.red, 0.15) : "transparent"
                                                border.color: root.surface1; border.width: 1
                                                Text { anchors.centerIn: parent; text: "Annuleer"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                                MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.editingIndex = -1 }
                                            }
                                        }
                                    }

                                    MouseArea { id: bindMa; anchors.fill: parent; hoverEnabled: true; z: -1 }
                                }
                            }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 2: WEATHER & TIME
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 2
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: root.s(20); spacing: root.s(15)

                    Text { text: "Weather & Time"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }

                    // ---- DATE & TIME FORMAT ----
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(180); radius: root.s(12)
                        color: Qt.alpha(root.surface0, 0.4); border.color: root.surface1; border.width: 1

                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: root.s(15); spacing: root.s(12)

                            RowLayout {
                                spacing: root.s(8)
                                Text { text: "󰥔"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.blue }
                                Text { text: "Date & Time Format"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                            }

                            Text { text: "Qt format strings — e.g. HH:mm (24h), hh:mm AP (12h), dddd d MMMM (Monday 7 April)"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(15)

                                // Time format
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(4)
                                    Text { text: "Time format"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                        color: root.surface0; border.color: timeFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        TextInput {
                                            id: timeFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                            verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                            text: root.settingsData.timeFormat || "hh:mm:ss AP"; selectByMouse: true; clip: true
                                        }
                                    }
                                }

                                // Date format
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: root.s(4)
                                    Text { text: "Date format"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: root.s(38); radius: root.s(6)
                                        color: root.surface0; border.color: dateFmtInput.activeFocus ? root.blue : root.surface2; border.width: 1
                                        Behavior on border.color { ColorAnimation { duration: 150 } }
                                        TextInput {
                                            id: dateFmtInput; anchors.fill: parent; anchors.margins: root.s(8)
                                            verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                            text: root.settingsData.dateFormat || "dddd, MMMM dd"; selectByMouse: true; clip: true
                                        }
                                    }
                                }
                            }

                            // Preview
                            RowLayout {
                                Layout.fillWidth: true; spacing: root.s(10)
                                Text { text: "Preview:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0 }
                                Text {
                                    property string preview: Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text)
                                    text: preview; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.peach
                                    Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.preview = Qt.formatDateTime(new Date(), timeFmtInput.text) + "  ·  " + Qt.formatDateTime(new Date(), dateFmtInput.text) }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(30); radius: root.s(6)
                                    color: dtSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                                    scale: dtSaveMa.pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "Save"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
                                    MouseArea { id: dtSaveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveSettings(timeFmtInput.text, dateFmtInput.text) }
                                }
                            }
                        }
                    }

                    // ---- SEPARATOR ----
                    Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                    // ---- WEATHER API CONFIG ----
                    RowLayout {
                        spacing: root.s(8)
                        Text { text: "󰖐"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(20); color: root.yellow }
                        Text { text: "Weather API"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(15); color: root.text }
                    }

                    Text { text: "Enter your OpenWeatherMap API key and coordinates."; font.family: "JetBrains Mono"; font.pixelSize: root.s(12); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                    // API Key
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                        color: root.surface0; border.color: apiKeyInput.activeFocus ? root.blue : root.surface2; border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 150 } }
                        RowLayout {
                            anchors.fill: parent; anchors.margins: root.s(10); spacing: root.s(10)
                            Text { text: "󰌆"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.subtext0 }
                            TextInput {
                                id: apiKeyInput; Layout.fillWidth: true; Layout.fillHeight: true
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text
                                clip: true; selectByMouse: true; echoMode: TextInput.Password
                                Text { text: "OpenWeather API Key..."; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Coordinates
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(15)
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: root.surface0; border.color: latInput.activeFocus ? root.peach : root.surface2; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            TextInput {
                                id: latInput; anchors.fill: parent; anchors.margins: root.s(10)
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                Text { text: "Latitude (e.g. 52.3676)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: root.surface0; border.color: lonInput.activeFocus ? root.peach : root.surface2; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            TextInput {
                                id: lonInput; anchors.fill: parent; anchors.margins: root.s(10)
                                verticalAlignment: TextInput.AlignVCenter; font.family: "JetBrains Mono"; font.pixelSize: root.s(13); color: root.text; clip: true; selectByMouse: true
                                Text { text: "Longitude (e.g. 4.9041)"; color: root.subtext0; visible: !parent.text && !parent.activeFocus; font: parent.font; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }

                    // Units
                    RowLayout {
                        Layout.fillWidth: true; spacing: root.s(15)
                        Text { text: "Units:"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                        Repeater {
                            model: ["metric", "imperial", "standard"]
                            Rectangle {
                                Layout.preferredWidth: root.s(80); Layout.preferredHeight: root.s(32); radius: root.s(6)
                                color: root.selectedUnit === modelData ? Qt.alpha(root.mauve, 0.2) : "transparent"
                                border.color: root.selectedUnit === modelData ? root.mauve : root.surface1; border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: modelData; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.capitalization: Font.Capitalize; color: root.selectedUnit === modelData ? root.mauve : root.subtext0 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedUnit = modelData }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    // Save weather button
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: root.s(160); Layout.preferredHeight: root.s(42); radius: root.s(8)
                            color: wSaveMa.containsMouse ? Qt.alpha(root.green, 0.8) : root.green
                            scale: wSaveMa.pressed ? 0.95 : (wSaveMa.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                            RowLayout {
                                anchors.centerIn: parent; spacing: root.s(8)
                                Text { text: "󰆓"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.base }
                                Text { text: "Save Weather"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(14); color: root.base }
                            }
                            MouseArea { id: wSaveMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.saveWeatherConfig() }
                        }
                    }
                }
            }

            // =================================================================
            // TAB 3: THEME (MATUGEN)
            // =================================================================
            Item {
                anchors.fill: parent
                visible: root.currentTab === 3
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                QtObject {
                    id: themeCarousel
                    property string selectedThemeId: ""
                    property var selectedThemeData: ({})
                    property bool isApplying: false

                    function applySelectedTheme() {
                        if (themeCarouselLoader.item && themeCarouselLoader.item.applySelectedTheme) {
                            themeCarouselLoader.item.applySelectedTheme();
                        }
                    }
                }

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: root.s(20)
                    clip: true

                    ColumnLayout {
                        width: parent.availableWidth !== undefined ? parent.availableWidth : parent.width
                        spacing: root.s(15)

                        Text { text: "Theming Engine"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: root.s(28); color: root.text }
                        Text { text: "Kies een thema, bekijk direct fonts, icons en Matugen-scene, en pas het daarna expliciet toe."; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.s(12)

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(92)
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.ambientPurple
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: root.s(14); spacing: root.s(12)

                                    Rectangle {
                                        width: root.s(52); height: root.s(52); radius: root.s(12)
                                        color: root.surface1
                                        Text { anchors.centerIn: parent; text: root.activeThemeIcon; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.s(24); color: root.ambientPurple }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(2)
                                        Text { text: "Actief thema"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: root.activeThemeName || "Geen thema actief"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: root.activeThemeId || ""; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: root.s(92)
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.blue
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent; anchors.margins: root.s(14); spacing: root.s(12)

                                    Rectangle {
                                        width: root.s(52); height: root.s(52); radius: root.s(12)
                                        color: root.surface1
                                        Text { anchors.centerIn: parent; text: themeCarousel.selectedThemeData.icon || "󰏘"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: root.s(24); color: root.blue }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: root.s(2)
                                        Text { text: "Geselecteerd"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0 }
                                        Text { text: themeCarousel.selectedThemeData.name || "Selecteer een thema"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }
                                        Text { text: themeCarousel.selectedThemeId || ""; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.overlay0; visible: text !== "" }
                                    }
                                }
                            }

                            ColumnLayout {
                                spacing: root.s(8)

                                Rectangle {
                                    Layout.preferredWidth: root.s(170); Layout.preferredHeight: root.s(42); radius: root.s(8)
                                    color: themeApplyMa.containsMouse ? Qt.alpha(root.green, 0.82) : root.green
                                    opacity: themeCarousel.selectedThemeId === "" || themeCarousel.isApplying ? 0.55 : 1.0
                                    scale: themeApplyMa.pressed ? 0.97 : (themeApplyMa.containsMouse ? 1.02 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: root.s(6)
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "󰄬" : "󰑐"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(16); color: root.base }
                                        Text { text: themeCarousel.selectedThemeId === root.activeThemeId ? "Al actief" : "Thema toepassen"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(12); color: root.base }
                                    }
                                    MouseArea {
                                        id: themeApplyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        enabled: themeCarousel.selectedThemeId !== "" && !themeCarousel.isApplying && themeCarousel.selectedThemeId !== root.activeThemeId
                                        onClicked: themeCarousel.applySelectedTheme()
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: root.s(170); Layout.preferredHeight: root.s(36); radius: root.s(8)
                                    color: themeFullscreenMa.containsMouse ? Qt.alpha(root.mauve, 0.2) : Qt.alpha(root.surface1, 0.65)
                                    border.color: themeFullscreenMa.containsMouse ? root.mauve : root.surface2
                                    border.width: 1
                                    RowLayout {
                                        anchors.centerIn: parent; spacing: root.s(6)
                                        Text { text: "󰍹"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: root.text }
                                        Text { text: "Vol scherm"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(11); color: root.text }
                                    }
                                    MouseArea {
                                        id: themeFullscreenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "theme"])
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.s(290)

                            Loader {
                                id: themeCarouselLoader
                                anchors.fill: parent
                                source: Qt.resolvedUrl("../themes/ThemeCarousel.qml")

                                onLoaded: {
                                    if (item) {
                                        item.embedded = true;
                                        themeCarousel.selectedThemeId = item.selectedThemeId || "";
                                        themeCarousel.selectedThemeData = item.selectedThemeData || ({});
                                        themeCarousel.isApplying = !!item.isApplying;
                                    }
                                }
                            }

                            Connections {
                                target: themeCarouselLoader.item
                                ignoreUnknownSignals: true

                                function onThemeSelected(themeId) {
                                    themeCarousel.selectedThemeId = themeId || "";
                                    themeCarousel.selectedThemeData = themeCarouselLoader.item && themeCarouselLoader.item.selectedThemeData ? themeCarouselLoader.item.selectedThemeData : ({});
                                }

                                function onThemeApplied(themeId) {
                                    themeCarousel.selectedThemeId = themeId || themeCarousel.selectedThemeId;
                                    themeCarousel.selectedThemeData = themeCarouselLoader.item && themeCarouselLoader.item.selectedThemeData ? themeCarouselLoader.item.selectedThemeData : themeCarousel.selectedThemeData;
                                    themeCarousel.isApplying = false;
                                    root.refreshActiveTheme();
                                }
                            }

                            Timer {
                                interval: 120
                                running: true
                                repeat: true
                                onTriggered: {
                                    if (themeCarouselLoader.item) {
                                        themeCarousel.isApplying = !!themeCarouselLoader.item.isApplying;
                                        if (themeCarousel.selectedThemeId === "" && themeCarouselLoader.item.selectedThemeId) {
                                            themeCarousel.selectedThemeId = themeCarouselLoader.item.selectedThemeId;
                                            themeCarousel.selectedThemeData = themeCarouselLoader.item.selectedThemeData || ({});
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                visible: themeCarouselLoader.status === Loader.Error
                                anchors.fill: parent
                                radius: root.s(12)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.red
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "Theme carousel kon niet geladen worden"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: root.s(12)
                                    color: root.text
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        Text { text: "Preview details"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(16); color: root.text }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: width > root.s(760) ? 2 : 1
                            rowSpacing: root.s(10)
                            columnSpacing: root.s(10)

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: appearanceInfo.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                ColumnLayout {
                                    id: appearanceInfo
                                    anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(8)
                                    Text { text: "Uiterlijk"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    Repeater {
                                        model: [
                                            { label: "Hoekrondheid", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "border_radius", "—") + "px" },
                                            { label: "Randdikte", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "border_width", "—") + "px" },
                                            { label: "Binnenmarge", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "gaps_in", "—") + "px" },
                                            { label: "Buitenmarge", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "gaps_out", "—") + "px" },
                                            { label: "Blur size", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "blur_size", "—") },
                                            { label: "Blur passes", value: root.themeValue(themeCarousel.selectedThemeData, "appearance", "blur_passes", "—") }
                                        ]
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: modelData.label; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                            Text { text: modelData.value; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: fontsInfo.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                ColumnLayout {
                                    id: fontsInfo
                                    anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(8)
                                    Text { text: "Fonts"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "UI font"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "fonts", "ui_font", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "UI size"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "fonts", "ui_font_size", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Mono font"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "fonts", "mono_font", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Mono size"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "fonts", "mono_font_size", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: iconsInfo.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                ColumnLayout {
                                    id: iconsInfo
                                    anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(8)
                                    Text { text: "Icons"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Icon theme"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "icons", "icon_theme", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    Text { text: "Wordt doorgezet naar GTK, Qt6CT en desktop-interface bij toepassen van het thema."; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: matugenInfo.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                ColumnLayout {
                                    id: matugenInfo
                                    anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(8)
                                    Text { text: "Matugen scene"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Scene"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.formatSchemeLabel(root.themeValue(themeCarousel.selectedThemeData, "matugen", "scheme_type", "scheme-tonal-spot")); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Color index"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "matugen", "color_index", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Contrast"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "matugen", "contrast", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: shellInfo.implicitHeight + root.s(24)
                                radius: root.s(10)
                                color: Qt.alpha(root.surface0, 0.45)
                                border.color: root.surface1
                                border.width: 1

                                ColumnLayout {
                                    id: shellInfo
                                    anchors.fill: parent; anchors.margins: root.s(12); spacing: root.s(8)
                                    Text { text: "Shell"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(13); color: root.text }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Bar height"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "quickshell", "bar_height", "—") + "px"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "Bar position"; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.subtext0; Layout.fillWidth: true }
                                        Text { text: root.themeValue(themeCarousel.selectedThemeData, "quickshell", "bar_position", "—"); font.family: "JetBrains Mono"; font.pixelSize: root.s(11); font.weight: Font.Bold; color: root.text }
                                    }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: root.surface1 }

                        RowLayout {
                            spacing: root.s(8)
                            Text { text: "󰇚"; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(18); color: root.ambientPurple }
                            Text { text: "Matugen Pipeline"; font.family: "JetBrains Mono"; font.weight: Font.Bold; font.pixelSize: root.s(14); color: root.text }
                        }

                        Text { text: "Bij toepassen van een thema worden de huidige wallpaper-kleuren opnieuw door Matugen gerenderd en in deze templates geïnjecteerd:"; font.family: "JetBrains Mono"; font.pixelSize: root.s(11); color: root.subtext0; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        GridLayout {
                            Layout.fillWidth: true; columns: 3; rowSpacing: root.s(6); columnSpacing: root.s(8)
                            Repeater {
                                model: [
                                    { f: "kitty/colors.conf", i: "󰄛", c: "yellow" },
                                    { f: "quickshell/colors.json", i: "󰣆", c: "mauve" },
                                    { f: "swaync/colors.css", i: "󰂚", c: "pink" },
                                    { f: "walker/colors.css", i: "󰀻", c: "green" },
                                    { f: "zsh/omp-colors.toml", i: "󱆃", c: "blue" },
                                    { f: "hypr/colors.conf", i: "󰆍", c: "peach" }
                                ]
                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: root.s(36); radius: root.s(6)
                                    color: tplMa.containsMouse ? Qt.alpha(root[modelData.c], 0.1) : root.surface0
                                    border.color: tplMa.containsMouse ? root[modelData.c] : "transparent"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }
                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: root.s(8); spacing: root.s(8)
                                        Text { text: modelData.i; font.family: "Iosevka Nerd Font"; font.pixelSize: root.s(14); color: root[modelData.c] }
                                        Text { text: modelData.f; font.family: "JetBrains Mono"; font.pixelSize: root.s(10); color: root.text; Layout.fillWidth: true }
                                    }
                                    MouseArea { id: tplMa; anchors.fill: parent; hoverEnabled: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
