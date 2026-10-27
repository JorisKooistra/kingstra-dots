import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import ".."
import "../settings/SettingIndex.js" as SettingIndex

// App-launcher die vanaf de onderkant van het scherm uitgroeit, in dezelfde
// chrome-taal als de bar. De desktop-entries komen uit list-apps.py; de
// Quickshell DesktopEntries-API levert op dit systeem geen resultaten.
//
// FocusScope, geen Item: het paneel wordt via een Loader in de PanelHost
// geladen en een Loader geeft toetsenbordfocus niet vanzelf door aan zijn
// inhoud. Daardoor bleef de focus op de PanelHost hangen — Escape kwam wel
// aan, maar getypte tekens bereikten het zoekveld nooit. Als scope kan de
// host hier focus aan geven, die dan bij searchInput (focus: true) landt.
FocusScope {
    id: root

    MatugenColors { id: mocha }

    property var allApps: []
    property var usageCounts: ({})
    property var lastLaunchTimes: ({})
    property var pinnedIds: []
    property int maxPinnedApps: 3
    property string query: ""
    property int selectedIndex: 0
    readonly property var quickActions: [
        { icon: "󰒓", label: "Instellingen", detail: "Shell en systeem", target: "settings" },
        { icon: "󰏘", label: "Thema", detail: "Kleur en vorm · instellingen", target: "settings", page: "thema" },
        { icon: "󰓃", label: "Media", detail: "Nu afspelen", target: "music" },
        { icon: "󰍹", label: "Schermen", detail: "Indeling en profielen", target: "monitors" },
        { icon: "󰊢", label: "Overview", detail: "Werkruimten", target: "overview" },
        { icon: "󰍛", label: "Systeemmonitor", detail: "Open btop", target: "btop" },
        { icon: "󰄀", label: "Klembord", detail: "Doorzoek recente items", target: "clipboard" },
        { icon: "󰖯", label: "Vensters", detail: "Wissel naar een open app · Super + W", target: "windows" },
        { icon: "󰂚", label: "Meldingen", detail: "Inbox en niet storen", target: "notifications" },
        { icon: "󰌾", label: "Vergrendelen", detail: "Huidige sessie", target: "lock" }
    ]

    // --- Voorvoegsels, zoals Caelestia en DMS ---------------------------------
    // Het eerste teken kiest een modus; de rest is de zoekterm.
    readonly property var prefixModes: [
        { key: "=", icon: "󰃬", label: "rekenen" },
        { key: ">", icon: "󰆍", label: "commando" },
        { key: ":", icon: "󰞅", label: "emoji" },
        { key: "/", icon: "󰒓", label: "instelling" },
        { key: "?", icon: "󰖟", label: "web" },
        { key: "@", icon: "󰖯", label: "venster" }
    ]
    readonly property string prefix: {
        let c = String(query || "").charAt(0);
        return c !== "" && "=>:/?@".indexOf(c) !== -1 ? c : "";
    }
    readonly property string term: prefix !== "" ? String(query).substring(1).trim() : ""
    property var emojiResults: []
    property var windowResults: []

    readonly property var prefixResults: {
        let t = term;
        if (prefix === "=") {
            let v = root.calc(t);
            if (t === "") return [{ icon: "󰃬", label: "Typ een som", detail: "Bijv. 12*(3+4) of 2^10", kind: "none" }];
            if (v === "") return [{ icon: "󰃬", label: "Geen geldige som", detail: t, kind: "none" }];
            return [{ icon: "󰃬", label: "= " + v, detail: "Enter kopieert de uitkomst", kind: "copy", value: v }];
        }
        if (prefix === ">") {
            if (t === "") return [{ icon: "󰆍", label: "Typ een commando", detail: "Bijv. > htop", kind: "none" }];
            return [
                { icon: "󰆍", label: t, detail: "Uitvoeren in een terminal", kind: "term", value: t },
                { icon: "󰐊", label: t, detail: "Op de achtergrond uitvoeren", kind: "run", value: t }
            ];
        }
        if (prefix === ":") {
            if (t === "") return [{ icon: "󰞅", label: "Typ een woord", detail: "Bijv. :hart of :rocket", kind: "none" }];
            return emojiResults.map(e => ({ icon: e.char, label: e.name, detail: "Enter kopieert", kind: "copy", value: e.char, emoji: true }));
        }
        if (prefix === "/") {
            let hits = t === "" ? SettingIndex.entries.slice(0, 10) : SettingIndex.search(t, 10);
            return hits.map(e => ({ icon: "󰒓", label: e.label, detail: e.where, kind: "setting", value: SettingIndex.deepLink(e) }));
        }
        if (prefix === "?") {
            if (t === "") return [{ icon: "󰖟", label: "Typ een zoekterm", detail: "Bijv. ?hyprland gestures", kind: "none" }];
            let q = encodeURIComponent(t);
            return [
                { icon: "󰖟", label: "Zoek op het web: " + t, detail: "DuckDuckGo", kind: "url", value: "https://duckduckgo.com/?q=" + q },
                { icon: "󰣇", label: "Zoek in de Arch Wiki: " + t, detail: "wiki.archlinux.org", kind: "url", value: "https://wiki.archlinux.org/index.php?search=" + q },
                { icon: "󰖬", label: "Zoek op Wikipedia: " + t, detail: "nl.wikipedia.org", kind: "url", value: "https://nl.wikipedia.org/w/index.php?search=" + q }
            ];
        }
        if (prefix === "@") {
            let n = t.toLowerCase();
            return windowResults
                .filter(w => n === "" || (String(w.title) + " " + String(w.className)).toLowerCase().indexOf(n) !== -1)
                .map(w => ({ icon: "󰖯", label: String(w.title), detail: String(w.className) + " · werkruimte " + w.workspace,
                             kind: "window", value: String(w.address), workspace: String(w.workspace) }));
        }
        return [];
    }
    onPrefixResultsChanged: if (prefix !== "") selectedIndex = 0
    onPrefixChanged: if (prefix === "@" && !windowProc.running) windowProc.running = true
    onTermChanged: if (prefix === ":") emojiDebounce.restart()

    // Kleine rekenmachine zonder eval: + - * / % ^ en haakjes.
    function calc(text) {
        let src = String(text || "").replace(/,/g, ".").replace(/×/g, "*").replace(/÷/g, "/").replace(/\s+/g, "");
        if (src === "" || !/^[0-9.+\-*\/%^()]+$/.test(src)) return "";
        let pos = 0;
        function peek() { return src.charAt(pos); }
        function number() {
            let start = pos;
            while (pos < src.length && /[0-9.]/.test(src.charAt(pos))) pos++;
            if (start === pos) throw "getal";
            return parseFloat(src.substring(start, pos));
        }
        function factor() {
            if (peek() === "-") { pos++; return -factor(); }
            if (peek() === "+") { pos++; return factor(); }
            let v;
            if (peek() === "(") {
                pos++;
                v = expr();
                if (peek() !== ")") throw "haakje";
                pos++;
            } else {
                v = number();
            }
            if (peek() === "^") { pos++; v = Math.pow(v, factor()); }
            return v;
        }
        function termP() {
            let v = factor();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                let op = src.charAt(pos++);
                let r = factor();
                v = op === "*" ? v * r : (op === "/" ? v / r : v % r);
            }
            return v;
        }
        function expr() {
            let v = termP();
            while (peek() === "+" || peek() === "-") {
                let op = src.charAt(pos++);
                let r = termP();
                v = op === "+" ? v + r : v - r;
            }
            return v;
        }
        try {
            let v = expr();
            if (pos !== src.length || !isFinite(v)) return "";
            return String(Math.round(v * 1e10) / 1e10);
        } catch (e) {
            return "";
        }
    }

    function runPrefixResult(item) {
        if (!item || item.kind === "none") return;
        if (item.kind === "copy") {
            Quickshell.execDetached(["wl-copy", String(item.value)]);
            Quickshell.execDetached(["notify-send", "-a", "Kingstra", "Gekopieerd", String(item.value)]);
        } else if (item.kind === "term") {
            Quickshell.execDetached(["kitty", "--hold", "bash", "-lc", String(item.value)]);
        } else if (item.kind === "run") {
            Quickshell.execDetached(["bash", "-lc", "setsid bash -lc \"$1\" >/dev/null 2>&1 &", "bash", String(item.value)]);
        } else if (item.kind === "setting") {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "open", "settings", String(item.value)]);
        } else if (item.kind === "url") {
            Quickshell.execDetached(["xdg-open", String(item.value)]);
        } else if (item.kind === "window") {
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/window-switcher.sh",
                "focus", String(item.value), String(item.workspace)]);
        }
        if (item.kind !== "setting") closePanel();
    }

    function activateSelected() {
        if (prefix !== "") runPrefixResult(prefixResults[selectedIndex]);
        else launch(filtered[selectedIndex]);
    }

    Timer {
        id: emojiDebounce
        interval: 140
        onTriggered: {
            if (root.prefix !== ":" || root.term === "") { root.emojiResults = []; return; }
            emojiProc.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/emoji-search.py", root.term];
            emojiProc.running = true;
        }
    }

    Process {
        id: emojiProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.emojiResults = JSON.parse(this.text); } catch (e) { root.emojiResults = []; }
            }
        }
    }

    Process {
        id: windowProc
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/window-switcher.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.windowResults = JSON.parse(this.text); } catch (e) { root.windowResults = []; }
            }
        }
    }

    readonly property color surfaceColor: {
        let f = mocha.crust;
        let a = mocha.primary;
        return Qt.rgba(f.r + (a.r - f.r) * 0.18,
                       f.g + (a.g - f.g) * 0.18,
                       f.b + (a.b - f.b) * 0.18,
                       1.0);
    }
    readonly property color rowHover: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.16)
    readonly property color rowActive: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.28)
    readonly property int panelCornerRadius: Math.max(18, ThemeConfig.styleWidgetRadius + 8)
    readonly property int controlCornerRadius: Math.max(12, Math.round(panelCornerRadius * 0.62))
    readonly property int rowCornerRadius: Math.max(12, Math.round(panelCornerRadius * 0.56))

    readonly property var filtered: {
        let q = root.normalizeSearch(query);
        if (q === "") return root.sortedApps(allApps);
        let scored = [];
        for (let i = 0; i < allApps.length; i++) {
            let a = allApps[i];
            let score = root.appScore(a, q);
            if (score > 0) scored.push({ app: a, score: score });
        }
        scored.sort((a, b) => {
            if (a.score !== b.score) return b.score - a.score;
            return root.compareApps(a.app, b.app);
        });
        return scored.map(r => r.app);
    }

    // Actions are first-class launcher results rather than static decoration.
    // This makes non-desktop tools such as btop discoverable through typing.
    readonly property var filteredActions: {
        let q = root.normalizeSearch(query);
        if (q === "") return [];
        let scored = [];
        for (let i = 0; i < quickActions.length; i++) {
            let action = quickActions[i];
            let score = Math.max(
                root.fieldScore(action.label, q, 5200),
                root.fieldScore(action.detail, q, 3000),
                root.fieldScore(action.target, q, 2800)
            );
            if (score > 0) scored.push({ action: action, score: score });
        }
        scored.sort((a, b) => b.score - a.score || String(a.action.label).localeCompare(String(b.action.label)));
        return scored.map(result => result.action);
    }

    onFilteredChanged: selectedIndex = 0

    function normalizeSearch(value) {
        return String(value || "")
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, " ")
            .trim()
            .replace(/\s+/g, " ");
    }

    function initials(value) {
        let text = normalizeSearch(value);
        if (text === "") return "";
        return text.split(" ").map(w => w.charAt(0)).join("");
    }

    function wordStartsWith(value, q) {
        let words = normalizeSearch(value).split(" ");
        for (let i = 0; i < words.length; i++) {
            if (words[i].indexOf(q) === 0) return true;
        }
        return false;
    }

    function subsequenceScore(value, q, base) {
        let text = normalizeSearch(value);
        if (text === "" || q === "") return 0;
        let qi = 0;
        let first = -1;
        let last = -1;
        let bonus = 0;
        let consecutive = 0;
        for (let i = 0; i < text.length && qi < q.length; i++) {
            if (text.charAt(i) !== q.charAt(qi)) continue;
            if (first < 0) first = i;
            if (i === 0 || text.charAt(i - 1) === " ") bonus += 80;
            if (last >= 0 && i === last + 1) {
                consecutive += 1;
                bonus += 16;
            }
            last = i;
            qi += 1;
        }
        if (qi !== q.length) return 0;
        let span = Math.max(1, last - first + 1);
        return base + bonus + consecutive * 8 - first * 10 - span * 5 - text.length;
    }

    function fieldScore(value, q, base) {
        let text = normalizeSearch(value);
        if (text === "") return 0;
        let acro = initials(text);
        if (text === q) return base + 5000;
        if (text.indexOf(q) === 0) return base + 4200 - text.length;
        if (wordStartsWith(text, q)) return base + 3600 - text.length;
        if (acro === q) return base + 3900 - text.length;
        if (acro.indexOf(q) === 0) return base + 3400 - text.length;
        if (text.indexOf(q) !== -1) return base + 2500 - text.indexOf(q) * 4 - text.length;
        return subsequenceScore(text, q, base + 1200);
    }

    function appScore(app, q) {
        return Math.max(
            fieldScore(app.name, q, 5000),
            fieldScore(app.genericName, q, 3600),
            fieldScore(app.startupClass, q, 3400),
            fieldScore(app.id, q, 3300),
            fieldScore(app.execString || app.exec, q, 3200),
            fieldScore(app.keywords, q, 2600),
            fieldScore(app.comment, q, 2200),
            fieldScore(app.categories, q, 1400)
        );
    }

    function launchCount(app) {
        if (!app || !app.id || !usageCounts) return 0;
        let count = usageCounts[app.id];
        return count === undefined ? 0 : Number(count);
    }

    function pinIndex(app) {
        if (!app || !app.id || !pinnedIds) return -1;
        return pinnedIds.indexOf(app.id);
    }

    function isPinned(app) {
        return pinIndex(app) >= 0;
    }

    function compareApps(a, b) {
        let ap = pinIndex(a);
        let bp = pinIndex(b);
        if (ap !== bp) {
            if (ap < 0) return 1;
            if (bp < 0) return -1;
            return ap - bp;
        }

        let ac = launchCount(a);
        let bc = launchCount(b);
        if (ac !== bc) return bc - ac;

        let at = Number((a && a.id && lastLaunchTimes[a.id]) || 0);
        let bt = Number((b && b.id && lastLaunchTimes[b.id]) || 0);
        if (at !== bt) return bt - at;

        return String(a.name || "").localeCompare(String(b.name || ""));
    }

    function sortedApps(apps) {
        let out = apps.slice();
        out.sort((a, b) => root.compareApps(a, b));
        return out;
    }

    function applyLauncherState(data) {
        if (!data || typeof data !== "object") {
            usageCounts = ({});
            lastLaunchTimes = ({});
            pinnedIds = [];
            return;
        }
        usageCounts = data.counts && typeof data.counts === "object" ? data.counts : ({});
        lastLaunchTimes = data.lastLaunched && typeof data.lastLaunched === "object" ? data.lastLaunched : ({});
        pinnedIds = Array.isArray(data.pins) ? data.pins.slice(0, maxPinnedApps) : [];
    }

    function applyLauncherStateJson(text) {
        try {
            applyLauncherState(JSON.parse(String(text || "{}")));
        } catch (e) {
            applyLauncherState({});
        }
    }

    Process {
        id: scanProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/list-apps.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allApps = JSON.parse(this.text);
                } catch (e) {
                    root.allApps = [];
                }
            }
        }
    }

    Process {
        id: stateLoadProc
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/launcher-state.py", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.applyLauncherStateJson(this.text)
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: if (!stateLoadProc.running) stateLoadProc.running = true
    }

    function closePanel() {
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"]);
    }

    function updateState(action, app) {
        if (!app || !app.id) return;
        let counts = Object.assign({}, usageCounts || {});
        let launches = Object.assign({}, lastLaunchTimes || {});
        let pins = pinnedIds ? pinnedIds.slice(0, maxPinnedApps) : [];
        if (action === "launch") {
            counts[app.id] = Number(counts[app.id] || 0) + 1;
            launches[app.id] = Math.round(Date.now() / 1000);
        } else if (action === "pin") {
            if (pins.indexOf(app.id) < 0 && pins.length < maxPinnedApps)
                pins.push(app.id);
        } else if (action === "unpin") {
            let idx = pins.indexOf(app.id);
            if (idx >= 0) pins.splice(idx, 1);
        }
        usageCounts = counts;
        lastLaunchTimes = launches;
        pinnedIds = pins;
        Quickshell.execDetached([
            "python3",
            Quickshell.env("HOME") + "/.config/quickshell/shellsurface/launcher-state.py",
            action,
            app.id
        ]);
    }

    function togglePin(app) {
        if (!app || !app.id) return;
        if (isPinned(app)) {
            updateState("unpin", app);
            return;
        }
        if (pinnedIds.length >= maxPinnedApps) return;
        updateState("pin", app);
    }

    function launch(app) {
        if (!app) return;
        updateState("launch", app);
        let cmd = app.terminal ? ("kitty -e " + app.exec) : app.exec;
        Quickshell.execDetached(["bash", "-lc", "setsid " + cmd + " >/dev/null 2>&1 &"]);
        closePanel();
    }

    function runQuickAction(action) {
        if (!action) return;
        if (action.target === "overview") {
            Quickshell.execDetached([
                "bash",
                Quickshell.env("HOME") + "/.config/hypr/scripts/overview-toggle.sh"
            ]);
        } else if (action.target === "btop") {
            Quickshell.execDetached(["kitty", "--title", "btop — Kingstra", "bash", "-lc", "exec btop"]);
        } else if (action.target === "lock") {
            Quickshell.execDetached(["loginctl", "lock-session"]);
        } else {
            Quickshell.execDetached([
                "bash",
                Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh",
                action.target === "settings" ? "open" : "toggle",
                action.target,
                action.page || ""
            ]);
        }
        closePanel();
    }

    function move(delta) {
        let n = prefix !== "" ? prefixResults.length : filtered.length;
        if (n === 0) return;
        selectedIndex = (selectedIndex + delta + n) % n;
        if (prefix !== "") prefixList.positionViewAtIndex(selectedIndex, ListView.Contain);
        else appList.positionViewAtIndex(selectedIndex, ListView.Contain);
    }

    Keys.onEscapePressed: event => {
        root.closePanel();
        event.accepted = true;
    }
    Keys.onDownPressed: event => { root.move(1); event.accepted = true; }
    Keys.onUpPressed: event => { root.move(-1); event.accepted = true; }
    Keys.onReturnPressed: event => { root.activateSelected(); event.accepted = true; }
    Keys.onEnterPressed: event => { root.activateSelected(); event.accepted = true; }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // --- Zoekveld --------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: root.controlCornerRadius
            color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.10)
            border.width: 1
            border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.35)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                Text {
                    text: "󱒟"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 16
                    color: mocha.primary
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    focus: true
                    color: mocha.text
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 15
                    selectByMouse: true
                    selectionColor: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.35)
                    onTextChanged: root.query = text
                    Component.onCompleted: forceActiveFocus()

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: searchInput.text === ""
                        text: "Zoek apps, of begin met = > : / ? @"
                        font: searchInput.font
                        color: mocha.subtext0
                    }
                }

                Text {
                    text: root.prefix !== ""
                        ? root.prefixResults.filter(r => r.kind !== "none").length + ""
                        : (root.filtered.length + root.filteredActions.length) + ""
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: 12
                    color: mocha.subtext0
                }
            }
        }

        // Een lege zoekopdracht is ook een rustig commandocentrum. De acties
        // gaan via dezelfde scripts als de railknoppen, dus er ontstaat geen
        // tweede pad voor shell-state of focusafhandeling.
        Flow {
            Layout.fillWidth: true
            // Empty query: a calm dashboard. Typed query: only matching
            // commands survive, directly above matching apps.
            visible: root.prefix === "" && (root.query === "" || root.filteredActions.length > 0)
            spacing: 8

            Repeater {
                model: root.query === "" ? root.quickActions : root.filteredActions

                delegate: Rectangle {
                    required property var modelData
                    width: Math.max(136, Math.min(178, actionContent.implicitWidth + 28))
                    height: 52
                    radius: root.rowCornerRadius
                    color: actionMouse.containsMouse
                        ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.22)
                        : Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.10)
                    border.width: 1
                    border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b,
                                          actionMouse.containsMouse ? 0.55 : 0.24)

                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }

                    RowLayout {
                        id: actionContent
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: modelData.icon
                            color: mocha.primary
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 17
                        }
                        ColumnLayout {
                            spacing: 0
                            Text {
                                text: modelData.label
                                color: mocha.text
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: modelData.detail
                                color: mocha.subtext0
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.runQuickAction(modelData)
                    }
                }
            }
        }

        // Voorvoegsels als kleine chips: klik zet het teken in het zoekveld.
        Flow {
            Layout.fillWidth: true
            visible: root.query === ""
            spacing: 6

            Repeater {
                model: root.prefixModes
                delegate: Rectangle {
                    required property var modelData
                    width: chipRow.implicitWidth + 18
                    height: 26
                    radius: 13
                    color: chipMouse.containsMouse
                        ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.20)
                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.key
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: mocha.primary
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext1
                        }
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = modelData.key;
                            searchInput.forceActiveFocus();
                        }
                    }
                }
            }
        }

        // --- Resultaten van een voorvoegsel ----------------------------------
        ListView {
            id: prefixList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.prefix !== ""
            clip: true
            model: root.prefixResults
            spacing: 2
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: prow
                required property int index
                required property var modelData
                readonly property bool current: index === root.selectedIndex && modelData.kind !== "none"

                width: prefixList.width
                height: 46
                radius: root.rowCornerRadius
                color: current ? root.rowActive : (prowMouse.containsMouse && modelData.kind !== "none" ? root.rowHover : "transparent")
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: prow.modelData.icon
                        font.family: prow.modelData.emoji ? ThemeConfig.textFont : ThemeConfig.iconFont
                        font.pixelSize: prow.modelData.emoji ? 20 : 17
                        color: mocha.primary
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: prow.modelData.label
                            elide: Text.ElideRight
                            font.family: prow.modelData.kind === "copy" && !prow.modelData.emoji ? ThemeConfig.monoFont : ThemeConfig.uiFont
                            font.pixelSize: 14
                            font.weight: prow.current ? Font.Bold : Font.DemiBold
                            color: prow.modelData.kind === "none" ? mocha.subtext0 : mocha.text
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: prow.modelData.detail || ""
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext0
                        }
                    }
                }

                MouseArea {
                    id: prowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: prow.modelData.kind === "none" ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: root.selectedIndex = prow.index
                    onClicked: root.runPrefixResult(prow.modelData)
                }
            }
        }

        // --- Resultaten ------------------------------------------------------
        ListView {
            id: appList
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.prefix === ""
            clip: true
            model: root.filtered
            spacing: 2
            currentIndex: root.selectedIndex
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData
                readonly property bool current: index === root.selectedIndex

                width: appList.width
                height: 46
                radius: root.rowCornerRadius
                color: current ? root.rowActive : (rowMouse.containsMouse ? root.rowHover : "transparent")

                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    z: 1

                    Item {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: row.modelData.icon ? Quickshell.iconPath(row.modelData.icon, true) : ""
                            visible: status === Image.Ready
                            sourceSize.width: 26
                            sourceSize.height: 26
                            smooth: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: appIcon.status !== Image.Ready
                            text: "󰄋"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 17
                            color: mocha.primary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.name
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 14
                            font.weight: row.current ? Font.Bold : Font.DemiBold
                            color: mocha.text
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: String(row.modelData.comment || "") !== ""
                            text: row.modelData.comment
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext0
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: 9
                        color: root.isPinned(row.modelData)
                            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.24)
                            : (pinMouse.containsMouse ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.14) : "transparent")
                        border.width: root.isPinned(row.modelData) ? 1 : 0
                        border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.45)
                        opacity: root.isPinned(row.modelData) || root.pinnedIds.length < root.maxPinnedApps ? 1.0 : 0.38

                        Text {
                            anchors.centerIn: parent
                            text: root.isPinned(row.modelData) ? "󰓎" : "󰐃"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 15
                            color: root.isPinned(row.modelData) ? mocha.primary : mocha.subtext0
                        }

                        MouseArea {
                            id: pinMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: root.isPinned(row.modelData) || root.pinnedIds.length < root.maxPinnedApps
                                         ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: mouse => {
                                mouse.accepted = true;
                                root.togglePin(row.modelData);
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    z: 0
                    hoverEnabled: true
                    onEntered: root.selectedIndex = row.index
                    onClicked: root.launch(row.modelData)
                }
            }
        }
    }
}
