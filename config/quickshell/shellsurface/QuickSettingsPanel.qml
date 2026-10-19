import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

// Snelle instellingen: het control-center-patroon van Caelestia en
// dotfiles-arch, geopend vanuit de statustegel (netwerk, bluetooth, batterij).
// Hier staat wat je vaak even omzet. Elke tegel met een pijltje opent het
// bestaande detailpaneel, zodat er niets wegvalt. Geluid en media hebben een
// eigen paneel (AudioMediaPanel); idle staat in het afsluitmenu.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }

    // PanelHost luistert hiernaar: wisselen naar een detailpaneel gebeurt
    // in dezelfde host, dus met dezelfde blob-overgang als een railklik.
    signal panelSwitchRequested(string entryId)

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property int preferredPanelWidth: 400
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

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

    // --- Gepollde state (alleen zolang het paneel geladen is) ---------------
    property int brightness: -1
    property string wifiName: ""
    property int kbLayoutCount: 1
    property string kbLayout: ""
    property bool draggingBrightness: false

    // PanelHost leest dit bij de wissel en zet de modus meteen op het
    // netwerkpaneel, zodat dat direct in de juiste vorm en maat opent.
    property string requestedNetworkMode: ""

    function openPanel(entryId, networkMode) {
        root.requestedNetworkMode = networkMode ? String(networkMode) : "";
        if (networkMode)
            Quickshell.execDetached(["bash", "-lc", "printf '%s' '" + networkMode + "' > /tmp/qs_network_mode"]);
        root.panelSwitchRequested(entryId);
    }

    function profileLabel(name) {
        if (name === "performance") return "Prestaties";
        if (name === "power-saver") return "Energiebesparing";
        return "Gebalanceerd";
    }

    function cycleProfile() {
        let order = PowerProfiles.hasPerformanceProfile
            ? ["power-saver", "balanced", "performance"]
            : ["power-saver", "balanced"];
        let next = order[(order.indexOf(root.powerProfileName) + 1) % order.length];
        if (next === "performance") PowerProfiles.profile = PowerProfile.Performance;
        else if (next === "power-saver") PowerProfiles.profile = PowerProfile.PowerSaver;
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

    function refresh() {
        if (!statePoller.running) statePoller.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: statePoller
        // Eén regel per sleutel, zodat een ontbrekend hulpmiddel (geen
        // brightnessctl, geen jq) alleen dat ene veld leeg laat.
        command: ["bash", "-lc",
            "bri=''; if command -v brightnessctl >/dev/null 2>&1; then bri=$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1{gsub(/%/,\"\",$4); print $4}'); fi; " +
            // Actieve verbinding i.p.v. `dev wifi`: die laatste kan een
            // wifi-scan starten, wat je bij elke poll niet wilt.
            "ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1; exit}'); " +
            "kbn=1; kb=''; if command -v jq >/dev/null 2>&1; then " +
            "kbn=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // \"us\"' | awk -F, '{n=0; for(i=1;i<=NF;i++) if($i!=\"\") n++; print n}'); " +
            "kb=$(hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main==true) | .active_keymap][0] // \"\"'); fi; " +
            "printf 'bri=%s\\nssid=%s\\nkbn=%s\\nkb=%s\\n' \"$bri\" \"$ssid\" \"$kbn\" \"$kb\""
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

                root.wifiName = state.ssid || "";
                let kbCount = parseInt(state.kbn);
                root.kbLayoutCount = isNaN(kbCount) ? 1 : kbCount;
                root.kbLayout = state.kb || "";
            }
        }
    }

    // Na een schakelactie de echte state snel teruglezen in plaats van op
    // de volgende reguliere poll te wachten.
    Timer {
        id: refreshSoon
        interval: 350
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Snelle instellingen"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: Font.Black
                    color: mocha.text
                }
                Text {
                    Layout.fillWidth: true
                    text: root.hasBattery
                        ? "Batterij " + root.batteryPercent + "%" + (root.batteryTimeText() !== "" ? " · " + root.batteryTimeText() : "")
                        : root.profileLabel(root.powerProfileName)
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "󰐥"
                tooltip: "Afsluitmenu"
                accent: mocha.red
                onTriggered: root.openPanel("power")
            }
            IconButton {
                icon: "󰒓"
                tooltip: "Instellingen"
                accent: mocha.subtext1
                onTriggered: root.openPanel("settings")
            }
        }

        // --- Schakeltegels ---------------------------------------------------
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            Tile {
                visible: root.hasWifi
                icon: root.wifiOn ? "󰤨" : "󰤮"
                label: "Wi-Fi"
                subtitle: !root.wifiOn ? "Uit" : (root.wifiName !== "" ? root.wifiName : "Aan")
                active: root.wifiOn
                accent: mocha.accent3
                detailTooltip: "Netwerkpaneel"
                onTriggered: Quickshell.execDetached(["nmcli", "radio", "wifi", root.wifiOn ? "off" : "on"])
                onDetailRequested: root.openPanel("network", "wifi")
            }
            Tile {
                visible: !root.hasWifi && root.isEthConnected
                icon: "󰈀"
                label: "Bedraad"
                subtitle: "Verbonden"
                active: true
                accent: mocha.accent3
                detailTooltip: "Netwerkpaneel"
                onTriggered: root.openPanel("network", "eth")
                onDetailRequested: root.openPanel("network", "eth")
            }
            Tile {
                visible: root.hasBluetooth
                icon: root.bluetoothOn ? "󰂱" : "󰂲"
                label: "Bluetooth"
                subtitle: !root.bluetoothOn ? "Uit"
                    : (root.bluetoothConnected > 0
                        ? root.bluetoothConnected + " verbonden" : "Aan")
                active: root.bluetoothOn
                accent: mocha.accent1
                detailTooltip: "Bluetoothpaneel"
                onTriggered: Quickshell.execDetached([
                    "bash",
                    Quickshell.env("HOME") + "/.config/quickshell/network/bluetooth_panel_logic.sh",
                    "--toggle"
                ])
                onDetailRequested: root.openPanel("network", "bt")
            }
            Tile {
                icon: NotificationService.dnd ? "󰂛" : "󰂚"
                label: "Niet storen"
                subtitle: NotificationService.dnd ? "Aan" : (NotificationService.count > 0 ? NotificationService.count + " meldingen" : "Uit")
                active: NotificationService.dnd
                accent: mocha.accent2
                detailTooltip: "Meldingen"
                onTriggered: NotificationService.toggleDnd()
                onDetailRequested: root.openPanel("notifications")
            }
            Tile {
                icon: root.powerProfileName === "performance" ? "󰓅"
                    : (root.powerProfileName === "power-saver" ? "󰌪" : "󰾅")
                label: "Energieprofiel"
                subtitle: root.profileLabel(root.powerProfileName)
                active: root.powerProfileName !== "balanced"
                accent: root.powerProfileName === "performance" ? mocha.accent2 : mocha.accent3
                detailTooltip: root.hasBattery ? "Batterijpaneel" : ""
                onTriggered: root.cycleProfile()
                onDetailRequested: root.openPanel("battery")
            }
            // Beeldschermen: stond als Monitoren-knop in de rail. Opent de
            // schermindeling (resolutie, positie, hoofdscherm), ook via Super+O.
            Tile {
                icon: "󰍹"
                label: "Beeldschermen"
                subtitle: Quickshell.screens.length === 1 ? "1 scherm" : Quickshell.screens.length + " schermen"
                active: false
                accent: mocha.accent3
                detailTooltip: "Schermindeling"
                onTriggered: root.openPanel("monitors")
                onDetailRequested: root.openPanel("monitors")
            }
            Tile {
                visible: root.kbLayoutCount > 1
                icon: "󰌌"
                label: "Toetsenbord"
                subtitle: root.kbLayout !== "" ? root.kbLayout : "Volgende indeling"
                active: false
                accent: mocha.accent1
                onTriggered: {
                    Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                    refreshSoon.restart();
                }
            }
        }

        // --- Schuifregelaars -------------------------------------------------
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

    // --- Componenten ---------------------------------------------------------

    // Tegel: hoofdvlak schakelt, het pijltje rechts opent het detailpaneel.
    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string label: ""
        property string subtitle: ""
        property bool active: false
        property color accent: mocha.primary
        property string detailTooltip: ""
        signal triggered()
        signal detailRequested()

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 52
        radius: root.itemRadius
        color: active
            ? Qt.rgba(accent.r, accent.g, accent.b, tileMouse.containsMouse ? 0.30 : 0.22)
            : (tileMouse.containsMouse
                ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.42)
                : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.26))
        border.width: 1
        border.color: active
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.42)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        scale: tileMouse.pressed ? 0.97 : 1.0

        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.triggered()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 4
            spacing: 8

            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: Math.min(root.itemRadius, 16)
                color: tile.active
                    ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.30)
                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }
                Text {
                    anchors.centerIn: parent
                    text: tile.icon
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 16
                    color: tile.active ? tile.accent : mocha.subtext0
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    text: tile.label
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: tile.subtitle
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: tile.active ? tile.accent : mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                visible: tile.detailTooltip !== ""
                Layout.preferredWidth: 24
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                radius: Math.min(root.itemRadius, 10)
                color: detailMouse.containsMouse
                    ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                    : "transparent"
                Behavior on color {
                    ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰅂"
                    font.family: "Iosevka Nerd Font"
                    font.pixelSize: 14
                    color: detailMouse.containsMouse ? mocha.text : mocha.subtext0
                }
                MouseArea {
                    id: detailMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tile.detailRequested()
                }
            }
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property string tooltip: ""
        property color accent: mocha.text
        signal triggered()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: ibMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        scale: ibMouse.containsMouse ? 1.07 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            anchors.centerIn: parent
            text: ib.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 15
            color: ib.accent
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }
    }
}
