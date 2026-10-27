import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

// Linkerkolom van het controlecentrum (TopHoverWidget): de snelle
// instellingen zoals GNOME en macOS ze doen. Een pil schakelt met één klik;
// het pijltje klapt de pil ter plekke uit (wifi-netwerken, bluetooth-
// apparaten, energieprofielen) in plaats van naar een ander paneel te
// springen. Onderaan elke uitklap staat een link naar het volledige paneel,
// zodat er niets wegvalt ten opzichte van Snelle instellingen.
Item {
    id: root

    MatugenColors { id: mocha }

    signal panelSwitchRequested(string entryId)
    property string requestedNetworkMode: ""

    readonly property int itemRadius: Math.max(10, Math.min(18, ThemeConfig.styleWidgetRadius))
    implicitHeight: content.implicitHeight

    // Welke pil is uitgeklapt: "", "wifi", "bt" of "power".
    property string expanded: ""

    // --- Netwerk en bluetooth ------------------------------------------------
    readonly property bool hasWifi: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return true;
        }
        return false;
    }
    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property bool isEthConnected: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wired && devs[i].connected) return true;
        }
        return false;
    }
    readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null
    readonly property bool bluetoothOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property int bluetoothConnected: {
        if (!Bluetooth.devices) return 0;
        let list = Bluetooth.devices.values;
        let n = 0;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && list[i].connected) n++;
        }
        return n;
    }

    // --- Batterij en energieprofiel ------------------------------------------
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    readonly property int batteryPercent: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool charging: UPower.displayDevice !== null
        && (UPower.displayDevice.state === UPowerDeviceState.Charging
            || UPower.displayDevice.state === UPowerDeviceState.FullyCharged
            || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
    readonly property string powerProfileName: {
        let p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "performance";
        if (p === PowerProfile.PowerSaver) return "power-saver";
        return "balanced";
    }

    // --- Gepollde state ------------------------------------------------------
    property int brightness: -1
    property int volume: 0
    property bool muted: false
    property string wifiName: ""
    property int kbLayoutCount: 1
    property string kbLayout: ""
    property bool draggingBrightness: false
    property bool draggingVolume: false
    property var wifiNetworks: []
    property var savedConnections: []
    property var btConnected: []
    property var btPaired: []
    property string busyId: ""

    function openPanel(entryId, networkMode) {
        root.requestedNetworkMode = networkMode ? String(networkMode) : "";
        if (networkMode)
            Quickshell.execDetached(["bash", "-lc", "printf '%s' '" + networkMode + "' > /tmp/qs_network_mode"]);
        root.panelSwitchRequested(entryId);
    }

    function toggleExpanded(name) {
        expanded = expanded === name ? "" : name;
        if (expanded === "wifi") {
            Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
            refreshWifi();
        }
        if (expanded === "bt") refreshBt();
    }

    function profileLabel(name) {
        if (name === "performance") return "Prestaties";
        if (name === "power-saver") return "Energiebesparing";
        return "Gebalanceerd";
    }

    function setProfile(name) {
        if (name === "performance") PowerProfiles.profile = PowerProfile.Performance;
        else if (name === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
        else PowerProfiles.profile = PowerProfile.Balanced;
    }

    function batteryTimeText() {
        let d = UPower.displayDevice;
        if (!d) return "";
        let seconds = root.charging ? d.timeToFull : d.timeToEmpty;
        if (!seconds || seconds <= 0) return root.charging ? "Aan het laden" : "";
        let h = Math.floor(seconds / 3600);
        let m = Math.floor((seconds % 3600) / 60);
        let span = h > 0 ? h + "u " + (m < 10 ? "0" : "") + m + "m" : m + "m";
        return root.charging ? "Vol over " + span : "Nog " + span;
    }

    function setBrightness(percent) {
        let v = Math.max(1, Math.min(100, Math.round(percent)));
        root.brightness = v;
        Quickshell.execDetached(["bash", "-lc", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -q set " + v + "%"]);
    }

    function setVolume(percent) {
        let v = Math.max(0, Math.min(100, Math.round(percent)));
        if (v > 0 && root.muted) {
            root.muted = false;
            Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"]);
        }
        root.volume = v;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]);
    }

    function toggleMute() {
        root.muted = !root.muted;
        Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        refreshSoon.restart();
    }

    // Bekende netwerken verbinden meteen; een beveiligd onbekend netwerk
    // heeft een wachtwoord nodig, en dat vraagt het netwerkpaneel.
    function connectWifi(net) {
        if (!net) return;
        let ssid = String(net.ssid || "");
        let secured = String(net.security || "").trim() !== "" && String(net.security) !== "--";
        if (secured && savedConnections.indexOf(ssid) === -1) {
            openPanel("network", "wifi");
            return;
        }
        busyId = ssid;
        Quickshell.execDetached(["nmcli", "device", "wifi", "connect", ssid]);
        busyClear.restart();
        wifiRefreshSoon.restart();
    }

    function btAction(dev, connect) {
        if (!dev || !dev.mac) return;
        busyId = String(dev.mac);
        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/network/bluetooth_panel_logic.sh",
            connect ? "--connect" : "--disconnect", String(dev.mac)]);
        busyClear.restart();
        btRefreshSoon.restart();
    }

    function refresh() {
        if (!statePoller.running) statePoller.running = true;
    }
    function refreshWifi() {
        if (!wifiPoller.running) wifiPoller.running = true;
        if (!savedPoller.running) savedPoller.running = true;
    }
    function refreshBt() {
        if (!btPoller.running) btPoller.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: statePoller
        command: ["bash", "-lc",
            "bri=''; if command -v brightnessctl >/dev/null 2>&1; then bri=$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1{gsub(/%/,\"\",$4); print $4}'); fi; " +
            "vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1; exit}'); " +
            "kbn=1; kb=''; if command -v jq >/dev/null 2>&1; then " +
            "kbn=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // \"us\"' | awk -F, '{n=0; for(i=1;i<=NF;i++) if($i!=\"\") n++; print n}'); " +
            "kb=$(hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main==true) | .active_keymap][0] // \"\"'); fi; " +
            "printf 'bri=%s\\nvol=%s\\nssid=%s\\nkbn=%s\\nkb=%s\\n' \"$bri\" \"$vol\" \"$ssid\" \"$kbn\" \"$kb\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let state = {};
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let eq = lines[i].indexOf("=");
                    if (eq > 0) state[lines[i].substring(0, eq)] = lines[i].substring(eq + 1).trim();
                }
                let bright = parseInt(state.bri);
                if (!root.draggingBrightness) root.brightness = isNaN(bright) ? -1 : bright;
                // wpctl: "Volume: 0.45" of "Volume: 0.45 [MUTED]"
                let m = String(state.vol || "").match(/([0-9.]+)/);
                if (m && !root.draggingVolume) root.volume = Math.round(parseFloat(m[1]) * 100);
                root.muted = String(state.vol || "").indexOf("MUTED") !== -1;
                root.wifiName = state.ssid || "";
                let kbCount = parseInt(state.kbn);
                root.kbLayoutCount = isNaN(kbCount) ? 1 : kbCount;
                root.kbLayout = state.kb || "";
            }
        }
    }

    Process {
        id: wifiPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/network/wifi_panel_logic.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim() || "{}");
                    let list = [];
                    if (data.connected) list.push(Object.assign({ active: true }, data.connected));
                    let nets = Array.isArray(data.networks) ? data.networks : [];
                    for (let i = 0; i < nets.length && list.length < 8; i++) list.push(nets[i]);
                    root.wifiNetworks = list;
                } catch (e) {}
            }
        }
    }

    Process {
        id: savedPoller
        command: ["bash", "-lc", "nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1}'"]
        stdout: StdioCollector {
            onStreamFinished: root.savedConnections = this.text.split("\n").filter(s => s !== "")
        }
    }

    Process {
        id: btPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/network/bluetooth_panel_logic.sh", "--status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim() || "{}");
                    root.btConnected = Array.isArray(data.connected) ? data.connected : [];
                    let devs = Array.isArray(data.devices) ? data.devices : [];
                    root.btPaired = devs.filter(d => d.action === "Connect").slice(0, 6);
                } catch (e) {}
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 350
        onTriggered: root.refresh()
    }
    Timer {
        id: wifiRefreshSoon
        interval: 2500
        onTriggered: root.refreshWifi()
    }
    Timer {
        id: btRefreshSoon
        interval: 2500
        onTriggered: root.refreshBt()
    }
    Timer {
        id: busyClear
        interval: 8000
        onTriggered: root.busyId = ""
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        // Alleen de uitgeklapte lijst blijft verversen.
        interval: 4000
        running: root.expanded === "wifi" || root.expanded === "bt"
        repeat: true
        onTriggered: root.expanded === "wifi" ? root.refreshWifi() : root.refreshBt()
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        // --- Kop: batterij en snelle knoppen -----------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    text: "Snelle instellingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    color: mocha.text
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hasBattery
                        ? "󰁹 " + root.batteryPercent + "%" + (root.batteryTimeText() !== "" ? " · " + root.batteryTimeText() : "")
                        : root.profileLabel(root.powerProfileName)
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            RoundButton {
                icon: "󰌾"
                tooltip: "Vergrendelen"
                accent: mocha.accent1
                onTriggered: Quickshell.execDetached(["bash", "-lc", "if [ -x \"$HOME/.config/hypr/scripts/lock.sh\" ]; then \"$HOME/.config/hypr/scripts/lock.sh\"; else loginctl lock-session; fi"])
            }
            RoundButton {
                icon: "󰒓"
                tooltip: "Instellingen"
                accent: mocha.subtext1
                onTriggered: root.panelSwitchRequested("settings")
            }
            RoundButton {
                icon: "󰐥"
                tooltip: "Afsluitmenu"
                accent: mocha.red
                onTriggered: root.openPanel("power")
            }
        }

        // --- Pillen ------------------------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Pill {
                visible: root.hasWifi
                icon: root.wifiOn ? "󰤨" : "󰤮"
                label: "Wi-Fi"
                subtitle: !root.wifiOn ? "Uit" : (root.wifiName !== "" ? root.wifiName : "Aan")
                active: root.wifiOn
                accent: mocha.accent3
                expandable: root.wifiOn
                isExpanded: root.expanded === "wifi"
                onTriggered: {
                    Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"]);
                    if (root.wifiOn && root.expanded === "wifi") root.expanded = "";
                }
                onExpandRequested: root.toggleExpanded("wifi")
            }
            Pill {
                visible: !root.hasWifi && root.isEthConnected
                icon: "󰈀"
                label: "Bedraad"
                subtitle: "Verbonden"
                active: true
                accent: mocha.accent3
                onTriggered: root.openPanel("network", "eth")
            }
            Pill {
                visible: root.hasBluetooth
                icon: root.bluetoothOn ? "󰂱" : "󰂲"
                label: "Bluetooth"
                subtitle: !root.bluetoothOn ? "Uit"
                    : (root.bluetoothConnected > 0 ? root.bluetoothConnected + " verbonden" : "Aan")
                active: root.bluetoothOn
                accent: mocha.accent1
                expandable: root.bluetoothOn
                isExpanded: root.expanded === "bt"
                onTriggered: {
                    Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/quickshell/network/bluetooth_panel_logic.sh", "--toggle"]);
                    if (root.bluetoothOn && root.expanded === "bt") root.expanded = "";
                }
                onExpandRequested: root.toggleExpanded("bt")
            }
            Pill {
                icon: NotificationService.dnd ? "󰂛" : "󰂚"
                label: "Niet storen"
                subtitle: NotificationService.dnd ? "Aan" : "Uit"
                active: NotificationService.dnd
                accent: mocha.accent2
                onTriggered: NotificationService.toggleDnd()
            }
            Pill {
                icon: root.powerProfileName === "performance" ? "󰓅"
                    : (root.powerProfileName === "power-saver" ? "󰌪" : "󰾅")
                label: "Energie"
                subtitle: root.profileLabel(root.powerProfileName)
                active: root.powerProfileName !== "balanced"
                accent: root.powerProfileName === "performance" ? mocha.accent2 : mocha.accent3
                expandable: true
                isExpanded: root.expanded === "power"
                onTriggered: root.toggleExpanded("power")
                onExpandRequested: root.toggleExpanded("power")
            }
            Pill {
                icon: "󰍹"
                label: "Beeldschermen"
                subtitle: Quickshell.screens.length === 1 ? "1 scherm" : Quickshell.screens.length + " schermen"
                accent: mocha.accent3
                onTriggered: root.openPanel("monitors")
            }
            Pill {
                visible: root.kbLayoutCount > 1
                icon: "󰌌"
                label: "Toetsenbord"
                subtitle: root.kbLayout !== "" ? root.kbLayout : "Volgende indeling"
                accent: mocha.accent1
                onTriggered: {
                    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                    refreshSoon.restart();
                }
            }
        }

        // --- Uitklap onder de pillen ------------------------------------------
        // Groeit vloeiend open en dicht; de inhoud wisselt per pil.
        Rectangle {
            id: drawer
            Layout.fillWidth: true
            Layout.preferredHeight: openHeight
            property real openHeight: root.expanded !== "" ? drawerContent.implicitHeight + 16 : 0
            radius: root.itemRadius
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.30)
            border.width: root.expanded !== "" ? 1 : 0
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
            clip: true
            opacity: root.expanded !== "" ? 1 : 0
            Behavior on openHeight {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
            }

            ColumnLayout {
                id: drawerContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                // Wi-Fi
                Repeater {
                    model: root.expanded === "wifi" ? root.wifiNetworks : []
                    delegate: ListRow {
                        required property var modelData
                        icon: String(modelData.icon || "󰤨")
                        label: String(modelData.ssid || "")
                        detail: modelData.active ? "Verbonden"
                            : (root.busyId === modelData.ssid ? "Verbinden…"
                                : (String(modelData.security || "").trim() !== "" && String(modelData.security) !== "--" ? "󰌾" : ""))
                        highlighted: !!modelData.active
                        onTriggered: if (!modelData.active) root.connectWifi(modelData)
                    }
                }
                Text {
                    visible: root.expanded === "wifi" && root.wifiNetworks.length === 0
                    Layout.fillWidth: true
                    Layout.margins: 6
                    text: "Netwerken zoeken…"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }

                // Bluetooth
                Repeater {
                    model: root.expanded === "bt" ? root.btConnected : []
                    delegate: ListRow {
                        required property var modelData
                        icon: "󰂱"
                        label: String(modelData.name || modelData.mac || "")
                        detail: Number(modelData.battery || 0) > 0 ? modelData.battery + "%" : "Verbonden"
                        highlighted: true
                        onTriggered: root.btAction(modelData, false)
                    }
                }
                Repeater {
                    model: root.expanded === "bt" ? root.btPaired : []
                    delegate: ListRow {
                        required property var modelData
                        icon: "󰂯"
                        label: String(modelData.name || modelData.mac || "")
                        detail: root.busyId === modelData.mac ? "Verbinden…" : ""
                        onTriggered: root.btAction(modelData, true)
                    }
                }
                Text {
                    visible: root.expanded === "bt" && root.btConnected.length === 0 && root.btPaired.length === 0
                    Layout.fillWidth: true
                    Layout.margins: 6
                    text: "Geen gekoppelde apparaten"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }

                // Energieprofielen
                Repeater {
                    model: root.expanded === "power"
                        ? (PowerProfiles.hasPerformanceProfile
                            ? ["power-saver", "balanced", "performance"]
                            : ["power-saver", "balanced"])
                        : []
                    delegate: ListRow {
                        required property string modelData
                        icon: modelData === "performance" ? "󰓅" : (modelData === "power-saver" ? "󰌪" : "󰾅")
                        label: root.profileLabel(modelData)
                        detail: root.powerProfileName === modelData ? "󰄬" : ""
                        highlighted: root.powerProfileName === modelData
                        onTriggered: root.setProfile(modelData)
                    }
                }

                // Naar het volledige paneel, zoals "Meer instellingen" bij GNOME.
                ListRow {
                    visible: root.expanded !== ""
                    icon: "󰒓"
                    label: root.expanded === "wifi" ? "Alle wifi-instellingen"
                        : (root.expanded === "bt" ? "Koppelen en meer" : (root.hasBattery ? "Batterij en energie" : "Energie-instellingen"))
                    muted: true
                    onTriggered: {
                        if (root.expanded === "wifi") root.openPanel("network", "wifi");
                        else if (root.expanded === "bt") root.openPanel("network", "bt");
                        else if (root.hasBattery) root.openPanel("battery");
                        else root.panelSwitchRequested("settings:sessie");
                    }
                }
            }
        }

        // --- Schuifregelaars ---------------------------------------------------
        PanelSlider {
            mocha: mocha
            itemRadius: root.itemRadius
            icon: root.muted || root.volume === 0 ? "󰝟" : (root.volume > 60 ? "󰕾" : "󰖀")
            label: "Volume"
            value: root.volume
            dimmed: root.muted
            accent: mocha.accent3
            detailTooltip: "Geluid & media"
            onIconClicked: root.toggleMute()
            onDragToggled: (dragging) => root.draggingVolume = dragging
            onMoved: (percent) => root.setVolume(percent)
            onDetailRequested: root.openPanel("audiomedia")
        }
        PanelSlider {
            mocha: mocha
            itemRadius: root.itemRadius
            visible: root.brightness >= 0
            icon: "󰃟"
            label: "Helderheid"
            value: root.brightness
            accent: mocha.yellow
            detailTooltip: "Beeldschermen"
            onDragToggled: (dragging) => root.draggingBrightness = dragging
            onMoved: (percent) => root.setBrightness(percent)
            onDetailRequested: root.openPanel("monitors")
        }
    }

    // --- Componenten -----------------------------------------------------------

    // Pil zoals bij GNOME: hoofdvlak schakelt, het pijltje klapt uit.
    component Pill: Rectangle {
        id: pill
        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property bool expandable: false
        property bool isExpanded: false
        property color accent: mocha.primary
        signal triggered()
        signal expandRequested()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 50
        radius: height / 2
        color: active
            ? Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse ? 0.32 : 0.24)
            : (pillMouse.containsMouse
                ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.46)
                : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.30))
        border.width: 1
        border.color: isExpanded
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.70)
            : (active ? Qt.rgba(accent.r, accent.g, accent.b, 0.42) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08))
        scale: pillMouse.pressed ? 0.97 : 1.0

        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on border.color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.triggered()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: pill.active
                    ? Qt.rgba(pill.accent.r, pill.accent.g, pill.accent.b, 0.34)
                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
                Text {
                    anchors.centerIn: parent
                    text: pill.icon
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 16
                    color: pill.active ? pill.accent : mocha.subtext0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: pill.label
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: pill.subtitle
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: pill.active ? pill.accent : mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: pill.expandable
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: expandMouse.containsMouse || pill.isExpanded
                    ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                    : "transparent"
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 14
                    color: expandMouse.containsMouse || pill.isExpanded ? mocha.text : mocha.subtext0
                    rotation: pill.isExpanded ? 90 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                    }
                }
                MouseArea {
                    id: expandMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pill.expandRequested()
                }
            }
        }
    }

    component ListRow: Rectangle {
        id: row
        property string icon: ""
        property string label: ""
        property string detail: ""
        property bool highlighted: false
        property bool muted: false
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 16
        color: rowMouse.containsMouse
            ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
            : (highlighted ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.12) : "transparent")
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
            Text {
                text: row.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 13
                color: row.highlighted ? mocha.primary : mocha.subtext0
            }
            Text {
                Layout.fillWidth: true
                text: row.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: row.highlighted ? Font.DemiBold : Font.Normal
                color: row.muted ? mocha.subtext0 : mocha.text
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                text: row.detail
                font.family: ThemeConfig.iconFont
                font.pixelSize: 10
                color: row.highlighted ? mocha.primary : mocha.subtext0
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }
    }

    component RoundButton: Rectangle {
        id: rb
        property string icon: ""
        property string tooltip: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 16
        color: rbMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        scale: rbMouse.containsMouse ? 1.07 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            anchors.centerIn: parent
            text: rb.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 15
            color: rb.accent
        }
        MouseArea {
            id: rbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.triggered()
        }
    }
}
