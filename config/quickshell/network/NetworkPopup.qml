import QtQuick
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import "../"

// Netwerkpaneel: Wi-Fi, Bluetooth en bedraad netwerk in één paneel, in
// dezelfde vormtaal als Snelle instellingen en Geluid & media (afgeronde
// tegels, themakleuren uit Matugen, ThemeConfig-animaties). Vervangt de oude
// radar-weergave; alle functies daarvan zitten er nog in:
//  - Wi-Fi/Bluetooth aan en uit, met directe terugkoppeling;
//  - verbinden, verbreken, details van de verbinding (signaal, beveiliging,
//    IP, band; batterij, audioprofiel, MAC);
//  - bluetooth zoeken, koppelen en vergeten; foutmelding bij mislukken;
//  - Tab wisselt Wi-Fi ↔ Bluetooth, /tmp/qs_network_mode blijft de bron
//    voor de modus (qs_manager, Snelle instellingen);
//  - geluidjes bij schakelen, verbinden en verbreken;
//  - de laatste status uit de cache, zodat het paneel direct gevuld opent.
// Nieuw: wachtwoordveld voor onbekende beveiligde netwerken, opnieuw zoeken,
// opgeslagen netwerken vergeten en een terugknop naar Snelle instellingen.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    focus: true

    MatugenColors { id: mocha }

    signal panelSwitchRequested(string entryId)

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property bool matteStyle: ThemeConfig.styleFamily === "matte"
    readonly property int preferredPanelWidth: 420
    // Groeit mee met de lijst; daarboven scrollt de lijst binnen het paneel.
    readonly property int maxPanelHeight: 640
    readonly property int preferredPanelHeight: Math.min(maxPanelHeight,
        Math.ceil(pad * 2 + headerColumn.implicitHeight + 12 + bodyColumn.implicitHeight))

    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/quickshell/network"

    // Wi-Fi in de kleur van de Wi-Fi-tegel, Bluetooth in die van de
    // Bluetooth-tegel in Snelle instellingen; bedraad in groen (status).
    readonly property color wifiAccent: mocha.accent3
    readonly property color btAccent: mocha.accent1
    readonly property color ethAccent: mocha.green

    property string activeMode: "wifi"
    readonly property color activeColor: activeMode === "wifi" ? wifiAccent
        : (activeMode === "bt" ? btAccent : ethAccent)

    // ------------------------------------------------------------------------
    // Toetsen
    // ------------------------------------------------------------------------
    Shortcut {
        sequence: "Tab"
        onActivated: root.setMode(root.activeMode === "wifi" ? "bt" : "wifi")
    }

    function setMode(mode) {
        if (mode === root.activeMode) return;
        root.playSfx("switch.wav");
        root.activeMode = mode;
    }

    function playSfx(filename) {
        try {
            let path = Qt.resolvedUrl("sounds/" + filename).toString();
            if (path.indexOf("file://") === 0) path = path.substring(7);
            Quickshell.execDetached(["sh", "-c", "pw-play \"$1\" 2>/dev/null || paplay \"$1\" 2>/dev/null", "sh", path]);
        } catch (e) {}
    }

    // ------------------------------------------------------------------------
    // Cache en modusbestand
    // ------------------------------------------------------------------------
    Settings {
        id: cache
        category: "QS_NetworkWidget"
        property string lastWifiSsid: ""
        property string lastWifiJson: ""
        property string lastBtJson: ""
    }

    property bool ignoreNextModeFileUpdate: false

    Process {
        id: modeReader
        command: ["cat", "/tmp/qs_network_mode"]
        stdout: StdioCollector {
            onStreamFinished: {
                let mode = this.text.trim();
                if ((mode === "wifi" || mode === "bt" || mode === "eth") && root.activeMode !== mode) {
                    root.ignoreNextModeFileUpdate = true;
                    root.activeMode = mode;
                }
            }
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: if (!modeReader.running) modeReader.running = true
    }

    onActiveModeChanged: {
        if (!root.ignoreNextModeFileUpdate)
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" > /tmp/qs_network_mode", "sh", root.activeMode]);
        root.ignoreNextModeFileUpdate = false;
        root.wifiError = "";
        root.btError = "";
        root.passwordSsid = "";
        root.updateBtScan();
        root.pollNow();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", "[ -f /tmp/qs_network_mode ] || printf '%s\\n' \"$1\" > /tmp/qs_network_mode", "sh", root.activeMode]);
        if (cache.lastWifiJson !== "") processWifiJson(cache.lastWifiJson);
        if (cache.lastBtJson !== "") processBtJson(cache.lastBtJson);
        // Eén echte scan bij openen; de poller zelf gebruikt --rescan no.
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        root.updateBtScan();
    }

    // Bluetooth-zoeken loopt alleen zolang dit paneel op Bluetooth staat.
    // De oude popup liet het zoeken na sluiten aan staan.
    Component.onDestruction: {
        if (root.btScanning)
            Quickshell.execDetached(["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--scan-off"]);
    }

    // ------------------------------------------------------------------------
    // Modellen: ListModels houden de rijen vast tussen polls, zodat een open
    // wachtwoordveld of uitgeklapte details niet bij elke poll verdwijnen.
    // ------------------------------------------------------------------------
    ListModel { id: wifiModel }
    ListModel { id: btConnectedModel }
    ListModel { id: btPairedModel }
    ListModel { id: btFoundModel }

    function syncModel(listModel, rows) {
        for (let i = listModel.count - 1; i >= 0; i--) {
            let rid = listModel.get(i).rid;
            let keep = false;
            for (let j = 0; j < rows.length; j++) {
                if (rows[j].rid === rid) { keep = true; break; }
            }
            if (!keep) listModel.remove(i);
        }
        for (let i = 0; i < rows.length; i++) {
            let row = rows[i];
            let found = -1;
            for (let j = i; j < listModel.count; j++) {
                if (listModel.get(j).rid === row.rid) { found = j; break; }
            }
            if (found === -1) {
                listModel.insert(i, row);
            } else {
                if (found !== i) listModel.move(found, i, 1);
                let current = listModel.get(i);
                for (let key in row) {
                    if (current[key] !== row[key]) listModel.setProperty(i, key, row[key]);
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Wi-Fi
    // ------------------------------------------------------------------------
    property string wifiPower: "off"
    property bool wifiPowerPending: false
    property string expectedWifiPower: ""
    property var wifiConnected: null
    readonly property bool isWifiConn: !!wifiConnected && wifiConnected.ssid !== undefined
    property string wifiBusySsid: ""
    property bool wifiDisconnecting: false
    property string wifiError: ""
    property string passwordSsid: ""
    property bool wifiScanning: false

    Timer { id: wifiPendingReset; interval: 8000; onTriggered: { root.wifiPowerPending = false; root.expectedWifiPower = ""; } }
    Timer { id: wifiErrorTimer; interval: 6000; onTriggered: root.wifiError = "" }
    Timer { id: wifiScanDone; interval: 3500; onTriggered: { root.wifiScanning = false; root.pollNow(); } }

    onWifiConnectedChanged: {
        if (root.isWifiConn) cache.lastWifiSsid = root.wifiConnected.ssid;
    }

    function processWifiJson(textData) {
        if (textData === "") return;
        let data;
        try { data = JSON.parse(textData); } catch (e) { return; }

        let fetchedPower = data.power || "off";
        if (root.wifiPowerPending) {
            root.wifiPower = root.expectedWifiPower;
            if (fetchedPower === root.expectedWifiPower) {
                root.wifiPowerPending = false;
                wifiPendingReset.stop();
            }
        } else {
            root.wifiPower = fetchedPower;
            root.expectedWifiPower = "";
        }

        let connected = data.connected || null;
        if (JSON.stringify(root.wifiConnected) !== JSON.stringify(connected))
            root.wifiConnected = connected;
        if (!root.isWifiConn) root.wifiDisconnecting = false;

        let nets = Array.isArray(data.networks) ? data.networks : [];
        // Sterkste bovenaan, daarna op naam: zo staat wat je wilt meestal
        // boven zonder dat de lijst bij elke poll door elkaar springt.
        nets.sort((a, b) => {
            let sa = Math.round(parseInt(a.signal || 0) / 20);
            let sb = Math.round(parseInt(b.signal || 0) / 20);
            if (sa !== sb) return sb - sa;
            return String(a.ssid || "").localeCompare(String(b.ssid || ""));
        });
        let rows = [];
        for (let i = 0; i < nets.length && i < 30; i++) {
            let n = nets[i];
            rows.push({
                rid: String(n.id || n.ssid || ""),
                name: String(n.ssid || n.id || ""),
                icon: String(n.icon || "󰤨"),
                signal: parseInt(n.signal || 0) || 0,
                security: String(n.security || ""),
                known: n.known === true
            });
        }
        root.syncModel(wifiModel, rows);
    }

    Process {
        id: wifiPoller
        command: ["bash", root.scriptsDir + "/wifi_panel_logic.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                cache.lastWifiJson = txt;
                root.processWifiJson(txt);
            }
        }
    }

    property string wifiConnectTarget: ""
    property bool wifiConnectWithPassword: false

    Process {
        id: wifiConnectProc
        stderr: StdioCollector { id: wifiConnectErr }
        onExited: (exitCode, exitStatus) => {
            let ssid = root.wifiConnectTarget;
            root.wifiBusySsid = "";
            if (exitCode === 0) {
                root.playSfx("connect.wav");
                root.wifiError = "";
                root.passwordSsid = "";
            } else {
                let detail = String(wifiConnectErr.text || "").trim().split("\n")[0];
                let secrets = /secret|password|802-1x|psk/i.test(detail);
                root.wifiError = secrets || root.wifiConnectWithPassword
                    ? "Verbinden met " + ssid + " mislukt: controleer het wachtwoord"
                    : "Verbinden met " + ssid + " mislukt" + (detail !== "" ? " (" + detail.replace(/^Error:\s*/, "") + ")" : "");
                wifiErrorTimer.restart();
                // Beveiligd netwerk zonder (juist) wachtwoord: vraag erom.
                if (secrets || root.wifiConnectWithPassword) root.passwordSsid = ssid;
            }
            root.pollNow();
        }
    }

    function connectWifi(ssid, password) {
        if (wifiConnectProc.running || ssid === "") return;
        let cmd = ["nmcli", "device", "wifi", "connect", ssid];
        if (password !== undefined && password !== "") cmd.push("password", password);
        root.wifiConnectTarget = ssid;
        root.wifiConnectWithPassword = password !== undefined && password !== "";
        root.wifiBusySsid = ssid;
        root.wifiError = "";
        wifiConnectProc.command = cmd;
        wifiConnectProc.running = true;
        root.pollNow();
    }

    function disconnectWifi() {
        if (!root.isWifiConn || root.wifiDisconnecting) return;
        root.wifiDisconnecting = true;
        root.playSfx("disconnect.wav");
        Quickshell.execDetached(["sh", "-c", "nmcli device disconnect \"$(nmcli -t -f DEVICE,TYPE d | awk -F: '$2==\"wifi\"{print $1; exit}')\""]);
        root.pollNow();
    }

    function forgetWifi(ssid) {
        if (ssid === "") return;
        root.playSfx("disconnect.wav");
        Quickshell.execDetached(["nmcli", "connection", "delete", "id", ssid]);
        root.pollNow();
    }

    function rescanWifi() {
        if (root.wifiScanning || root.wifiPower !== "on") return;
        root.wifiScanning = true;
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        wifiScanDone.restart();
    }

    function bandLabel(freq) {
        let mhz = parseInt(String(freq || ""));
        if (isNaN(mhz)) return freq && freq !== "Unknown" ? String(freq) : "Onbekend";
        let band = mhz >= 5925 ? "6 GHz" : (mhz >= 4900 ? "5 GHz" : "2,4 GHz");
        return band + " · " + mhz + " MHz";
    }

    function securityLabel(sec) {
        let s = String(sec || "").trim();
        return s === "" || s === "--" ? "Open" : s;
    }

    function isSecured(sec) {
        let s = String(sec || "").trim();
        return s !== "" && s !== "--";
    }

    // ------------------------------------------------------------------------
    // Bluetooth
    // ------------------------------------------------------------------------
    property string btPower: "off"
    property bool btPowerPending: false
    property string expectedBtPower: ""
    property int btConnectedCount: 0
    property var btBusy: ({})
    property string btError: ""
    property bool btScanning: false

    Timer { id: btPendingReset; interval: 8000; onTriggered: { root.btPowerPending = false; root.expectedBtPower = ""; } }
    Timer { id: btErrorTimer; interval: 6000; onTriggered: root.btError = "" }

    function setBtBusy(mac, what) {
        let next = Object.assign({}, root.btBusy);
        if (what === "") delete next[mac];
        else next[mac] = what;
        root.btBusy = next;
    }

    function updateBtScan() {
        let want = root.activeMode === "bt" && root.btPower === "on";
        if (want === root.btScanning) return;
        root.btScanning = want;
        Quickshell.execDetached(["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", want ? "--scan-on" : "--scan-off"]);
    }

    onBtPowerChanged: updateBtScan()

    function looksUnnamed(name, mac) {
        let n = String(name || "");
        return n === "" || n.replace(/-/g, ":").toUpperCase() === String(mac || "").toUpperCase();
    }

    function processBtJson(textData) {
        if (textData === "") return;
        let data;
        try { data = JSON.parse(textData); } catch (e) { return; }

        let fetchedPower = data.power || "off";
        if (root.btPowerPending) {
            root.btPower = root.expectedBtPower;
            if (fetchedPower === root.expectedBtPower) {
                root.btPowerPending = false;
                btPendingReset.stop();
            }
        } else {
            root.btPower = fetchedPower;
            root.expectedBtPower = "";
        }

        let connected = data.connected || [];
        if (!Array.isArray(connected)) connected = [connected];
        let connectedRows = [];
        for (let i = 0; i < connected.length; i++) {
            let d = connected[i];
            if (!d || !d.mac) continue;
            connectedRows.push({
                rid: String(d.mac),
                name: String(d.name || d.mac),
                icon: String(d.icon || "󰂯"),
                mac: String(d.mac),
                battery: parseInt(d.battery || 0) || 0,
                profile: String(d.profile || "")
            });
            // Een apparaat dat verbonden is, is niet meer "bezig met verbinden".
            if (root.btBusy[d.mac] === "connect") root.setBtBusy(d.mac, "");
        }
        // Verbreken is klaar zodra het apparaat uit de verbonden lijst is.
        for (let mac in root.btBusy) {
            if (root.btBusy[mac] !== "disconnect") continue;
            let still = false;
            for (let i = 0; i < connectedRows.length; i++) {
                if (connectedRows[i].mac === mac) { still = true; break; }
            }
            if (!still) root.setBtBusy(mac, "");
        }

        let devices = Array.isArray(data.devices) ? data.devices : [];
        let paired = [];
        let found = [];
        for (let i = 0; i < devices.length; i++) {
            let d = devices[i];
            if (!d || !d.mac) continue;
            let unnamed = root.looksUnnamed(d.name, d.mac);
            let row = {
                rid: String(d.mac),
                name: unnamed ? "Onbekend apparaat" : String(d.name),
                icon: String(d.icon || "󰂯"),
                mac: String(d.mac),
                unnamed: unnamed
            };
            if (d.action === "Pair") found.push(row);
            else paired.push(row);
        }
        let byName = (a, b) => {
            if (a.unnamed !== b.unnamed) return a.unnamed ? 1 : -1;
            return a.name.localeCompare(b.name);
        };
        paired.sort(byName);
        found.sort(byName);

        root.syncModel(btConnectedModel, connectedRows);
        root.syncModel(btPairedModel, paired);
        root.syncModel(btFoundModel, found.slice(0, 20));
        root.btConnectedCount = connectedRows.length;
    }

    Process {
        id: btPoller
        command: ["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                cache.lastBtJson = txt;
                root.processBtJson(txt);
            }
        }
    }

    property string btConnectTarget: ""
    property string btConnectName: ""

    Process {
        id: btConnectProc
        stdout: StdioCollector { id: btConnectOut }
        onExited: (exitCode, exitStatus) => {
            let mac = root.btConnectTarget;
            root.setBtBusy(mac, "");
            let reply = null;
            try { reply = JSON.parse(String(btConnectOut.text || "").trim().split("\n").pop()); } catch (e) {}
            if (exitCode === 0 && (!reply || reply.ok !== false)) {
                root.playSfx("connect.wav");
                root.btError = "";
            } else {
                let why = reply && reply.error ? String(reply.error) : "";
                // bluetoothctl-uitvoer kan lang zijn; de eerste regel volstaat.
                why = why.split("\n")[0];
                root.btError = (root.btConnectName !== "" ? root.btConnectName + ": " : "")
                    + (why !== "" ? why : "verbinding mislukt");
                btErrorTimer.restart();
            }
            root.pollNow();
        }
    }

    Timer {
        id: btConnectTimeout
        interval: 90000
        onTriggered: {
            if (!btConnectProc.running) return;
            btConnectProc.running = false;
            root.setBtBusy(root.btConnectTarget, "");
            root.btError = "Verbinding mislukt (timeout)";
            btErrorTimer.restart();
        }
    }

    function connectBt(mac, name) {
        if (btConnectProc.running) {
            root.btError = "Even geduld: er wordt al een apparaat verbonden";
            btErrorTimer.restart();
            return;
        }
        root.btConnectTarget = mac;
        root.btConnectName = name || "";
        root.btError = "";
        root.setBtBusy(mac, "connect");
        btConnectProc.command = ["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--connect", mac];
        btConnectProc.running = true;
        btConnectTimeout.restart();
        root.pollNow();
    }

    function disconnectBt(mac) {
        if (root.btBusy[mac]) return;
        root.setBtBusy(mac, "disconnect");
        root.playSfx("disconnect.wav");
        Quickshell.execDetached(["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--disconnect", mac]);
        root.pollNow();
    }

    function forgetBt(mac) {
        if (root.btBusy[mac]) return;
        root.playSfx("disconnect.wav");
        Quickshell.execDetached(["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--forget", mac]);
        root.pollNow();
    }

    // ------------------------------------------------------------------------
    // Bedraad
    // ------------------------------------------------------------------------
    property var ethernet: ({ power: "off", connected: null })
    readonly property var ethConnection: ethernet && ethernet.connected ? ethernet.connected : null
    readonly property bool ethConnected: ethConnection !== null

    Process {
        id: ethPoller
        command: ["bash", root.scriptsDir + "/eth_panel_logic.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.ethernet = JSON.parse(this.text.trim()); } catch (e) {}
            }
        }
    }

    // ------------------------------------------------------------------------
    // Aan/uit en verversen
    // ------------------------------------------------------------------------
    readonly property bool currentPower: activeMode === "wifi" ? wifiPower === "on"
        : (activeMode === "bt" ? btPower === "on" : ethConnected)
    readonly property bool currentPowerPending: activeMode === "wifi" ? wifiPowerPending
        : (activeMode === "bt" ? btPowerPending : false)
    readonly property bool anyBusy: wifiBusySsid !== "" || wifiDisconnecting || Object.keys(btBusy).length > 0

    function togglePower() {
        if (root.activeMode === "wifi") {
            if (root.wifiPowerPending) return;
            root.expectedWifiPower = root.wifiPower === "on" ? "off" : "on";
            root.wifiPowerPending = true;
            root.playSfx(root.expectedWifiPower === "on" ? "power_on.wav" : "power_off.wav");
            wifiPendingReset.restart();
            root.wifiPower = root.expectedWifiPower;
            Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiPower]);
        } else if (root.activeMode === "bt") {
            if (root.btPowerPending) return;
            root.expectedBtPower = root.btPower === "on" ? "off" : "on";
            root.btPowerPending = true;
            root.playSfx(root.expectedBtPower === "on" ? "power_on.wav" : "power_off.wav");
            btPendingReset.restart();
            root.btPower = root.expectedBtPower;
            Quickshell.execDetached(["bash", root.scriptsDir + "/bluetooth_panel_logic.sh", "--toggle"]);
        }
        root.pollNow();
    }

    function pollNow() {
        if (!wifiPoller.running) wifiPoller.running = true;
        if (!btPoller.running) btPoller.running = true;
        if (root.activeMode === "eth" && !ethPoller.running) ethPoller.running = true;
    }

    Timer {
        interval: root.anyBusy || root.wifiPowerPending || root.btPowerPending ? 1000 : 3000
        running: true
        repeat: true
        onTriggered: root.pollNow()
    }

    // ------------------------------------------------------------------------
    // Weergave
    // ------------------------------------------------------------------------
    ColumnLayout {
        id: headerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Math.min(root.itemRadius, 18)
                color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, root.currentPower ? 0.24 : 0.10)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
                }
                Text {
                    anchors.centerIn: parent
                    text: root.activeMode === "wifi" ? (root.wifiPower === "on" ? (root.isWifiConn ? (root.wifiConnected.icon || "󰤨") : "󰤯") : "󰤮")
                        : (root.activeMode === "bt" ? (root.btPower === "on" ? (root.btConnectedCount > 0 ? "󰂱" : "󰂯") : "󰂲") : "󰈀")
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 18
                    color: root.currentPower ? root.activeColor : mocha.subtext0
                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.activeMode === "wifi" ? "Wi-Fi" : (root.activeMode === "bt" ? "Bluetooth" : "Bedraad netwerk")
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: ThemeConfig.headingWeight
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: {
                        if (root.activeMode === "wifi") {
                            if (root.wifiPowerPending) return root.expectedWifiPower === "on" ? "Wordt aangezet…" : "Wordt uitgezet…";
                            if (root.wifiPower !== "on") return "Uit";
                            if (root.wifiBusySsid !== "") return "Verbinden met " + root.wifiBusySsid + "…";
                            return root.isWifiConn ? "Verbonden met " + root.wifiConnected.ssid : "Aan, niet verbonden";
                        }
                        if (root.activeMode === "bt") {
                            if (root.btPowerPending) return root.expectedBtPower === "on" ? "Wordt aangezet…" : "Wordt uitgezet…";
                            if (root.btPower !== "on") return "Uit";
                            if (root.btConnectedCount === 1) return "1 apparaat verbonden";
                            if (root.btConnectedCount > 1) return root.btConnectedCount + " apparaten verbonden";
                            return root.btScanning ? "Aan · zoekt naar apparaten" : "Aan";
                        }
                        return root.ethConnected ? "Ethernet · verbonden" : "Geen kabelverbinding actief";
                    }
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: root.currentPower ? root.activeColor : mocha.subtext0
                    elide: Text.ElideRight
                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                    }
                }
            }

            IconButton {
                icon: "󰅁"
                tooltip: "Snelle instellingen"
                accent: mocha.subtext1
                onTriggered: root.panelSwitchRequested("quicksettings")
            }

            PowerSwitch {
                visible: root.activeMode !== "eth"
                checked: root.currentPower
                pending: root.currentPowerPending
                accent: root.activeColor
                onToggled: root.togglePower()
            }
        }

        // --- Tabs ------------------------------------------------------------
        Rectangle {
            id: tabBar
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Math.min(root.itemRadius, 18)
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            readonly property var modes: ["wifi", "bt", "eth"]
            readonly property int modeIndex: Math.max(0, modes.indexOf(root.activeMode))
            readonly property real segmentWidth: (width - 6) / modes.length

            // Glijdende markering onder de actieve tab.
            Rectangle {
                x: 3 + tabBar.modeIndex * tabBar.segmentWidth
                y: 3
                width: tabBar.segmentWidth
                height: tabBar.height - 6
                radius: Math.max(4, tabBar.radius - 3)
                color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.22)
                border.width: 1
                border.color: Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.45)
                Behavior on x {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                }
                Behavior on border.color {
                    ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0

                TabButton { mode: "wifi"; icon: "󰤨"; label: "Wi-Fi"; accent: root.wifiAccent }
                TabButton { mode: "bt"; icon: "󰂯"; label: "Bluetooth"; accent: root.btAccent }
                TabButton { mode: "eth"; icon: "󰈀"; label: "Bedraad"; accent: root.ethAccent }
            }
        }
    }

    Flickable {
        id: bodyFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerColumn.bottom
        anchors.bottom: parent.bottom
        anchors.topMargin: 12
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottomMargin: root.pad
        contentWidth: width
        contentHeight: bodyColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
            id: bodyColumn
            width: bodyFlick.width
            spacing: 8

            // ================= Wi-Fi =================
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.activeMode === "wifi"
                spacing: 8

                OffState {
                    shown: root.wifiPower !== "on" && !root.wifiPowerPending
                    icon: "󰤮"
                    title: "Wi-Fi staat uit"
                    detail: "Zet Wi-Fi aan om netwerken in de buurt te zien."
                    accent: root.wifiAccent
                    onActivate: root.togglePower()
                }

                Banner {
                    shown: root.wifiError !== ""
                    message: root.wifiError
                    onDismissed: root.wifiError = ""
                }

                // Huidige verbinding.
                Rectangle {
                    id: wifiCurrent
                    property bool expanded: false
                    Layout.fillWidth: true
                    visible: root.wifiPower === "on" && root.isWifiConn
                    Layout.preferredHeight: wifiCurrentColumn.implicitHeight + 16
                    radius: Math.min(root.itemRadius, 14)
                    color: Qt.rgba(root.wifiAccent.r, root.wifiAccent.g, root.wifiAccent.b, 0.14)
                    border.width: 1
                    border.color: Qt.rgba(root.wifiAccent.r, root.wifiAccent.g, root.wifiAccent.b, 0.45)

                    ColumnLayout {
                        id: wifiCurrentColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            IconBubble {
                                icon: root.isWifiConn ? (root.wifiConnected.icon || "󰤨") : "󰤨"
                                accent: root.wifiAccent
                                lit: true
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: root.isWifiConn ? root.wifiConnected.ssid : ""
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.wifiDisconnecting ? "Verbreken…"
                                        : "Verbonden" + (root.isWifiConn && root.wifiConnected.signal ? " · " + root.wifiConnected.signal + "%" : "")
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 10
                                    color: root.wifiAccent
                                    elide: Text.ElideRight
                                }
                            }
                            IconButton {
                                icon: "󰅂"
                                tooltip: "Details"
                                accent: mocha.text
                                small: true
                                iconRotation: wifiCurrent.expanded ? 90 : 0
                                onTriggered: wifiCurrent.expanded = !wifiCurrent.expanded
                            }
                            IconButton {
                                icon: root.wifiDisconnecting ? "󰑮" : "󰖪"
                                spinning: root.wifiDisconnecting
                                tooltip: "Verbreken"
                                accent: mocha.red
                                small: true
                                onTriggered: root.disconnectWifi()
                            }
                        }

                        Reveal {
                            shown: wifiCurrent.expanded
                            DetailRow { icon: "󰤨"; label: "Signaal"; value: root.isWifiConn && root.wifiConnected.signal ? root.wifiConnected.signal + "%" : "—"; accent: root.wifiAccent }
                            DetailRow { icon: "󰦝"; label: "Beveiliging"; value: root.isWifiConn ? root.securityLabel(root.wifiConnected.security) : "—"; accent: root.wifiAccent }
                            DetailRow { icon: "󰩟"; label: "IP-adres"; value: root.isWifiConn && root.wifiConnected.ip && root.wifiConnected.ip !== "No IP" ? root.wifiConnected.ip : "Geen IP"; accent: root.wifiAccent }
                            DetailRow { icon: "󰖧"; label: "Band"; value: root.isWifiConn ? root.bandLabel(root.wifiConnected.freq) : "—"; accent: root.wifiAccent }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.wifiPower === "on"
                    spacing: 6
                    SectionLabel { text: "Beschikbare netwerken" }
                    IconButton {
                        icon: "󰑐"
                        tooltip: "Opnieuw zoeken"
                        accent: root.wifiAccent
                        small: true
                        spinning: root.wifiScanning
                        onTriggered: root.rescanWifi()
                    }
                }

                Repeater {
                    model: wifiModel
                    delegate: DeviceRow {
                        id: netRow
                        required property var model
                        readonly property bool secured: root.isSecured(netRow.model.security)
                        readonly property bool asking: root.passwordSsid === netRow.model.name
                        visible: root.wifiPower === "on"
                        icon: netRow.model.icon
                        title: netRow.model.name
                        subtitle: (secured ? root.securityLabel(netRow.model.security) : "Open")
                            + (netRow.model.known ? " · opgeslagen" : "")
                            + " · " + netRow.model.signal + "%"
                        accent: root.wifiAccent
                        trailingIcon: secured && !netRow.model.known ? "󰌾" : "󰅂"
                        busy: root.wifiBusySsid === netRow.model.name
                        highlighted: asking
                        secondaryIcon: netRow.model.known ? "󰩺" : ""
                        secondaryTooltip: "Vergeten"
                        onSecondaryTriggered: root.forgetWifi(netRow.model.name)
                        onTriggered: {
                            if (secured && !netRow.model.known) {
                                root.passwordSsid = asking ? "" : netRow.model.name;
                            } else {
                                root.passwordSsid = "";
                                root.connectWifi(netRow.model.name);
                            }
                        }

                        Reveal {
                            shown: netRow.asking
                            onShownChanged: if (shown) passwordField.forceActiveFocus()

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Math.min(root.itemRadius, 12)
                                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                                    border.width: 1
                                    border.color: passwordField.activeFocus
                                        ? Qt.rgba(root.wifiAccent.r, root.wifiAccent.g, root.wifiAccent.b, 0.70)
                                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                                    Behavior on border.color {
                                        ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                                    }

                                    TextInput {
                                        id: passwordField
                                        property bool reveal: false
                                        anchors.left: parent.left
                                        anchors.right: eyeButton.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 4
                                        echoMode: reveal ? TextInput.Normal : TextInput.Password
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: 12
                                        color: mocha.text
                                        selectionColor: Qt.rgba(root.wifiAccent.r, root.wifiAccent.g, root.wifiAccent.b, 0.4)
                                        clip: true
                                        onAccepted: if (text !== "") { root.connectWifi(netRow.model.name, text); text = ""; }
                                        Keys.onEscapePressed: root.passwordSsid = ""

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: passwordField.text === ""
                                            text: "Wachtwoord"
                                            font: passwordField.font
                                            color: mocha.subtext0
                                        }
                                    }

                                    Text {
                                        id: eyeButton
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: passwordField.reveal ? "󰈉" : "󰈈"
                                        font.family: ThemeConfig.iconFont
                                        font.pixelSize: 14
                                        color: eyeMouse.containsMouse ? mocha.text : mocha.subtext0
                                        MouseArea {
                                            id: eyeMouse
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: passwordField.reveal = !passwordField.reveal
                                        }
                                    }
                                }

                                PillButton {
                                    label: "Verbind"
                                    accent: root.wifiAccent
                                    enabledState: passwordField.text !== "" && root.wifiBusySsid === ""
                                    onTriggered: {
                                        root.connectWifi(netRow.model.name, passwordField.text);
                                        passwordField.text = "";
                                    }
                                }
                            }
                        }
                    }
                }

                EmptyNote {
                    visible: root.wifiPower === "on" && wifiModel.count === 0
                    text: root.wifiScanning ? "Zoeken naar netwerken…" : "Geen andere netwerken gevonden"
                }
            }

            // ================= Bluetooth =================
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.activeMode === "bt"
                spacing: 8

                OffState {
                    shown: root.btPower !== "on" && !root.btPowerPending
                    icon: "󰂲"
                    title: "Bluetooth staat uit"
                    detail: "Zet Bluetooth aan om apparaten te verbinden of te koppelen."
                    accent: root.btAccent
                    onActivate: root.togglePower()
                }

                Banner {
                    shown: root.btError !== ""
                    message: root.btError
                    onDismissed: root.btError = ""
                }

                Repeater {
                    model: btConnectedModel
                    delegate: Rectangle {
                        id: btCard
                        required property var model
                        property bool expanded: false
                        readonly property bool leaving: root.btBusy[btCard.model.mac] === "disconnect"
                        Layout.fillWidth: true
                        visible: root.btPower === "on"
                        Layout.preferredHeight: btCardColumn.implicitHeight + 16
                        radius: Math.min(root.itemRadius, 14)
                        color: Qt.rgba(root.btAccent.r, root.btAccent.g, root.btAccent.b, 0.14)
                        border.width: 1
                        border.color: Qt.rgba(root.btAccent.r, root.btAccent.g, root.btAccent.b, 0.45)

                        ColumnLayout {
                            id: btCardColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 0

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                IconBubble { icon: btCard.model.icon; accent: root.btAccent; lit: true }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        Layout.fillWidth: true
                                        text: btCard.model.name
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        color: mocha.text
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: btCard.leaving ? "Verbreken…"
                                            : "Verbonden"
                                              + (btCard.model.battery > 0 ? " · " + btCard.model.battery + "%" : "")
                                              + (btCard.model.profile !== "" && btCard.model.profile !== "None" ? " · " + btCard.model.profile : "")
                                        font.family: ThemeConfig.uiFont
                                        font.pixelSize: 10
                                        color: root.btAccent
                                        elide: Text.ElideRight
                                    }
                                }
                                IconButton {
                                    icon: "󰅂"
                                    tooltip: "Details"
                                    accent: mocha.text
                                    small: true
                                    iconRotation: btCard.expanded ? 90 : 0
                                    onTriggered: btCard.expanded = !btCard.expanded
                                }
                                IconButton {
                                    icon: btCard.leaving ? "󰑮" : "󰂲"
                                    spinning: btCard.leaving
                                    tooltip: "Verbreken"
                                    accent: mocha.red
                                    small: true
                                    onTriggered: root.disconnectBt(btCard.model.mac)
                                }
                            }

                            // Batterijbalkje van het apparaat (als het dat meldt).
                            Rectangle {
                                visible: btCard.model.battery > 0
                                Layout.fillWidth: true
                                Layout.topMargin: 8
                                Layout.leftMargin: 40
                                Layout.preferredHeight: 4
                                radius: 2
                                color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                                Rectangle {
                                    width: parent.width * Math.max(0, Math.min(100, btCard.model.battery)) / 100
                                    height: parent.height
                                    radius: parent.radius
                                    color: btCard.model.battery <= 15 ? mocha.red : (btCard.model.battery <= 35 ? mocha.yellow : root.btAccent)
                                    Behavior on width {
                                        NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
                                    }
                                }
                            }

                            Reveal {
                                shown: btCard.expanded
                                DetailRow { icon: "󰥉"; label: "Batterij"; value: btCard.model.battery > 0 ? btCard.model.battery + "%" : "Niet gemeld"; accent: root.btAccent }
                                DetailRow {
                                    visible: btCard.model.profile !== "" && btCard.model.profile !== "None"
                                    icon: btCard.model.profile === "Hi-Fi (A2DP)" ? "󰓃" : "󰋎"
                                    label: "Audioprofiel"
                                    value: btCard.model.profile
                                    accent: root.btAccent
                                }
                                DetailRow { icon: "󰒋"; label: "MAC-adres"; value: btCard.model.mac; accent: root.btAccent }
                            }
                        }
                    }
                }

                SectionLabel {
                    Layout.topMargin: 4
                    visible: root.btPower === "on" && btPairedModel.count > 0
                    text: "Gekoppelde apparaten"
                }

                Repeater {
                    model: btPairedModel
                    delegate: DeviceRow {
                        id: pairedRow
                        required property var model
                        visible: root.btPower === "on"
                        icon: pairedRow.model.icon
                        title: pairedRow.model.name
                        subtitle: root.btBusy[pairedRow.model.mac] === "connect" ? "Verbinden…" : "Gekoppeld · klik om te verbinden"
                        accent: root.btAccent
                        busy: root.btBusy[pairedRow.model.mac] === "connect"
                        dimmed: pairedRow.model.unnamed
                        secondaryIcon: "󰩺"
                        secondaryTooltip: "Vergeten"
                        onSecondaryTriggered: root.forgetBt(pairedRow.model.mac)
                        onTriggered: root.connectBt(pairedRow.model.mac, pairedRow.model.name)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.btPower === "on"
                    spacing: 6
                    SectionLabel { text: "In de buurt" }
                    LoadingDots { visible: root.btScanning; dotColor: root.btAccent }
                }

                Repeater {
                    model: btFoundModel
                    delegate: DeviceRow {
                        id: foundRow
                        required property var model
                        visible: root.btPower === "on"
                        icon: foundRow.model.icon
                        title: foundRow.model.name
                        subtitle: root.btBusy[foundRow.model.mac] === "connect" ? "Koppelen…"
                            : (foundRow.model.unnamed ? foundRow.model.mac : "Klik om te koppelen")
                        accent: root.btAccent
                        busy: root.btBusy[foundRow.model.mac] === "connect"
                        dimmed: foundRow.model.unnamed
                        trailingIcon: "󰐕"
                        onTriggered: root.connectBt(foundRow.model.mac, foundRow.model.name)
                    }
                }

                EmptyNote {
                    visible: root.btPower === "on" && btFoundModel.count === 0
                    text: root.btScanning ? "Zoeken naar apparaten in de buurt…" : "Geen nieuwe apparaten gevonden"
                }
            }

            // ================= Bedraad =================
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.activeMode === "eth"
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ethColumn.implicitHeight + 16
                    radius: Math.min(root.itemRadius, 14)
                    color: root.ethConnected
                        ? Qt.rgba(root.ethAccent.r, root.ethAccent.g, root.ethAccent.b, 0.14)
                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.04)
                    border.width: 1
                    border.color: root.ethConnected
                        ? Qt.rgba(root.ethAccent.r, root.ethAccent.g, root.ethAccent.b, 0.45)
                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("normal") }
                    }

                    ColumnLayout {
                        id: ethColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            IconBubble { icon: "󰈀"; accent: root.ethAccent; lit: root.ethConnected }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: root.ethConnected ? (root.ethConnection.name || "Bedrade verbinding") : "Bedraad netwerk"
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.ethConnected ? "Ethernet · verbonden" : "Geen kabelverbinding actief"
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 10
                                    color: root.ethConnected ? root.ethAccent : mocha.subtext0
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                Layout.rightMargin: 6
                                radius: 4
                                color: root.ethConnected ? root.ethAccent : mocha.overlay0
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 6
                            DetailRow { icon: "󰩟"; label: "IP-adres"; value: root.ethConnected && root.ethConnection.ip !== "No IP" ? (root.ethConnection.ip || "—") : "—"; accent: root.ethAccent }
                            DetailRow { icon: "󰖟"; label: "Snelheid"; value: root.ethConnected && root.ethConnection.speed !== "Unknown" ? (root.ethConnection.speed || "Onbekend") : "—"; accent: root.ethAccent }
                            DetailRow { icon: "󰒋"; label: "Interface"; value: root.ethConnected ? (root.ethConnection.id || "—") : "—"; accent: root.ethAccent }
                            DetailRow { icon: "󰑬"; label: "MAC-adres"; value: root.ethConnected ? (root.ethConnection.mac || "—") : "—"; accent: root.ethAccent }
                        }
                    }
                }

                EmptyNote {
                    text: root.ethConnected
                        ? "Bedraad netwerk wordt automatisch door NetworkManager beheerd."
                        : "Sluit een ethernetkabel aan; deze weergave ververst automatisch."
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Componenten
    // ------------------------------------------------------------------------

    // Klapt zijn inhoud vloeiend open en dicht (zelfde als Geluid & media).
    component Reveal: Item {
        id: reveal
        property bool shown: false
        property int gap: 8
        default property alias content: revealColumn.data
        property real progress: shown ? 1 : 0

        Layout.fillWidth: true
        Layout.preferredHeight: Math.ceil((revealColumn.implicitHeight + gap) * progress)
        visible: shown || progress > 0.001
        opacity: progress
        clip: true

        Behavior on progress {
            NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        ColumnLayout {
            id: revealColumn
            y: reveal.gap
            width: reveal.width
            spacing: 6
        }
    }

    component SectionLabel: Text {
        Layout.fillWidth: true
        font.family: ThemeConfig.uiFont
        font.pixelSize: 10
        font.weight: ThemeConfig.emphasisWeight
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 0.6
        color: mocha.subtext0
    }

    component EmptyNote: Text {
        Layout.fillWidth: true
        topPadding: 6
        bottomPadding: 6
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        font.family: ThemeConfig.uiFont
        font.pixelSize: 11
        color: mocha.subtext0
    }

    component DetailRow: RowLayout {
        id: detail
        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: mocha.primary
        Layout.fillWidth: true
        spacing: 10
        Text {
            Layout.preferredWidth: 32
            horizontalAlignment: Text.AlignHCenter
            text: detail.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 14
            color: detail.accent
        }
        Text {
            Layout.preferredWidth: 86
            text: detail.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            color: mocha.subtext0
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: detail.value
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Medium
            color: mocha.text
            elide: Text.ElideRight
        }
    }

    component IconBubble: Rectangle {
        id: bubble
        property string icon: ""
        property color accent: mocha.primary
        property bool lit: false
        property bool dimmed: false
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: lit
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.30)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Text {
            anchors.centerIn: parent
            text: bubble.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 16
            color: bubble.lit ? bubble.accent : (bubble.dimmed ? mocha.overlay1 : mocha.subtext0)
        }
    }

    // Eén netwerk of apparaat. Klik verbindt; het tweede knopje (verschijnt
    // bij hover) vergeet. Kinderen (zoals het wachtwoordveld) komen eronder.
    component DeviceRow: Rectangle {
        id: row
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property color accent: mocha.primary
        property string trailingIcon: "󰅂"
        property string secondaryIcon: ""
        property string secondaryTooltip: ""
        property bool busy: false
        property bool highlighted: false
        property bool dimmed: false
        default property alias extra: rowExtra.data
        signal triggered()
        signal secondaryTriggered()

        readonly property bool hovered: rowMouse.containsMouse || secondaryMouse.containsMouse

        Layout.fillWidth: true
        Layout.preferredHeight: rowColumn.implicitHeight + 12
        radius: Math.min(root.itemRadius, 14)
        color: highlighted
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.10)
            : (busy
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.08)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, hovered ? 0.08 : 0.04))
        border.width: 1
        border.color: highlighted || busy
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.35)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, hovered ? 0.12 : 0.06)
        scale: rowMouse.pressed ? 0.985 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on border.color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        ColumnLayout {
            id: rowColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            anchors.leftMargin: 8
            spacing: 0

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 34

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.busy ? Qt.BusyCursor : Qt.PointingHandCursor
                    onClicked: if (!row.busy) row.triggered()
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    IconBubble {
                        icon: row.icon
                        accent: row.accent
                        lit: row.busy || row.highlighted
                        dimmed: row.dimmed
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.title
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: row.dimmed ? mocha.subtext0 : mocha.text
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.subtitle
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: row.busy ? row.accent : mocha.subtext0
                            elide: Text.ElideRight
                        }
                    }

                    // Vergeten: alleen zichtbaar bij hover, zodat de lijst rustig blijft.
                    Rectangle {
                        visible: row.secondaryIcon !== "" && !row.busy
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: Math.min(root.itemRadius, 13)
                        opacity: row.hovered ? 1 : 0
                        color: secondaryMouse.containsMouse
                            ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.20)
                            : "transparent"
                        Behavior on opacity {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: row.secondaryIcon
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 13
                            color: secondaryMouse.containsMouse ? mocha.red : mocha.subtext0
                        }
                        MouseArea {
                            id: secondaryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: row.secondaryTriggered()
                        }
                    }

                    Text {
                        Layout.preferredWidth: 24
                        horizontalAlignment: Text.AlignHCenter
                        text: row.busy ? "󰑮" : row.trailingIcon
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: 14
                        color: row.busy || row.highlighted ? row.accent : (row.hovered ? mocha.text : mocha.subtext0)
                        rotation: row.busy ? spinAngle : (row.highlighted && row.trailingIcon === "󰅂" ? 90 : 0)
                        property real spinAngle: 0
                        NumberAnimation on spinAngle {
                            from: 0; to: 360; duration: 900
                            loops: Animation.Infinite
                            running: row.busy
                        }
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                        }
                    }
                }
            }

            ColumnLayout {
                id: rowExtra
                Layout.fillWidth: true
                spacing: 0
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property string tooltip: ""
        property color accent: mocha.text
        property bool small: false
        property bool spinning: false
        property real iconRotation: 0
        signal triggered()

        Layout.preferredWidth: small ? 28 : 32
        Layout.preferredHeight: small ? 28 : 32
        radius: Math.min(root.itemRadius, small ? 14 : 16)
        color: ibMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, small ? 0.0 : 0.06)
        scale: ibMouse.pressed ? 0.94 : (ibMouse.containsMouse ? 1.07 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            id: ibIcon
            anchors.centerIn: parent
            text: ib.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: ib.small ? 14 : 15
            color: ibMouse.containsMouse || ib.spinning ? ib.accent : (ib.small ? mocha.subtext0 : ib.accent)
            property real spinAngle: 0
            rotation: ib.spinning ? spinAngle : ib.iconRotation
            Behavior on rotation {
                enabled: !ib.spinning
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
            NumberAnimation on spinAngle {
                from: 0; to: 360; duration: 900
                loops: Animation.Infinite
                running: ib.spinning
            }
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("fast") }
            }
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }
    }

    // Aan/uit-schakelaar: knopje glijdt, het spoor kleurt mee; tijdens het
    // omzetten draait er een klein wieltje in het knopje.
    component PowerSwitch: Rectangle {
        id: sw
        property bool checked: false
        property bool pending: false
        property color accent: mocha.primary
        signal toggled()

        Layout.preferredWidth: 46
        Layout.preferredHeight: 26
        radius: height / 2
        color: checked
            ? Qt.rgba(accent.r, accent.g, accent.b, swMouse.containsMouse ? 0.95 : 0.85)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, swMouse.containsMouse ? 0.16 : 0.10)
        border.width: 1
        border.color: checked
            ? Qt.rgba(accent.r, accent.g, accent.b, 1.0)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.16)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on border.color {
            ColorAnimation { duration: ThemeConfig.durationToken("normal") }
        }

        Rectangle {
            id: knob
            width: sw.height - 6
            height: width
            radius: width / 2
            y: 3
            x: sw.checked ? sw.width - width - 3 : 3
            color: sw.checked ? mocha.crust : mocha.subtext0
            scale: swMouse.pressed ? 0.88 : 1.0
            Behavior on x {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("normal") }
            }
            Behavior on scale {
                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
            }
            Text {
                anchors.centerIn: parent
                visible: sw.pending
                text: "󰑮"
                font.family: ThemeConfig.iconFont
                font.pixelSize: 11
                color: sw.checked ? sw.accent : mocha.crust
                property real spinAngle: 0
                rotation: spinAngle
                NumberAnimation on spinAngle {
                    from: 0; to: 360; duration: 800
                    loops: Animation.Infinite
                    running: sw.pending
                }
            }
        }

        MouseArea {
            id: swMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.toggled()
        }
    }

    component TabButton: Item {
        id: tab
        property string mode: ""
        property string icon: ""
        property string label: ""
        property color accent: mocha.primary
        readonly property bool current: root.activeMode === mode

        Layout.fillWidth: true
        Layout.fillHeight: true

        Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 14
                color: tab.current ? tab.accent : (tabMouse.containsMouse ? mocha.text : mocha.subtext0)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tab.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                font.weight: tab.current ? Font.DemiBold : Font.Normal
                color: tab.current ? mocha.text : (tabMouse.containsMouse ? mocha.text : mocha.subtext0)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
            }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setMode(tab.mode)
        }
    }

    // Lege toestand als de radio uit staat, met een knop om hem aan te zetten.
    component OffState: Rectangle {
        id: off
        property bool shown: false
        property string icon: ""
        property string title: ""
        property string detail: ""
        property color accent: mocha.primary
        signal activate()

        Layout.fillWidth: true
        visible: shown
        Layout.preferredHeight: offColumn.implicitHeight + 32
        radius: Math.min(root.itemRadius, 14)
        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.04)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

        ColumnLayout {
            id: offColumn
            anchors.centerIn: parent
            width: parent.width - 32
            spacing: 8

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Math.min(root.itemRadius + 4, 24)
                color: Qt.rgba(off.accent.r, off.accent.g, off.accent.b, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: off.icon
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 22
                    color: off.accent
                }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: off.title
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: mocha.text
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: off.detail
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext0
            }
            PillButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                label: "Aanzetten"
                accent: off.accent
                onTriggered: off.activate()
            }
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property color accent: mocha.primary
        property bool enabledState: true
        signal triggered()

        Layout.preferredWidth: pillText.implicitWidth + 28
        Layout.preferredHeight: 32
        radius: height / 2
        opacity: enabledState ? 1 : 0.5
        color: Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse && enabledState ? 0.95 : 0.80)
        scale: pillMouse.pressed && enabledState ? 0.95 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: mocha.crust
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pill.enabledState ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (pill.enabledState) pill.triggered()
        }
    }

    // Foutmelding die zacht in- en uitklapt; klik sluit hem.
    component Banner: Item {
        id: banner
        property bool shown: false
        property string message: ""
        property real progress: shown ? 1 : 0
        signal dismissed()

        Layout.fillWidth: true
        Layout.preferredHeight: Math.ceil((bannerBox.implicitHeight) * progress)
        visible: shown || progress > 0.001
        opacity: progress
        clip: true
        Behavior on progress {
            NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Rectangle {
            id: bannerBox
            width: parent.width
            implicitHeight: bannerRow.implicitHeight + 16
            height: implicitHeight
            radius: Math.min(root.itemRadius, 14)
            color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.45)

            RowLayout {
                id: bannerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: "󰀦"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 15
                    color: mocha.red
                }
                Text {
                    Layout.fillWidth: true
                    text: banner.message
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.text
                }
                Text {
                    text: "󰅖"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 13
                    color: bannerMouse.containsMouse ? mocha.text : mocha.subtext0
                }
            }
            MouseArea {
                id: bannerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: banner.dismissed()
            }
        }
    }

    component LoadingDots: Row {
        id: dots
        property color dotColor: mocha.text
        spacing: 4
        Repeater {
            model: 3
            Rectangle {
                id: dot
                required property int index
                width: 5
                height: 5
                radius: 2.5
                color: dots.dotColor
                opacity: 0.3
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: dots.visible
                    PauseAnimation { duration: dot.index * 160 }
                    NumberAnimation { to: 1.0; duration: 320; easing.type: Easing.OutSine }
                    NumberAnimation { to: 0.3; duration: 320; easing.type: Easing.InSine }
                    PauseAnimation { duration: (2 - dot.index) * 160 }
                }
            }
        }
    }
}
