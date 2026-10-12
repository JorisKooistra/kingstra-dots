import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import ".."

// Snelle instellingen: het control-center-patroon van Caelestia en
// dotfiles-arch. De rail toont hiervoor één compacte statustegel in plaats van
// vijf losse knoppen; hier staat alles wat je vaak even omzet. Elke tegel met
// een pijltje opent het bestaande detailpaneel, zodat er niets wegvalt.
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
    property int volume: 0
    property bool muted: false
    property bool micMuted: false
    property bool micKnown: false
    property int brightness: -1
    property string wifiName: ""
    property int kbLayoutCount: 1
    property string kbLayout: ""
    property bool idleInhibited: false
    property bool draggingVolume: false
    property bool draggingBrightness: false

    function openPanel(entryId, networkMode) {
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

    // Zelfde zoekvolgorde als het afsluitmenu, zodat beide schakelaars
    // dezelfde idle-state lezen en schrijven.
    function idleInhibitCommand(action) {
        let safeAction = String(action || "status").replace(/'/g, "'\"'\"'");
        return "kingstra_idle_action='" + safeAction + "'; " +
            "if command -v kingstra-idle-inhibit >/dev/null 2>&1; then " +
            "kingstra-idle-inhibit \"$kingstra_idle_action\"; " +
            "elif [ -x \"$HOME/.local/bin/kingstra-idle-inhibit\" ]; then " +
            "\"$HOME/.local/bin/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "elif [ -x \"$HOME/.config/shared/scripts/kingstra-idle-inhibit\" ]; then " +
            "\"$HOME/.config/shared/scripts/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "else " +
            "\"$HOME/kingstra-dots/config/shared/scripts/kingstra-idle-inhibit\" \"$kingstra_idle_action\"; " +
            "fi";
    }

    function setIdleInhibited(on) {
        root.idleInhibited = on;
        Quickshell.execDetached(["bash", "-lc", root.idleInhibitCommand(on ? "on" : "off")]);
        idleRefreshTimer.restart();
    }

    function setVolume(percent) {
        let v = Math.max(0, Math.min(100, Math.round(percent)));
        root.volume = v;
        Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v + "%"]);
    }

    function setBrightness(percent) {
        let v = Math.max(1, Math.min(100, Math.round(percent)));
        root.brightness = v;
        Quickshell.execDetached(["bash", "-lc", "command -v brightnessctl >/dev/null 2>&1 && brightnessctl -q set " + v + "%"]);
    }

    function refresh() {
        if (!statePoller.running) statePoller.running = true;
        if (!idleStatusProc.running) idleStatusProc.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: statePoller
        // Eén regel per sleutel, zodat een ontbrekend hulpmiddel (geen
        // brightnessctl, geen jq) alleen dat ene veld leeg laat.
        command: ["bash", "-lc",
            "sink=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | head -n1); " +
            "src=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | head -n1); " +
            "bri=''; if command -v brightnessctl >/dev/null 2>&1; then bri=$(brightnessctl -m 2>/dev/null | awk -F, 'NR==1{gsub(/%/,\"\",$4); print $4}'); fi; " +
            // Actieve verbinding i.p.v. `dev wifi`: die laatste kan een
            // wifi-scan starten, wat je bij elke poll niet wilt.
            "ssid=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | awk -F: '$2==\"802-11-wireless\"{print $1; exit}'); " +
            "kbn=1; kb=''; if command -v jq >/dev/null 2>&1; then " +
            "kbn=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // \"us\"' | awk -F, '{n=0; for(i=1;i<=NF;i++) if($i!=\"\") n++; print n}'); " +
            "kb=$(hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[] | select(.main==true) | .active_keymap][0] // \"\"'); fi; " +
            "printf 'sink=%s\\nsrc=%s\\nbri=%s\\nssid=%s\\nkbn=%s\\nkb=%s\\n' \"$sink\" \"$src\" \"$bri\" \"$ssid\" \"$kbn\" \"$kb\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let state = {};
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let eq = lines[i].indexOf("=");
                    if (eq > 0) state[lines[i].substring(0, eq)] = lines[i].substring(eq + 1).trim();
                }

                let sink = state.sink || "";
                let sinkMatch = sink.match(/Volume:\s+([\d.]+)/);
                if (sinkMatch && !root.draggingVolume) root.volume = Math.round(parseFloat(sinkMatch[1]) * 100);
                root.muted = sink.indexOf("[MUTED]") !== -1;

                let source = state.src || "";
                root.micKnown = /Volume:/.test(source);
                root.micMuted = source.indexOf("[MUTED]") !== -1;

                let bright = parseInt(state.bri);
                if (!root.draggingBrightness) root.brightness = isNaN(bright) ? -1 : bright;

                root.wifiName = state.ssid || "";
                let kbCount = parseInt(state.kbn);
                root.kbLayoutCount = isNaN(kbCount) ? 1 : kbCount;
                root.kbLayout = state.kb || "";
            }
        }
    }

    Process {
        id: idleStatusProc
        command: ["bash", "-lc", root.idleInhibitCommand("status")]
        stdout: StdioCollector {
            onStreamFinished: root.idleInhibited = this.text.trim() === "on"
        }
    }

    Timer {
        id: idleRefreshTimer
        interval: 450
        repeat: false
        onTriggered: if (!idleStatusProc.running) idleStatusProc.running = true
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
                icon: root.idleInhibited ? "󰅶" : "󰾪"
                label: "Wakker houden"
                subtitle: root.idleInhibited ? "Scherm blijft aan" : "Uit"
                active: root.idleInhibited
                accent: mocha.yellow
                onTriggered: root.setIdleInhibited(!root.idleInhibited)
            }
            Tile {
                visible: root.micKnown
                icon: root.micMuted ? "󰍭" : "󰍬"
                label: "Microfoon"
                subtitle: root.micMuted ? "Gedempt" : "Aan"
                active: !root.micMuted
                accent: mocha.accent1
                detailTooltip: "Geluidspaneel"
                onTriggered: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
                onDetailRequested: root.openPanel("volume")
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
        SliderRow {
            icon: root.muted || root.volume === 0 ? "󰝟" : (root.volume >= 70 ? "󰕾" : (root.volume >= 30 ? "󰖀" : "󰕿"))
            label: "Volume"
            value: root.volume
            dimmed: root.muted
            accent: mocha.accent3
            detailTooltip: "Geluidspaneel"
            onIconClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
            onDragToggled: (dragging) => root.draggingVolume = dragging
            onMoved: (percent) => root.setVolume(percent)
            onDetailRequested: root.openPanel("volume")
        }
        SliderRow {
            visible: root.brightness >= 0
            icon: "󰃟"
            label: "Helderheid"
            value: root.brightness
            accent: mocha.yellow
            detailTooltip: "Monitoren"
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

    component SliderRow: RowLayout {
        id: slider
        property string icon: ""
        property string label: ""
        property int value: 0
        property bool dimmed: false
        property color accent: mocha.primary
        property string detailTooltip: ""
        signal iconClicked()
        signal moved(real percent)
        signal dragToggled(bool dragging)
        signal detailRequested()

        Layout.fillWidth: true
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: Math.min(root.itemRadius, 16)
            color: iconMouse.containsMouse
                ? Qt.rgba(slider.accent.r, slider.accent.g, slider.accent.b, 0.22)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("fast") }
            }
            Text {
                anchors.centerIn: parent
                text: slider.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 16
                color: slider.dimmed ? mocha.subtext0 : slider.accent
            }
            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: slider.iconClicked()
            }
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 32

            Rectangle {
                id: groove
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 10
                radius: height / 2
                color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

                Rectangle {
                    width: Math.max(groove.height, groove.width * Math.max(0, Math.min(100, slider.value)) / 100)
                    height: parent.height
                    radius: parent.radius
                    color: slider.dimmed
                        ? Qt.rgba(slider.accent.r, slider.accent.g, slider.accent.b, 0.35)
                        : slider.accent
                    Behavior on width {
                        enabled: !trackMouse.pressed
                        NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                    }
                    Behavior on color {
                        ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                    }
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.bottom: groove.top
                anchors.bottomMargin: 2
                text: slider.label + "  " + Math.max(0, slider.value) + "%"
                font.family: ThemeConfig.monoFont
                font.pixelSize: 9
                font.weight: Font.Bold
                color: mocha.subtext0
            }

            MouseArea {
                id: trackMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    slider.moved(Math.max(0, Math.min(1, mx / Math.max(1, width))) * 100);
                }
                onPressed: (mouse) => { slider.dragToggled(true); apply(mouse.x); }
                onPositionChanged: (mouse) => { if (pressed) apply(mouse.x); }
                onReleased: slider.dragToggled(false)
                onCanceled: slider.dragToggled(false)
                onWheel: (wheel) => {
                    slider.moved(slider.value + (wheel.angleDelta.y > 0 ? 5 : -5));
                    wheel.accepted = true;
                }
            }
        }

        Rectangle {
            visible: slider.detailTooltip !== ""
            Layout.preferredWidth: 24
            Layout.preferredHeight: 28
            radius: Math.min(root.itemRadius, 10)
            color: sliderDetailMouse.containsMouse
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
                color: sliderDetailMouse.containsMouse ? mocha.text : mocha.subtext0
            }
            MouseArea {
                id: sliderDetailMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: slider.detailRequested()
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
