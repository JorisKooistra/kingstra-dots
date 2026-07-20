import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import ".."

Item {
    id: root
    required property var shellWindow
    required property var mocha

    readonly property bool railEnabled: ThemeConfig.barRailEnabled
    readonly property bool stripEnabled: ThemeConfig.barStatusStripEnabled
    readonly property bool stripOnBottom: ThemeConfig.barStatusStripEdge === "bottom"
    readonly property bool railOnRight: ThemeConfig.barRailEdge === "right"
    readonly property int railWidth: ThemeConfig.barRailWidth
    readonly property int stripHeight: ThemeConfig.barStatusStripHeight
    // De rail bezit de volledige zijrand (top→bottom). De strip begint al bij
    // rail.right, dus zonder deze full-height rail bleef er een gat in de
    // hoek waar rail en strip elkaar niet raakten ("de ontbrekende hoek").
    readonly property int railTopOffset: 0
    readonly property int railBottomOffset: 0
    // Fillet-radius voor de concave hoek waar de content in de bar-L nestelt.
    readonly property int cornerR: Math.max(20, ThemeConfig.styleWidgetRadius + 14)
    // Dunne omlijning rechts/onder, zodat de content een volledig afgerond
    // kader krijgt (caelestia-stijl). Links/boven kosten al rail+strip.
    readonly property int shellBorderWidth: 8
    readonly property int cornerStrokeWidth: 2
    readonly property int cornerSeamOverlap: 3
    readonly property string styleFamily: String(ThemeConfig.styleFamily || "").toLowerCase()
    readonly property bool paperStyle: styleFamily === "paper"
    readonly property bool organicStyle: styleFamily === "organic"
    readonly property bool modernStyle: styleFamily === "modern"
    readonly property bool monoStyle: styleFamily === "mono"
    // --- Matugen twee-kleur chrome ------------------------------------------
    // De bar leunde voorheen op crust/base (bijna-zwart), waardoor matugen
    // visueel vrijwel niets deed. We tinten nu een donker chrome-oppervlak met
    // twee onderscheiden wallpaper-hues en leggen daar een subtiele
    // twee-kleur-gradient overheen (rail verticaal, strip horizontaal).
    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t,
                       1.0);
    }
    // Donkere basis waarop we tinten; behoudt de bestaande donkerte per stijl.
    readonly property color barFloor: paperStyle ? mocha.mantle
        : (modernStyle || monoStyle ? mocha.crust : mocha.base)
    readonly property real barFillAlpha: paperStyle ? 0.82
        : (modernStyle || monoStyle ? 0.97 : Math.min(0.98, ThemeConfig.barOpacity + 0.04))
    // Twee visueel onderscheiden wallpaper-hues. Mono blijft bewust neutraal.
    readonly property color barHueA: mocha.primary
    readonly property color barHueB: mocha.secondary || mocha.accent2 || mocha.primary
    readonly property real barTintK: monoStyle ? 0.04 : (paperStyle ? 0.12 : 0.30)
    readonly property color barGradStart: {
        let c = _mix(barFloor, barHueA, barTintK);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color barGradEnd: {
        let c = _mix(barFloor, barHueB, barTintK * 1.1);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    // Het kader draagt twee gespiegelde sweeps: rail en strip lopen hue A -> B,
    // de rechter- en onderrand lopen terug B -> A. Daardoor krijgen beide
    // diagonalen gelijke hoeken (linksboven = rechtsonder = A, rechtsboven =
    // linksonder = B) en sluit de gradient rondom op zichzelf aan.
    // De onderrand loopt B -> A; in het midden (waar de launcher staat) is dat
    // exact het halverwege-punt. Launcher en aansluitbogen nemen die kleur over.
    readonly property color barGradCenter: {
        let c = _mix(barGradEnd, barGradStart, 0.5);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color barHueCenter: _mix(barHueB, barHueA, 0.5)
    readonly property real chromeAccentAlpha: monoStyle ? 0.45 : 1.0
    // Geometrie van de launcher, doorgegeven vanuit ShellSurface, zodat de
    // onderrand eromheen kan buigen i.p.v. er blind onderdoor te lopen.
    property bool launcherOpen: false
    property real launcherX: 0
    property real launcherWidth: 0
    function _clamp01(v) {
        return Math.max(0.0, Math.min(1.0, Number(v) || 0.0));
    }
    function _bottomGradientT(screenX) {
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth);
        return root._clamp01((screenX - root.railWidth) / w);
    }
    function _bottomAccentT(screenX) {
        let x0 = root.railWidth + root.cornerR;
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth - root.cornerR * 2);
        return root._clamp01((screenX - x0) / w);
    }
    function _stripFillAt(screenX) {
        let w = Math.max(1, root.width - root.railWidth);
        return root._mix(root.barGradStart, root.barGradEnd, root._clamp01((screenX - root.railWidth) / w));
    }
    function _railFillAt(screenY) {
        return root._mix(root.barGradStart, root.barGradEnd, root._clamp01(screenY / Math.max(1, root.height)));
    }
    function _rightFillAt(screenY) {
        let h = Math.max(1, root.height - root.stripHeight);
        return root._mix(root.barGradEnd, root.barGradStart, root._clamp01((screenY - root.stripHeight) / h));
    }
    function _bottomFillAt(screenX) {
        return root._mix(root.barGradEnd, root.barGradStart, root._bottomGradientT(screenX));
    }
    function _stripHueAt(screenX) {
        let x0 = root.railWidth + root.cornerR;
        let w = Math.max(1, root.width - root.railWidth - root.shellBorderWidth - root.cornerR * 2);
        return root._mix(root.barHueA, root.barHueB, root._clamp01((screenX - x0) / w));
    }
    function _railHueAt(screenY) {
        let y0 = root.stripHeight + root.cornerR;
        let h = Math.max(1, root.height - root.stripHeight - root.shellBorderWidth - root.cornerR * 2);
        return root._mix(root.barHueA, root.barHueB, root._clamp01((screenY - y0) / h));
    }
    function _rightHueAt(screenY) {
        let y0 = root.stripHeight + root.cornerR;
        let h = Math.max(1, root.height - root.stripHeight - root.shellBorderWidth - root.cornerR * 2);
        return root._mix(root.barHueB, root.barHueA, root._clamp01((screenY - y0) / h));
    }
    function _bottomHueAt(screenX) {
        return root._mix(root.barHueB, root.barHueA, root._bottomAccentT(screenX));
    }
    readonly property color launcherFillLeft: _bottomFillAt(launcherX)
    readonly property color launcherFillRight: _bottomFillAt(launcherX + launcherWidth)
    readonly property color launcherHueLeft: _bottomHueAt(launcherX)
    readonly property color launcherHueRight: _bottomHueAt(launcherX + launcherWidth)

    readonly property color panelColor: {
        let c = _mix(barFloor, barHueA, barTintK * 0.6);
        return Qt.rgba(c.r, c.g, c.b, barFillAlpha);
    }
    readonly property color pillColor: {
        if (paperStyle) return Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.38);
        if (modernStyle) return Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.24);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08);
        return Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.58);
    }
    readonly property color pillHoverColor: {
        if (modernStyle) return Qt.rgba(mocha.teal.r, mocha.teal.g, mocha.teal.b, 0.22);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.16);
        return Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, paperStyle ? 0.64 : 0.86);
    }
    readonly property color borderColor: {
        if (paperStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.16);
        if (modernStyle) return Qt.rgba(mocha.accent2.r, mocha.accent2.g, mocha.accent2.b, 0.30);
        if (monoStyle) return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.34);
        return Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06 + ThemeConfig.styleOutlineStrength);
    }
    readonly property color hotColor: {
        if (monoStyle) return mocha.text;
        if (modernStyle) return mocha.teal || mocha.accent2 || mocha.mauve;
        if (paperStyle) return mocha.lavender || mocha.accent2 || mocha.mauve;
        return mocha.accent2 || mocha.mauve;
    }
    // --- Special workspaces (scratchpads: spotify, discord, ...) -------------
    // Hyprland geeft deze een negatieve id en de naam "special:<naam>". De
    // interne qs-master overlay laten we bewust weg.
    readonly property var specialWorkspaces: {
        let out = [];
        let list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            let n = String(list[i].name || "");
            if (n.indexOf("special:") !== 0) continue;
            let short = n.substring(8);
            if (short === "qs-master" || short === "") continue;
            out.push({ wsName: short, windows: list[i].toplevels.values.length });
        }
        out.sort((a, b) => a.wsName < b.wsName ? -1 : 1);
        return out;
    }
    // Welke special workspace staat open op de gefocuste monitor?
    readonly property string activeSpecial: {
        let m = Hyprland.focusedMonitor;
        if (!m || !m.lastIpcObject) return "";
        let sw = m.lastIpcObject.specialWorkspace;
        if (!sw || !sw.name) return "";
        let n = String(sw.name);
        return n.indexOf("special:") === 0 ? n.substring(8) : n;
    }

    function specialIcon(name) {
        if (name === "spotify") return "\uf1bc";
        if (name === "discord") return "\udb81\ude6f";
        return "\udb81\udcfe";
    }

    function toggleSpecial(name) {
        Quickshell.execDetached(["bash", "-lc", "hyprctl dispatch togglespecialworkspace " + name]);
    }

    readonly property Item railHitRegion: railHitArea
    readonly property Item stripHitRegion: stripHitArea
    property string activeMode: "office"
    property var moduleList: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications"]
    property bool barAutoHide: false
    property bool autoHideVisible: true
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: Qt.formatDateTime(new Date(), "ddd d MMM")
    property int volumeWheelAccumulator: 0
    property int workspaceWheelAccumulator: 0
    property int _volRaw: 0
    property bool isMuted: false
    readonly property bool railContentVisible: !barAutoHide || autoHideVisible || railHover.hovered
    readonly property bool stripContentVisible: !barAutoHide || autoHideVisible || stripHover.hovered
    // Anker van de laatst getriggerde knop (host-coords), zodat panelen uit
    // de knop groeien i.p.v. uit een vaste schermhoek.
    property real lastTriggerX: 0
    property real lastTriggerY: 0
    signal panelRequested(string sourceEntryId, real anchorX, real anchorY)

    function _defaultModules(mode) {
        if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "fps", "battery", "volume", "game_launcher", "clock"];
        if (mode === "media")  return ["volume", "brightness", "media_controls", "battery", "clock"];
        return ["workspaces", "clock", "updates", "cpu_temp", "ram_usage", "network", "battery", "volume", "bluetooth", "notifications"];
    }

    function _normalizeModules(mode, modules) {
        let normalized = Array.isArray(modules) ? modules.slice() : [];
        if (mode === "office" && normalized.indexOf("updates") === -1) normalized.push("updates");
        if (mode === "office" && normalized.indexOf("cpu_temp") === -1) normalized.push("cpu_temp");
        if ((mode === "office" || mode === "gaming" || mode === "media")
                && normalized.indexOf("battery") === -1) {
            normalized.push("battery");
        }
        return normalized;
    }

    function moduleEnabled(name) {
        return Array.isArray(moduleList) && moduleList.indexOf(name) !== -1;
    }

    function anyModuleEnabled(names) {
        for (let i = 0; i < names.length; i++) {
            if (moduleEnabled(names[i])) return true;
        }
        return false;
    }

    function applyModeState(rawText) {
        if (!rawText) return;
        try {
            let m = JSON.parse(rawText);
            let mode = m.name || "office";
            let resolvedModules = (m.modules && m.modules.length > 0)
                ? m.modules
                : root._defaultModules(mode);
            root.activeMode = mode;
            root.moduleList = root._normalizeModules(mode, resolvedModules);
            root.barAutoHide = m.bar_autohide === true;
            root.autoHideVisible = true;
            if (root.barAutoHide) autoHideTimer.restart();
            else autoHideTimer.stop();
        } catch(e) {}
    }

    function togglePanel(target) {
        panelRequested(target, lastTriggerX, lastTriggerY);
    }

    function launchWalker() {
        Quickshell.execDetached(["bash", "-lc", "walker"]);
    }

    function switchWorkspace(wsId) {
        Quickshell.execDetached([
            "bash",
            "-lc",
            Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh " + wsId
        ]);
    }

    function handleWorkspaceWheel(deltaY, workspaceCount) {
        if (!deltaY || deltaY === 0) return;
        root.workspaceWheelAccumulator += deltaY;
        let steps = 0;
        while (root.workspaceWheelAccumulator >= 120) { steps -= 1; root.workspaceWheelAccumulator -= 120; }
        while (root.workspaceWheelAccumulator <= -120) { steps += 1; root.workspaceWheelAccumulator += 120; }
        if (steps === 0) return;

        let monitor = root.shellWindow && root.shellWindow.screen ? root.shellWindow.screen.name : "";
        Quickshell.execDetached([
            "bash",
            Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-scroll-monitor.sh",
            monitor,
            steps > 0 ? "next" : "prev",
            String(Math.max(1, workspaceCount || 8)),
            String(Math.abs(steps))
        ]);
    }

    function handleVolumeWheel(deltaY) {
        if (!deltaY || deltaY === 0) return;
        root.volumeWheelAccumulator += deltaY;
        let steps = 0;
        while (root.volumeWheelAccumulator >= 120) { steps += 1; root.volumeWheelAccumulator -= 120; }
        while (root.volumeWheelAccumulator <= -120) { steps -= 1; root.volumeWheelAccumulator += 120; }
        if (steps === 0) return;

        Quickshell.execDetached([
            "bash",
            "-lc",
            steps > 0
                ? "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + steps + "%+"
                : "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.abs(steps) + "%-"
        ]);
        if (!volPoller.running) volPoller.running = true;
    }

    FileView {
        id: modeFileView
        path: Quickshell.env("HOME") + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.applyModeState(__text)
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: modeFileView.reload()
    }

    Timer {
        id: autoHideTimer
        interval: 2400
        repeat: false
        onTriggered: if (root.barAutoHide && !railHover.hovered && !stripHover.hovered) root.autoHideVisible = false
    }

    readonly property bool hasWifi: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return true;
        }
        return false;
    }
    readonly property bool isWifiOn: {
        if (!Networking.wifiEnabled) return false;
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi && devs[i].connected) return true;
        }
        return false;
    }
    readonly property bool isEthConnected: {
        var devs = Networking.devices.values;
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wired && devs[i].connected) return true;
        }
        return false;
    }
    readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null
    readonly property bool isBtOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
    readonly property bool hasBattery: UPower.displayDevice !== null && UPower.displayDevice.isLaptopBattery
    readonly property int batCap: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property bool isSoundActive: !isMuted && _volRaw > 0
    readonly property string volPercent: _volRaw + "%"
    readonly property string volIcon: {
        if (isMuted || _volRaw === 0) return "󰝟";
        if (_volRaw >= 70) return "󰕾";
        if (_volRaw >= 30) return "󰖀";
        return "󰕿";
    }
    readonly property var activePlayer: {
        var players = Mpris.players.values;
        for (var i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool mediaVisible: activePlayer !== null
        && String(activePlayer.trackTitle || "").trim() !== ""
        && activePlayer.playbackState !== MprisPlaybackState.Stopped

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            let now = new Date();
            root.timeText = Qt.formatDateTime(now, "HH:mm");
            root.dateText = Qt.formatDateTime(now, "ddd d MMM");
        }
    }

    Process {
        id: volPoller
        command: ["bash", "-lc", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let line = this.text.trim();
                let match = line.match(/Volume:\s+([\d.]+)/);
                if (match) root._volRaw = Math.round(parseFloat(match[1]) * 100);
                root.isMuted = line.indexOf("[MUTED]") !== -1;
            }
        }
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: if (!volPoller.running) volPoller.running = true
    }

    Item {
        id: railHitArea
        visible: root.railEnabled
        anchors.top: parent.top
        anchors.topMargin: root.railTopOffset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.railBottomOffset
        anchors.left: root.railOnRight ? undefined : parent.left
        anchors.right: root.railOnRight ? parent.right : undefined
        width: root.railWidth

        HoverHandler {
            id: railHover
            onHoveredChanged: {
                if (hovered) {
                    root.autoHideVisible = true;
                } else if (root.barAutoHide) {
                    autoHideTimer.restart();
                }
            }
        }
    }

    Rectangle {
        id: rail
        visible: root.railEnabled
        anchors.fill: railHitArea
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.barGradStart }
            GradientStop { position: 1.0; color: root.barGradEnd }
        }
        border.width: 0
        opacity: root.railContentVisible ? 1 : 0.82
        transform: Translate {
            id: railSlide
            x: root.railContentVisible ? 0 : (root.railOnRight ? root.railWidth - 7 : -root.railWidth + 7)
            Behavior on x {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
        }

        // Accent-"spine": twee wallpaper-hues over de binnenrand van de rail.
        Rectangle {
            visible: !root.cornersActive
            width: 2
            anchors.top: parent.top
            // Boven de strip is dit een interne naad, geen buitenrand; daar
            // hoort geen lijn. De boog neemt het hoekstuk voor zijn rekening.
            anchors.topMargin: root.cornersActive ? root.stripHeight + root.cornerR - root.cornerSeamOverlap : 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.cornersActive ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
            anchors.left: root.railOnRight ? parent.left : undefined
            anchors.right: root.railOnRight ? undefined : parent.right
            opacity: root.chromeAccentAlpha
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.barHueA }
                GradientStop { position: 1.0; color: root.barHueB }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 7
            spacing: 7

            RailButton { tooltip: "Launcher";
                icon: "󰣇"
                accent: root.hotColor
                onTriggered: root.togglePanel("launcher")
            }

            ColumnLayout {
                visible: root.moduleEnabled("workspaces")
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool active: Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool occupied: {
                            var list = Hyprland.workspaces.values;
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === wsId && list[i].toplevels.values.length > 0) return true;
                            }
                            return false;
                        }
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (wsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? root.pillColor : "transparent"))
                        border.width: active || occupied ? 0 : 1
                        border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: wsId
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 12
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.mocha.base : root.mocha.text
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.switchWorkspace(wsId)
                            onWheel: (wheel) => {
                                root.handleWorkspaceWheel(wheel.angleDelta.y, 8);
                                wheel.accepted = true;
                            }
                        }
                    }
                }
            }

            // Special workspaces (scratchpads) — alleen tonen als ze bestaan.
            ColumnLayout {
                visible: root.specialWorkspaces.length > 0
                Layout.fillWidth: true
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 2
                    Layout.bottomMargin: 2
                    color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                }

                Repeater {
                    model: root.specialWorkspaces
                    delegate: Rectangle {
                        id: spPill
                        required property var modelData
                        readonly property bool active: root.activeSpecial === modelData.wsName
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (spMouse.containsMouse ? root.pillHoverColor : root.pillColor)
                        scale: spMouse.containsMouse ? 1.07 : 1.0
                        Behavior on color {
                            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.specialIcon(spPill.modelData.wsName)
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 14
                            color: spPill.active ? root.mocha.base : root.mocha.text
                        }

                        MouseArea {
                            id: spMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.showTooltip(spPill, spPill.modelData.wsName, true)
                            onExited: root.hideTooltip(spPill.modelData.wsName)
                            onClicked: root.toggleSpecial(spPill.modelData.wsName)
                        }
                    }
                }
            }

            RailButton { tooltip: "Focus";
                visible: root.activeMode === "office" || root.moduleEnabled("focus")
                icon: "󰥔"
                accent: root.mocha.peach
                onTriggered: root.togglePanel("focustime")
            }

            RailButton { tooltip: "Systeem";
                visible: root.anyModuleEnabled(["cpu_temp", "gpu_temp", "ram_usage", "fps"])
                icon: "󰍛"
                accent: root.mocha.teal
                onTriggered: root.togglePanel("performance")
            }

            Item { Layout.fillHeight: true }

            RailButton { tooltip: "Netwerk";
                visible: root.moduleEnabled("network") && root.hasWifi
                icon: root.isWifiOn ? "󰤨" : "󰤮"
                accent: root.isWifiOn ? root.mocha.blue : root.mocha.subtext0
                onTriggered: root.togglePanel("network")
            }
            RailButton { tooltip: "Bedraad netwerk";
                visible: root.moduleEnabled("network") && !root.hasWifi && root.isEthConnected
                icon: "󰈀"
                accent: root.mocha.teal
                onTriggered: {
                    Quickshell.execDetached(["bash", "-lc", "printf eth > /tmp/qs_network_mode"]);
                    root.togglePanel("network");
                }
            }
            RailButton { tooltip: "Bluetooth";
                visible: root.moduleEnabled("bluetooth") && root.hasBluetooth
                icon: root.isBtOn ? "󰂱" : "󰂲"
                accent: root.isBtOn ? root.mocha.mauve : root.mocha.subtext0
                onTriggered: {
                    Quickshell.execDetached(["bash", "-lc", "printf bt > /tmp/qs_network_mode"]);
                    root.togglePanel("network");
                }
            }
            RailButton { tooltip: "Volume";
                visible: root.moduleEnabled("volume")
                icon: root.volIcon
                text: root.volPercent
                accent: root.isSoundActive ? root.mocha.peach : root.mocha.subtext0
                onTriggered: root.togglePanel("volume")
                onWheelDelta: (delta) => root.handleVolumeWheel(delta)
            }
            RailButton { tooltip: "Batterij";
                visible: root.moduleEnabled("battery") && root.hasBattery
                icon: "󰁹"
                text: root.batCap + "%"
                accent: root.mocha.yellow
                onTriggered: root.togglePanel("battery")
            }
            RailButton { tooltip: "Afsluitmenu";
                icon: "󰐥"
                accent: root.mocha.red
                onTriggered: root.togglePanel("power")
            }
            RailButton { tooltip: "Instellingen";
                visible: root.activeMode !== "media"
                icon: "󰒓"
                accent: root.mocha.subtext1
                onTriggered: root.togglePanel("settings")
            }
        }
    }

    Item {
        id: statusStripZone
        visible: root.stripEnabled
        anchors.top: root.stripOnBottom ? undefined : parent.top
        anchors.bottom: root.stripOnBottom ? parent.bottom : undefined
        anchors.left: root.railEnabled && !root.railOnRight ? rail.right : parent.left
        anchors.right: root.railEnabled && root.railOnRight ? rail.left : parent.right
        height: root.stripHeight

        Item {
            id: stripHitArea
            anchors.fill: parent

            HoverHandler {
                id: stripHover
                onHoveredChanged: {
                    if (hovered) {
                        root.autoHideVisible = true;
                    } else if (root.barAutoHide) {
                        autoHideTimer.restart();
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.barGradStart }
                GradientStop { position: 1.0; color: root.barGradEnd }
            }
            border.width: 0
            opacity: root.stripContentVisible ? 1 : 0.84
            transform: Translate {
                id: stripSlide
                y: root.stripContentVisible ? 0 : (root.stripOnBottom ? root.stripHeight - 6 : -root.stripHeight + 6)
                Behavior on y {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
                }
            }
            Behavior on opacity {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("standard") }
            }

            // Accent-lijn: twee wallpaper-hues over de buitenrand van de strip.
            Rectangle {
                visible: !root.cornersActive
                height: 2
                anchors.left: parent.left
                anchors.leftMargin: root.cornersActive ? root.cornerR - root.cornerSeamOverlap : 0
                anchors.right: parent.right
                anchors.rightMargin: root.cornersActive ? root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap : 0
                anchors.top: root.stripOnBottom ? parent.top : undefined
                anchors.bottom: root.stripOnBottom ? undefined : parent.bottom
                opacity: root.chromeAccentAlpha
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.barHueA }
                    GradientStop { position: 1.0; color: root.barHueB }
                }
            }

            RowLayout {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Repeater {
                    model: root.railEnabled || !root.moduleEnabled("workspaces") ? 0 : 8
                    delegate: Rectangle {
                        required property int index
                        readonly property int wsId: index + 1
                        readonly property bool active: Hyprland.focusedWorkspace !== null
                            && Hyprland.focusedWorkspace.id === wsId
                        readonly property bool occupied: {
                            var list = Hyprland.workspaces.values;
                            for (var i = 0; i < list.length; i++) {
                                if (list[i].id === wsId && list[i].toplevels.values.length > 0) return true;
                            }
                            return false;
                        }
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 24
                        radius: Math.min(6, ThemeConfig.styleWidgetRadius)
                        color: active ? root.hotColor
                            : (wsMouse.containsMouse ? root.pillHoverColor
                                : (occupied ? root.pillColor : "transparent"))
                        border.width: active || occupied ? 0 : 1
                        border.color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.14)
                        Text {
                            anchors.centerIn: parent
                            text: wsId
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 11
                            font.weight: active ? Font.Black : Font.Bold
                            color: active ? root.mocha.base : root.mocha.text
                        }
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.switchWorkspace(wsId)
                            onWheel: (wheel) => {
                                root.handleWorkspaceWheel(wheel.angleDelta.y, 8);
                                wheel.accepted = true;
                            }
                        }
                    }
                }
                StripButton { tooltip: "Meldingen"; visible: root.moduleEnabled("notifications"); icon: "󰍜"; accent: root.mocha.yellow; onTriggered: Quickshell.execDetached(["bash", "-lc", "swaync-client -t -sw"]) }
                StripButton { tooltip: "Agenda"; visible: root.moduleEnabled("clock"); icon: "󰃰"; accent: root.mocha.blue; onTriggered: root.togglePanel("calendar") }
                StripButton { tooltip: "Monitoren"; visible: root.anyModuleEnabled(["updates", "cpu_temp", "gpu_temp", "ram_usage", "fps", "brightness"]); icon: "󰍹"; accent: root.mocha.teal; onTriggered: root.togglePanel("monitors") }
                StripButton { tooltip: "Games"; visible: root.moduleEnabled("game_launcher"); icon: "󰊴"; accent: root.mocha.mauve; onTriggered: root.togglePanel("gaming") }
            }

            RowLayout {
                anchors.centerIn: parent
                visible: root.moduleEnabled("clock")
                spacing: 10
                Text {
                    text: root.timeText
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    color: root.hotColor
                    horizontalAlignment: Text.AlignRight
                }
                Rectangle {
                    width: 1
                    height: 16
                    color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.18)
                }
                Text {
                    text: root.dateText
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: root.mocha.subtext0
                    horizontalAlignment: Text.AlignLeft
                }
            }

            RowLayout {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MediaPill {}

                StripButton { tooltip: "Netwerk";
                    visible: !root.railEnabled && root.moduleEnabled("network") && root.hasWifi
                    icon: root.isWifiOn ? "󰤨" : "󰤮"
                    accent: root.isWifiOn ? root.mocha.blue : root.mocha.subtext0
                    onTriggered: root.togglePanel("network")
                }
                StripButton { tooltip: "Bedraad netwerk";
                    visible: !root.railEnabled && root.moduleEnabled("network") && !root.hasWifi && root.isEthConnected
                    icon: "󰈀"
                    accent: root.mocha.teal
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-lc", "printf eth > /tmp/qs_network_mode"]);
                        root.togglePanel("network");
                    }
                }
                StripButton { tooltip: "Volume";
                    // Rail bezit de systeemcontrols; strip toont ze alleen zonder rail.
                    visible: !root.railEnabled && root.moduleEnabled("volume")
                    icon: root.volIcon
                    accent: root.isSoundActive ? root.mocha.peach : root.mocha.subtext0
                    onTriggered: root.togglePanel("volume")
                    onWheelDelta: (delta) => root.handleVolumeWheel(delta)
                }
                StripButton { tooltip: "Batterij";
                    visible: !root.railEnabled && root.moduleEnabled("battery") && root.hasBattery
                    icon: "󰁹"
                    accent: root.mocha.yellow
                    onTriggered: root.togglePanel("battery")
                }
                StripButton { tooltip: "Afsluitmenu";
                    icon: "󰐥"
                    accent: root.mocha.red
                    onTriggered: root.togglePanel("power")
                }
                StripButton { tooltip: "Instellingen"; visible: !root.railEnabled && root.activeMode !== "media"; icon: "󰒓"; accent: root.mocha.subtext1; onTriggered: root.togglePanel("settings") }
            }
        }
    }

    // Concave binnenhoek waar rail (links) en strip (boven) samenkomen, zodat
    // de content vloeiend afgerond in de bar-L nestelt i.p.v. een harde 90°.
    // Shape rendert declaratief (geen requestPaint nodig, i.t.t. Canvas).
    readonly property bool cornersActive: railEnabled && stripEnabled && !railOnRight && !stripOnBottom
    // --- Dunne omlijning rechts en onder --------------------------------------
    // Samen met rail (links) en strip (boven) vormt dit een gesloten kader om
    // de content, met afgeronde binnenhoeken.
    Rectangle {
        id: rightBorder
        visible: root.cornersActive
        x: root.width - root.shellBorderWidth
        y: root.stripHeight
        width: root.shellBorderWidth
        height: root.height - root.stripHeight
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: root.barGradEnd }
            GradientStop { position: 1.0; color: root.barGradStart }
        }

        Rectangle {
            visible: !root.cornersActive
            width: 2
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: root.cornerR - root.cornerSeamOverlap
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.shellBorderWidth + root.cornerR - root.cornerSeamOverlap
            opacity: root.chromeAccentAlpha
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: root.barHueB }
                GradientStop { position: 1.0; color: root.barHueA }
            }
        }
    }

    Rectangle {
        id: bottomBorder
        visible: root.cornersActive
        x: root.railWidth
        y: root.height - root.shellBorderWidth
        width: root.width - root.railWidth - root.shellBorderWidth
        height: root.shellBorderWidth
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.barGradEnd }
            GradientStop { position: 1.0; color: root.barGradStart }
        }

        // Linkerdeel: van de hoek linksonder tot waar de launcher begint.
        Rectangle {
            visible: !root.cornersActive
            height: 2
            y: 0
            x: root.cornerR - root.cornerSeamOverlap
            width: Math.max(0, (root.launcherOpen
                    ? root.launcherX - root.railWidth - root.cornerR + root.cornerSeamOverlap
                    : parent.width - root.cornerR + root.cornerSeamOverlap) - x)
            opacity: root.chromeAccentAlpha
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.barHueB }
                GradientStop { position: 1.0; color: root.launcherOpen ? root.launcherHueLeft : root.barHueA }
            }
        }
        // Rechterdeel: pas nodig zodra de launcher de rand onderbreekt.
        Rectangle {
            visible: !root.cornersActive && root.launcherOpen
            height: 2
            y: 0
            x: root.launcherX + root.launcherWidth - root.railWidth + root.cornerR - root.cornerSeamOverlap
            width: Math.max(0, parent.width - root.cornerR + root.cornerSeamOverlap - x)
            opacity: root.chromeAccentAlpha
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.launcherHueRight }
                GradientStop { position: 1.0; color: root.barHueA }
            }
        }
    }

    // Aansluitbogen links en rechts van de launcher: de onderrand buigt hier
    // omhoog de launcher in, zodat het één doorlopende vorm lijkt.
    InnerCorner {
        mirrorH: true
        mirrorV: true
        visible: root.cornersActive && root.launcherOpen
        x: root.launcherX - root.cornerR
        y: root.height - root.shellBorderWidth - root.cornerR
        drawStroke: false
        fillColor: root.launcherFillLeft
        accentColor: root.launcherHueLeft
        horizontalFillColor: root._bottomFillAt(root.launcherX)
        verticalFillColor: root.launcherFillLeft
        horizontalAccentColor: root._bottomHueAt(root.launcherX)
        verticalAccentColor: root.launcherHueLeft
    }
    InnerCorner {
        mirrorV: true
        visible: root.cornersActive && root.launcherOpen
        x: root.launcherX + root.launcherWidth - 1
        y: root.height - root.shellBorderWidth - root.cornerR
        drawStroke: false
        fillColor: root.launcherFillRight
        accentColor: root.launcherHueRight
        horizontalFillColor: root._bottomFillAt(root.launcherX + root.launcherWidth)
        verticalFillColor: root.launcherFillRight
        horizontalAccentColor: root._bottomHueAt(root.launcherX + root.launcherWidth)
        verticalAccentColor: root.launcherHueRight
    }

    LauncherConnectorStroke {
        visible: root.cornersActive && root.launcherOpen
        x: root.launcherX - root.cornerR - root.cornerSeamOverlap
        y: root.height - root.shellBorderWidth - root.cornerR - root.cornerSeamOverlap
        horizontalAccentColor: root._bottomHueAt(root.launcherX)
        verticalAccentColor: root.launcherHueLeft
    }

    LauncherConnectorStroke {
        visible: root.cornersActive && root.launcherOpen
        mirrorH: true
        x: root.launcherX + root.launcherWidth - root.cornerSeamOverlap
        y: root.height - root.shellBorderWidth - root.cornerR - root.cornerSeamOverlap
        horizontalAccentColor: root._bottomHueAt(root.launcherX + root.launcherWidth)
        verticalAccentColor: root.launcherHueRight
    }

    component InnerCorner: Canvas {
        id: ic
        property bool mirrorH: false
        property bool mirrorV: false
        property bool drawStroke: true
        property color fillColor: root.barGradStart
        property color accentColor: root.barHueA
        property color horizontalFillColor: fillColor
        property color verticalFillColor: fillColor
        property color horizontalAccentColor: accentColor
        property color verticalAccentColor: accentColor

        width: root.cornerR
        height: root.cornerR
        antialiasing: true

        onMirrorHChanged: requestPaint()
        onMirrorVChanged: requestPaint()
        onHorizontalFillColorChanged: requestPaint()
        onVerticalFillColorChanged: requestPaint()
        onHorizontalAccentColorChanged: requestPaint()
        onVerticalAccentColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            let r = root.cornerR;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            ctx.translate(ic.mirrorH ? r : 0, ic.mirrorV ? r : 0);
            ctx.scale(ic.mirrorH ? -1 : 1, ic.mirrorV ? -1 : 1);

            let fill = ctx.createLinearGradient(r, 0, 0, r);
            fill.addColorStop(0.0, ic.horizontalFillColor);
            fill.addColorStop(1.0, ic.verticalFillColor);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.arc(r, r, r, -Math.PI / 2, Math.PI, true);
            ctx.lineTo(0, 0);
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();

            if (!ic.drawStroke) {
                ctx.restore();
                return;
            }

            let stroke = ctx.createLinearGradient(r, 0, 0, r);
            stroke.addColorStop(0.0, Qt.rgba(ic.horizontalAccentColor.r, ic.horizontalAccentColor.g, ic.horizontalAccentColor.b,
                                             root.chromeAccentAlpha));
            stroke.addColorStop(1.0, Qt.rgba(ic.verticalAccentColor.r, ic.verticalAccentColor.g, ic.verticalAccentColor.b,
                                             root.chromeAccentAlpha));
            let halfStroke = root.cornerStrokeWidth / 2;
            ctx.beginPath();
            ctx.moveTo(r, halfStroke);
            ctx.arc(r, r, Math.max(0, r - halfStroke), -Math.PI / 2, Math.PI, true);
            ctx.strokeStyle = stroke;
            ctx.lineWidth = root.cornerStrokeWidth;
            ctx.lineCap = "square";
            ctx.stroke();
            ctx.restore();
        }
    }

    component LauncherConnectorStroke: Canvas {
        id: connector
        property bool mirrorH: false
        property color horizontalAccentColor: root.barHueA
        property color verticalAccentColor: root.barHueA

        width: root.cornerR + root.cornerSeamOverlap * 2
        height: root.cornerR + root.cornerSeamOverlap * 2
        antialiasing: true
        z: 12

        onMirrorHChanged: requestPaint()
        onHorizontalAccentColorChanged: requestPaint()
        onVerticalAccentColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            let r = root.cornerR;
            let o = root.cornerSeamOverlap;
            let bottomY = r + o;
            let sideX = r + o;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            if (connector.mirrorH) {
                ctx.translate(width, 0);
                ctx.scale(-1, 1);
            }

            let stroke = ctx.createLinearGradient(0, bottomY, sideX, 0);
            stroke.addColorStop(0.0, Qt.rgba(connector.horizontalAccentColor.r,
                                             connector.horizontalAccentColor.g,
                                             connector.horizontalAccentColor.b,
                                             root.chromeAccentAlpha));
            stroke.addColorStop(1.0, Qt.rgba(connector.verticalAccentColor.r,
                                             connector.verticalAccentColor.g,
                                             connector.verticalAccentColor.b,
                                             root.chromeAccentAlpha));

            ctx.beginPath();
            ctx.moveTo(0, bottomY);
            ctx.lineTo(o, bottomY);
            ctx.arc(o, o, Math.max(0, r - root.cornerStrokeWidth / 2),
                    Math.PI / 2, 0, true);
            ctx.lineTo(sideX, 0);
            ctx.strokeStyle = stroke;
            ctx.lineWidth = root.cornerStrokeWidth;
            ctx.lineCap = "square";
            ctx.stroke();
            ctx.restore();
        }
    }

    // De vier content-hoeken. 1px naar de bar toe: de stroke ligt gecentreerd
    // op het pad terwijl de rechte lijnen tegen de rand liggen.
    InnerCorner {
        visible: root.cornersActive
        x: root.railWidth - 1
        y: root.stripHeight - 1
        drawStroke: false
        fillColor: root.barGradStart
        horizontalFillColor: root._stripFillAt(root.railWidth + root.cornerR)
        verticalFillColor: root._railFillAt(root.stripHeight + root.cornerR)
        horizontalAccentColor: root._stripHueAt(root.railWidth + root.cornerR)
        verticalAccentColor: root._railHueAt(root.stripHeight + root.cornerR)
    }
    InnerCorner {
        visible: root.cornersActive
        mirrorH: true
        x: root.width - root.shellBorderWidth - root.cornerR + 1
        y: root.stripHeight - 1
        drawStroke: false
        fillColor: root.barGradEnd
        accentColor: root.barHueB
        horizontalFillColor: root._stripFillAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalFillColor: root._rightFillAt(root.stripHeight + root.cornerR)
        horizontalAccentColor: root._stripHueAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalAccentColor: root._rightHueAt(root.stripHeight + root.cornerR)
    }
    InnerCorner {
        visible: root.cornersActive
        mirrorV: true
        x: root.railWidth - 1
        y: root.height - root.shellBorderWidth - root.cornerR + 1
        drawStroke: false
        fillColor: root.barGradEnd
        accentColor: root.barHueB
        horizontalFillColor: root._bottomFillAt(root.railWidth + root.cornerR)
        verticalFillColor: root._railFillAt(root.height - root.shellBorderWidth - root.cornerR)
        horizontalAccentColor: root._bottomHueAt(root.railWidth + root.cornerR)
        verticalAccentColor: root._railHueAt(root.height - root.shellBorderWidth - root.cornerR)
    }
    InnerCorner {
        visible: root.cornersActive
        mirrorH: true
        mirrorV: true
        x: root.width - root.shellBorderWidth - root.cornerR + 1
        y: root.height - root.shellBorderWidth - root.cornerR + 1
        drawStroke: false
        fillColor: root.barGradStart
        accentColor: root.barHueA
        horizontalFillColor: root._bottomFillAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalFillColor: root._rightFillAt(root.height - root.shellBorderWidth - root.cornerR)
        horizontalAccentColor: root._bottomHueAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalAccentColor: root._rightHueAt(root.height - root.shellBorderWidth - root.cornerR)
    }

    FrameCornerStroke {
        visible: false
        x: root.railWidth - 1 - root.cornerSeamOverlap
        y: root.stripHeight - 1 - root.cornerSeamOverlap
        horizontalAccentColor: root._stripHueAt(root.railWidth + root.cornerR)
        verticalAccentColor: root._railHueAt(root.stripHeight + root.cornerR)
    }

    FrameCornerStroke {
        visible: false
        mirrorH: true
        x: root.width - root.shellBorderWidth - root.cornerR + 1 - root.cornerSeamOverlap
        y: root.stripHeight - 1 - root.cornerSeamOverlap
        horizontalAccentColor: root._stripHueAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalAccentColor: root._rightHueAt(root.stripHeight + root.cornerR)
    }

    FrameCornerStroke {
        visible: false
        mirrorV: true
        x: root.railWidth - 1 - root.cornerSeamOverlap
        y: root.height - root.shellBorderWidth - root.cornerR + 1 - root.cornerSeamOverlap
        horizontalAccentColor: root._bottomHueAt(root.railWidth + root.cornerR)
        verticalAccentColor: root._railHueAt(root.height - root.shellBorderWidth - root.cornerR)
    }

    FrameCornerStroke {
        visible: false
        mirrorH: true
        mirrorV: true
        x: root.width - root.shellBorderWidth - root.cornerR + 1 - root.cornerSeamOverlap
        y: root.height - root.shellBorderWidth - root.cornerR + 1 - root.cornerSeamOverlap
        horizontalAccentColor: root._bottomHueAt(root.width - root.shellBorderWidth - root.cornerR)
        verticalAccentColor: root._rightHueAt(root.height - root.shellBorderWidth - root.cornerR)
    }

    component FrameCornerStroke: Canvas {
        id: frameCorner
        property bool mirrorH: false
        property bool mirrorV: false
        property color horizontalAccentColor: root.barHueA
        property color verticalAccentColor: root.barHueA

        width: root.cornerR + root.cornerSeamOverlap * 2
        height: root.cornerR + root.cornerSeamOverlap * 2
        antialiasing: true
        z: 11

        onMirrorHChanged: requestPaint()
        onMirrorVChanged: requestPaint()
        onHorizontalAccentColorChanged: requestPaint()
        onVerticalAccentColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            let r = root.cornerR;
            let o = root.cornerSeamOverlap;
            let halfStroke = root.cornerStrokeWidth / 2;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            ctx.save();
            ctx.translate(frameCorner.mirrorH ? width - o : o,
                          frameCorner.mirrorV ? height - o : o);
            ctx.scale(frameCorner.mirrorH ? -1 : 1,
                      frameCorner.mirrorV ? -1 : 1);

            let stroke = ctx.createLinearGradient(r, 0, 0, r);
            stroke.addColorStop(0.0, Qt.rgba(frameCorner.horizontalAccentColor.r,
                                             frameCorner.horizontalAccentColor.g,
                                             frameCorner.horizontalAccentColor.b,
                                             root.chromeAccentAlpha));
            stroke.addColorStop(1.0, Qt.rgba(frameCorner.verticalAccentColor.r,
                                             frameCorner.verticalAccentColor.g,
                                             frameCorner.verticalAccentColor.b,
                                             root.chromeAccentAlpha));

            ctx.beginPath();
            ctx.moveTo(r + o, halfStroke);
            ctx.lineTo(r, halfStroke);
            ctx.arc(r, r, Math.max(0, r - halfStroke), -Math.PI / 2, Math.PI, true);
            ctx.lineTo(halfStroke, r + o);
            ctx.strokeStyle = stroke;
            ctx.lineWidth = root.cornerStrokeWidth;
            ctx.lineCap = "square";
            ctx.lineJoin = "round";
            ctx.stroke();
            ctx.restore();
        }
    }

    Canvas {
        id: frameOutline
        visible: root.cornersActive
        anchors.fill: parent
        antialiasing: true
        z: 11

        onVisibleChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: root
            function onLauncherOpenChanged() { frameOutline.requestPaint(); }
            function onLauncherXChanged() { frameOutline.requestPaint(); }
            function onLauncherWidthChanged() { frameOutline.requestPaint(); }
        }

        onPaint: {
            let ctx = getContext("2d");
            let r = root.cornerR;
            let sw = root.cornerStrokeWidth;
            let half = sw / 2;
            let over = root.cornerSeamOverlap;
            let left = root.railWidth - half;
            let top = root.stripHeight - half;
            let right = root.width - root.shellBorderWidth + half;
            let bottom = root.height - root.shellBorderWidth + half;

            function rgba(c) {
                return Qt.rgba(c.r, c.g, c.b, root.chromeAccentAlpha);
            }

            function strokePath(pathFn, gradient) {
                ctx.beginPath();
                pathFn();
                ctx.strokeStyle = gradient;
                ctx.lineWidth = sw;
                ctx.lineCap = "square";
                ctx.lineJoin = "round";
                ctx.stroke();
            }

            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            let topGrad = ctx.createLinearGradient(left + r, top, right - r, top);
            topGrad.addColorStop(0.0, rgba(root._stripHueAt(left + r)));
            topGrad.addColorStop(1.0, rgba(root._stripHueAt(right - r)));

            let rightGrad = ctx.createLinearGradient(right, top + r, right, bottom - r);
            rightGrad.addColorStop(0.0, rgba(root._rightHueAt(top + r)));
            rightGrad.addColorStop(1.0, rgba(root._rightHueAt(bottom - r)));

            let bottomGrad = ctx.createLinearGradient(left + r, bottom, right - r, bottom);
            bottomGrad.addColorStop(0.0, rgba(root._bottomHueAt(left + r)));
            bottomGrad.addColorStop(1.0, rgba(root._bottomHueAt(right - r)));

            let leftGrad = ctx.createLinearGradient(left, top + r, left, bottom - r);
            leftGrad.addColorStop(0.0, rgba(root._railHueAt(top + r)));
            leftGrad.addColorStop(1.0, rgba(root._railHueAt(bottom - r)));

            let tlGrad = ctx.createLinearGradient(left + r, top, left, top + r);
            tlGrad.addColorStop(0.0, rgba(root._stripHueAt(left + r)));
            tlGrad.addColorStop(1.0, rgba(root._railHueAt(top + r)));

            let trGrad = ctx.createLinearGradient(right - r, top, right, top + r);
            trGrad.addColorStop(0.0, rgba(root._stripHueAt(right - r)));
            trGrad.addColorStop(1.0, rgba(root._rightHueAt(top + r)));

            let brGrad = ctx.createLinearGradient(right - r, bottom, right, bottom - r);
            brGrad.addColorStop(0.0, rgba(root._bottomHueAt(right - r)));
            brGrad.addColorStop(1.0, rgba(root._rightHueAt(bottom - r)));

            let blGrad = ctx.createLinearGradient(left + r, bottom, left, bottom - r);
            blGrad.addColorStop(0.0, rgba(root._bottomHueAt(left + r)));
            blGrad.addColorStop(1.0, rgba(root._railHueAt(bottom - r)));

            strokePath(function() {
                ctx.moveTo(left + r - over, top);
                ctx.arc(left + r, top + r, r, Math.PI * 1.5, Math.PI, true);
                ctx.lineTo(left, top + r + over);
            }, tlGrad);

            strokePath(function() {
                ctx.moveTo(left + r - over, top);
                ctx.lineTo(right - r + over, top);
            }, topGrad);

            strokePath(function() {
                ctx.moveTo(right - r - over, top);
                ctx.arc(right - r, top + r, r, Math.PI * 1.5, 0, false);
                ctx.lineTo(right, top + r + over);
            }, trGrad);

            strokePath(function() {
                ctx.moveTo(right, top + r - over);
                ctx.lineTo(right, bottom - r + over);
            }, rightGrad);

            strokePath(function() {
                ctx.moveTo(right, bottom - r - over);
                ctx.arc(right - r, bottom - r, r, 0, Math.PI / 2, false);
                ctx.lineTo(right - r - over, bottom);
            }, brGrad);

            strokePath(function() {
                ctx.moveTo(left + r - over, bottom);
                if (root.launcherOpen) {
                    let cutL = Math.max(left + r, root.launcherX);
                    let cutR = Math.min(right - r, root.launcherX + root.launcherWidth);
                    ctx.lineTo(cutL + over, bottom);
                    ctx.moveTo(cutR - over, bottom);
                }
                ctx.lineTo(right - r + over, bottom);
            }, bottomGrad);

            strokePath(function() {
                ctx.moveTo(left + r + over, bottom);
                ctx.arc(left + r, bottom - r, r, Math.PI / 2, Math.PI, false);
                ctx.lineTo(left, bottom - r - over);
            }, blGrad);

            strokePath(function() {
                ctx.moveTo(left, bottom - r + over);
                ctx.lineTo(left, top + r - over);
            }, leftGrad);
        }
    }

    // --- Hover-tooltip -------------------------------------------------------
    // Eén gedeelde tooltip die naar de gehoverde knop toe beweegt. Rail-knoppen
    // krijgen hem rechts ernaast, strip-knoppen eronder.
    property string tooltipText: ""
    property real tooltipAnchorX: 0
    property real tooltipAnchorY: 0
    property bool tooltipFromRail: true

    function showTooltip(item, text, fromRail) {
        if (!text) return;
        let p = item.mapToItem(root, item.width / 2, item.height / 2);
        root.tooltipAnchorX = p.x;
        root.tooltipAnchorY = p.y;
        root.tooltipFromRail = fromRail;
        root.tooltipText = text;
    }

    function hideTooltip(text) {
        if (root.tooltipText === text) root.tooltipText = "";
    }

    Rectangle {
        id: tooltip
        z: 200
        visible: opacity > 0.01
        opacity: root.tooltipText !== "" ? 1 : 0
        radius: Math.max(6, ThemeConfig.styleWidgetRadius)
        color: root.barGradStart
        border.width: 1
        border.color: Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.45)
        width: tipText.implicitWidth + 18
        height: tipText.implicitHeight + 10
        x: root.tooltipFromRail
            ? (root.railOnRight ? root.width - root.railWidth - width - 10 : root.railWidth + 10)
            : Math.max(4, Math.min(root.width - width - 4, root.tooltipAnchorX - width / 2))
        y: root.tooltipFromRail
            ? Math.max(4, Math.min(root.height - height - 4, root.tooltipAnchorY - height / 2))
            : (root.stripOnBottom ? root.height - root.stripHeight - height - 8 : root.stripHeight + 8)

        Behavior on opacity {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on x {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on y {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltipText
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: root.mocha.text
        }
    }

    // Media-pill: toont de lopende track en groeit op hover uit tot
    // transportcontrols (caelestia-patroon). Klik opent het volledige
    // muziekpaneel.
    component MediaPill: Rectangle {
        id: mp
        readonly property var player: root.activePlayer
        readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing
        readonly property string title: player ? String(player.trackTitle || "") : ""
        readonly property string artist: player ? String(player.trackArtist || "") : ""
        readonly property bool expanded: mpMouse.containsMouse

        visible: root.mediaVisible
        Layout.preferredWidth: expanded ? 300 : 168
        Layout.preferredHeight: 26
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: expanded ? root.pillHoverColor : root.pillColor
        border.width: 1
        border.color: expanded
            ? Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.40)
            : "transparent"

        Behavior on Layout.preferredWidth {
            NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 6
            spacing: 6

            Text {
                text: mp.playing ? "\udb81\udf5a" : "\udb81\udf5a"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 13
                color: root.mocha.green
            }

            Text {
                Layout.fillWidth: true
                text: mp.artist !== "" ? mp.title + "  ·  " + mp.artist : mp.title
                elide: Text.ElideRight
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: root.mocha.text
            }

            Row {
                spacing: 2
                visible: mp.expanded
                opacity: mp.expanded ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                }

                MediaCtl { icon: "\udb81\udcae"; onTriggered: if (mp.player) mp.player.previous() }
                MediaCtl { icon: mp.playing ? "\udb80\udfe4" : "\udb81\udc0a"; onTriggered: if (mp.player) mp.player.togglePlaying() }
                MediaCtl { icon: "\udb81\udcad"; onTriggered: if (mp.player) mp.player.next() }
            }
        }

        MouseArea {
            id: mpMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: {
                let p = mp.mapToItem(root, mp.width / 2, mp.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                root.togglePanel("music");
            }
        }
    }

    // Kleine transportknop binnen de media-pill.
    component MediaCtl: Rectangle {
        id: mc
        property string icon: ""
        signal triggered()
        width: 22
        height: 22
        radius: 5
        color: mcMouse.containsMouse
            ? Qt.rgba(root.barHueA.r, root.barHueA.g, root.barHueA.b, 0.28)
            : "transparent"
        Text {
            anchors.centerIn: parent
            text: mc.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: root.mocha.text
        }
        MouseArea {
            id: mcMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mc.triggered()
        }
    }

    component RailButton: Rectangle {
        id: btn
        property string icon: ""
        property string text: ""
        property color accent: root.hotColor
        property string tooltip: ""
        signal triggered()
        signal wheelDelta(int delta)

        Layout.fillWidth: true
        Layout.preferredHeight: text === "" ? 34 : 40
        radius: Math.min(7, ThemeConfig.styleWidgetRadius)
        color: mouse.containsMouse ? root.pillHoverColor : "transparent"
        border.width: 1
        border.color: mouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.36) : "transparent"
        scale: mouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Column {
            anchors.centerIn: parent
            spacing: -2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 16
                color: btn.accent
            }
            Text {
                visible: btn.text !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: btn.text
                font.family: ThemeConfig.monoFont
                font.pixelSize: 8
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.showTooltip(btn, btn.tooltip, true)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: {
                let p = btn.mapToItem(root, btn.width / 2, btn.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                btn.triggered();
            }
            onWheel: (wheel) => {
                btn.wheelDelta(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }

    component StripButton: Rectangle {
        id: btn
        property string icon: ""
        property color accent: root.hotColor
        property string tooltip: ""
        signal triggered()
        signal wheelDelta(int delta)

        Layout.preferredWidth: 30
        Layout.preferredHeight: 28
        radius: Math.min(6, ThemeConfig.styleWidgetRadius)
        color: mouse.containsMouse ? root.pillHoverColor : "transparent"
        scale: mouse.containsMouse ? 1.07 : 1.0
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 16
            color: btn.accent
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.showTooltip(btn, btn.tooltip, false)
            onExited: root.hideTooltip(btn.tooltip)
            onClicked: {
                let p = btn.mapToItem(root, btn.width / 2, btn.height / 2);
                root.lastTriggerX = p.x;
                root.lastTriggerY = p.y;
                btn.triggered();
            }
            onWheel: (wheel) => {
                btn.wheelDelta(wheel.angleDelta.y);
                wheel.accepted = true;
            }
        }
    }
}
