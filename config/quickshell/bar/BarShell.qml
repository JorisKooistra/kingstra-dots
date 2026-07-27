import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Hyprland
import Quickshell.Networking
import ".."

Variants {
    model: Quickshell.screens
    
    delegate: Component {
        PanelWindow {
        id: barWindow

        // New theme state is rendered by ShellSurface. Legacy state keeps this
        // window until it is migrated by kingstra-theme-switch.
        visible: !ThemeConfig.barZoneSchemaLoaded
        readonly property bool runtimeActive: visible

        required property var modelData
            
            // Bind this specific bar instance to the dynamically assigned screen
            screen: modelData
            
            anchors {
                top: barWindow.isTopBar || barWindow.isVerticalBar
                bottom: barWindow.isBottomBar || barWindow.isVerticalBar
                left: barWindow.isHorizontalBar || barWindow.isLeftBar
                right: barWindow.isHorizontalBar || barWindow.isRightBar
            }
            
            // --- Responsive Scaling Logic ---
            property real scaleReferenceWidth: barWindow.isVerticalBar
                                               ? (barWindow.screen ? barWindow.screen.width : 1920)
                                               : Math.max(800, barWindow.width)
            Scaler {
                id: scaler
                currentWidth: barWindow.scaleReferenceWidth
            }

            property real baseScale: scaler.baseScale
            
            // Helper function mapped to the external scaler
            function s(val) { 
                return scaler.s(val); 
            }

            property string barPositionNormalized: {
                let pos = String(ThemeConfig.barPosition || "top").toLowerCase();
                if (pos === "bottom" || pos === "left" || pos === "right") return pos;
                return "top";
            }
            property bool isTopBar: barPositionNormalized === "top"
            property bool isBottomBar: barPositionNormalized === "bottom"
            property bool isLeftBar: barPositionNormalized === "left"
            property bool isRightBar: barPositionNormalized === "right"
            property bool isVerticalBar: isLeftBar || isRightBar
            property bool isHorizontalBar: !isVerticalBar
            property bool touchOptimized: TouchProfile.isTouchscreen
            property string activeThemeName: ThemeConfig.theme
            property string activeThemeNormalized: String(activeThemeName || "").toLowerCase()
            property string activeBarTemplate: ThemeConfig.effectiveBarTemplate
            property bool compactSidebarTemplate: activeBarTemplate === "compact-sidebar"
            property bool animatedVerticalBar: isVerticalBar && compactSidebarTemplate
            property bool sidebarDrawerOpen: false
            property int sidebarDrawerWidth: animatedVerticalBar ? s(touchOptimized ? 178 : 160) : 0
            property int minBarHeight: s(touchOptimized ? 44 : 36)
            property int themedBarHeight: s(ThemeConfig.barHeight > 0 ? ThemeConfig.barHeight : 48)
            property int barHeight: Math.max(minBarHeight, themedBarHeight)
            property int baseBarThickness: Math.max(
                animatedVerticalBar ? s(touchOptimized ? 66 : 52) : s(touchOptimized ? 78 : 62),
                barHeight + (animatedVerticalBar ? s(6) : s(18))
            )
            property int barThickness: baseBarThickness + (animatedVerticalBar && sidebarDrawerOpen ? sidebarDrawerWidth + s(8) : 0)
            property int verticalBarPadding: animatedVerticalBar ? s(6) : s(18)
            property bool edgeAttachedBar: ThemeConfig.barAttachToScreenEdge
                                          && ThemeConfig.barWidthMode === "full"
                                          && !ThemeConfig.barFloating
            property string uiFontFamily: ThemeConfig.uiFont
            property string monoFontFamily: ThemeConfig.monoFont
            property string displayFontFamily: ThemeConfig.displayFont
            property string clockStyle: ThemeConfig.clockStyle
            property real themeLetterSpacing: ThemeConfig.letterSpacing
            property int themeFontWeight: ThemeConfig.fontWeight
            property int neonUnderhang: 0
            property int topEdgeBleed: (isHorizontalBar
                                        && isTopBar
                                        && edgeAttachedBar
                                        && (ThemeConfig.barShape === "organic-grown"
                                            || ThemeConfig.barShape === "block"
                                            || ThemeConfig.barShape === "beveled")) ? 2 : 0
            property string particleType: ThemeConfig.particleType
            property int particleCount: ThemeConfig.particleCount
            property real particleSpeed: ThemeConfig.particleSpeed
            property int particleVisualOverflow: particleType === "fireflies" ? s(42) : 0
            property string textureOverlayAsset: ThemeConfig.textureOverlayAsset

            // THICKER BAR, MINIMAL MARGINS (Scaled)
            implicitHeight: barWindow.isHorizontalBar
                            ? (barHeight + (barWindow.isTopBar ? neonUnderhang : 0) + particleVisualOverflow)
                            : 0
            implicitWidth: barWindow.isVerticalBar ? barThickness : 0
            margins {
                top: barWindow.isHorizontalBar
                     ? (barWindow.isBottomBar ? 0 : (barWindow.edgeAttachedBar ? -barWindow.topEdgeBleed : s(8)))
                     : (barWindow.animatedVerticalBar || barWindow.edgeAttachedBar ? 0 : s(8))
                bottom: barWindow.isHorizontalBar
                        ? (barWindow.isBottomBar ? (barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
                        : (barWindow.animatedVerticalBar || barWindow.edgeAttachedBar ? 0 : s(8))
                left: barWindow.isHorizontalBar
                      ? (barWindow.edgeAttachedBar ? 0 : s(8))
                      : (barWindow.isLeftBar ? (barWindow.animatedVerticalBar || barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
                right: barWindow.isHorizontalBar
                       ? (barWindow.edgeAttachedBar ? 0 : s(8))
                       : (barWindow.isRightBar ? (barWindow.animatedVerticalBar || barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
            }
            
            // exclusiveZone = 0 bij auto-hide (media mode), anders bar-dikte + randmarge
            exclusiveZone: {
                if (barWindow.barAutoHide) return 0;
                if (barWindow.isVerticalBar) {
                    return barWindow.baseBarThickness + (barWindow.isRightBar ? margins.right : margins.left);
                }
                return barWindow.barHeight
                       + (barWindow.isTopBar ? barWindow.neonUnderhang : 0)
                       + (barWindow.isBottomBar ? margins.bottom : margins.top);
            }
            color: "transparent"
            mask: Region {
                x: 0
                y: barWindow.isHorizontalBar && barWindow.isBottomBar ? barWindow.particleVisualOverflow : 0
                width: barWindow.width
                height: barWindow.isHorizontalBar
                        ? Math.max(1, barWindow.height - barWindow.particleVisualOverflow)
                        : barWindow.height
            }

            // Dynamic Matugen Palette
            MatugenColors {
                id: mocha
            }

            // User settings (date/time format)
            property var _settingsData: ({})
            property bool _settingsReady: false

            FileView {
                id: settingsFileView
                path: Quickshell.env("HOME") + "/.config/quickshell/settings/settings.json"
                watchChanges: true
                preload: true
                onInternalTextChanged: {
                    if (!__text) return;
                    try {
                        barWindow._settingsData = JSON.parse(__text);
                    } catch(e) {
                        barWindow._settingsData = { timeFormat: "HH:mm:ss", dateFormat: "dddd, MMMM dd" };
                    }
                    barWindow._settingsReady = true;
                }
            }
            // Failsafe: zet _settingsReady na 1s als het bestand niet bestaat
            Timer { interval: 1000; running: !barWindow._settingsReady; onTriggered: barWindow._settingsReady = true }

            // QS 0.3.0: watchChanges mist updates zodra het bestand via mv/rename
            // wordt vervangen (inode-wissel). Poll als vangnet; onInternalTextChanged
            // vuurt alleen bij daadwerkelijk gewijzigde inhoud.
            Timer { interval: 5000; running: barWindow.runtimeActive; repeat: true; onTriggered: settingsFileView.reload() }

            // --- Mode State ---
            property string activeMode: "office"
            property var moduleList: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications", "mail"]
            property bool barAutoHide: false
            property bool barVisible: true
            property int updateCount: 0
            property int volumeWheelAccumulator: 0
            property int workspaceWheelAccumulator: 0

            function _defaultModules(mode) {
                if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "fps", "battery", "volume", "game_launcher", "clock"];
                if (mode === "media")  return ["volume", "brightness", "media_controls", "battery", "clock"];
                return ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications", "mail"];
            }

            function _normalizeModules(mode, modules) {
                let normalized = Array.isArray(modules) ? modules.slice() : [];
                if (mode === "office" && normalized.indexOf("updates") === -1) {
                    normalized.push("updates");
                }
                if (mode === "office" && normalized.indexOf("cpu_temp") === -1) {
                    normalized.push("cpu_temp");
                }
                if (mode === "office" && normalized.indexOf("mail") === -1) {
                    normalized.push("mail");
                }
                if ((mode === "office" || mode === "gaming" || mode === "media")
                        && normalized.indexOf("battery") === -1) {
                    normalized.push("battery");
                }

                return normalized;
            }

            function refreshUpdates() {
                updatesPoller.running = true;
            }

            function openUpdatesTerminal() {
                let cmd = "~/.config/quickshell/package_upgrade.sh";
                Quickshell.execDetached(["kitty", "--hold", "bash", "-c", cmd]);
                Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/quickshell/package_updates_count"]);
                updatesPoller.running = true;
                Quickshell.execDetached(["notify-send", "Updates", "Update gestart in terminal"]);
            }

            function switchKeyboardLayout() {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                // Geen timer nodig — update komt via Hyprland rawEvent
            }

            function mediaPrevious()  { if (_activePlayer && _activePlayer.canGoPrevious)    _activePlayer.previous(); }
            function mediaPlayPause() {
                if (_activePlayer && _activePlayer.canTogglePlaying) {
                    _activePlayer.togglePlaying();
                    return;
                }
                if (_activePlayer && _activePlayer.canPlay) {
                    _activePlayer.play();
                    return;
                }

                // Fallback: some players expose metadata/state differently.
                var players = Mpris.players.values;
                for (var i = 0; i < players.length; i++) {
                    var p = players[i];
                    if (p.canTogglePlaying
                            && (p.playbackState === MprisPlaybackState.Playing
                                || p.playbackState === MprisPlaybackState.Paused)) {
                        p.togglePlaying();
                        return;
                    }
                }
                for (var j = 0; j < players.length; j++) {
                    if (players[j].canTogglePlaying) {
                        players[j].togglePlaying();
                        return;
                    }
                }
                for (var k = 0; k < players.length; k++) {
                    if (players[k].canPlay) {
                        players[k].play();
                        return;
                    }
                }
            }
            function mediaNext()      { if (_activePlayer && _activePlayer.canGoNext)        _activePlayer.next(); }

            function togglePopup(target) {
                Quickshell.execDetached([
                    "bash",
                    "-lc",
                    "~/.config/hypr/scripts/qs_manager.sh toggle " + target
                ]);
            }

            function toggleWeatherPopup() { togglePopup("calendar"); }
            function toggleMusicPopup() { togglePopup("music"); }
            function toggleAudioControlsPopup() { togglePopup("volume"); }

            function handleVolumeWheel(deltaY) {
                if (!deltaY || deltaY === 0) return;
                barWindow.volumeWheelAccumulator += deltaY;
                let steps = 0;
                while (barWindow.volumeWheelAccumulator >= 120) { steps += 1; barWindow.volumeWheelAccumulator -= 120; }
                while (barWindow.volumeWheelAccumulator <= -120) { steps -= 1; barWindow.volumeWheelAccumulator += 120; }
                if (steps === 0) return;
                if (steps > 0) {
                    Quickshell.execDetached(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + steps + "%+"]);
                } else {
                    Quickshell.execDetached(["bash", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + Math.abs(steps) + "%-"]);
                }
                if (!volPoller.running) volPoller.running = true;
            }

            function handleWorkspaceWheel(deltaY, workspaceCount, monitorName) {
                if (!deltaY || deltaY === 0) return;
                barWindow.workspaceWheelAccumulator += deltaY;
                let steps = 0;
                while (barWindow.workspaceWheelAccumulator >= 120) { steps -= 1; barWindow.workspaceWheelAccumulator -= 120; }
                while (barWindow.workspaceWheelAccumulator <= -120) { steps += 1; barWindow.workspaceWheelAccumulator += 120; }
                if (steps === 0) return;

                let count = Math.max(1, workspaceCount || 8);
                let monitor = monitorName || (barWindow.screen ? barWindow.screen.name : "");
                let direction = steps > 0 ? "next" : "prev";
                let repeats = Math.abs(steps);
                Quickshell.execDetached([
                    "bash",
                    Quickshell.env("HOME") + "/.config/hypr/scripts/workspace-scroll-monitor.sh",
                    monitor,
                    direction,
                    String(count),
                    String(repeats)
                ]);
            }

            FileView {
                id: modeFileView
                path: Quickshell.env("HOME") + "/.config/kingstra/state/mode.json"
                watchChanges: true
                preload: true
                onInternalTextChanged: {
                    if (!__text) return;
                    try {
                        let m = JSON.parse(__text);
                        if (m.name) barWindow.activeMode = m.name;
                        let resolvedModules = (m.modules && m.modules.length > 0)
                            ? m.modules
                            : barWindow._defaultModules(m.name || "office");
                        barWindow.moduleList = barWindow._normalizeModules(m.name || "office", resolvedModules);
                        barWindow.barAutoHide = m.bar_autohide === true;
                    } catch(e) {}
                }
            }

            // QS 0.3.0: watchChanges mist inode-vervanging (mode-switch schrijft via mv)
            Timer { interval: 2000; running: barWindow.runtimeActive; repeat: true; onTriggered: modeFileView.reload() }

            // --- State Variables ---

            // Triggers layout animations immediately to feel fast
            property bool isStartupReady: false
            Timer { interval: 10; running: barWindow.runtimeActive; onTriggered: barWindow.isStartupReady = true }
            
            // Prevents repeaters (Workspaces/Tray) from flickering on data updates
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: barWindow.runtimeActive; onTriggered: barWindow.startupCascadeFinished = true }
            
            // Data is direct beschikbaar via event-driven bronnen (Networking, Hyprland)
            property bool isDataReady: true
            Timer { interval: 600; running: barWindow.runtimeActive; onTriggered: barWindow.isDataReady = true }
            readonly property bool sysPollerLoaded: true
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            property string kbLayout: "US"
            property int kbLayoutCount: 1
            
            // WiFi + Ethernet — Quickshell.Networking (event-driven)
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
            readonly property string wifiSsid: {
                var devs = Networking.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    var dev = devs[i];
                    if (dev.type !== DeviceType.Wifi || !dev.connected) continue;
                    var nets = dev.networks.values;
                    for (var j = 0; j < nets.length; j++) {
                        if (nets[j].connected) return nets[j].name;
                    }
                }
                return "";
            }
            readonly property string wifiIcon: {
                if (!isWifiOn || !wifiSsid) return isWifiOn ? "󰤯" : "󰤮";
                var devs = Networking.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    var dev = devs[i];
                    if (dev.type !== DeviceType.Wifi || !dev.connected) continue;
                    var nets = dev.networks.values;
                    for (var j = 0; j < nets.length; j++) {
                        if (!nets[j].connected) continue;
                        var sig = nets[j].signalStrength;
                        if (sig >= 75) return "󰤨";
                        if (sig >= 50) return "󰤥";
                        if (sig >= 25) return "󰤢";
                        return "󰤟";
                    }
                }
                return "󰤮";
            }
            readonly property bool isEthConnected: {
                var devs = Networking.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    if (devs[i].type === DeviceType.Wired && devs[i].connected) return true;
                }
                return false;
            }
            readonly property string ethSpeed: {
                var devs = Networking.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    var dev = devs[i];
                    if (dev.type !== DeviceType.Wired || !dev.connected) continue;
                    var spd = dev.linkSpeed;
                    if (!spd || spd <= 0 || spd >= 65535) return "";
                    return spd >= 1000 ? (Math.floor(spd / 1000) + "G") : (spd + "M");
                }
                return "";
            }
            readonly property string ethIcon: isEthConnected ? "󰈀" : "󰈂"

            // Bluetooth — Quickshell.Bluetooth (event-driven)
            readonly property bool hasBluetooth: Bluetooth.defaultAdapter !== null
            readonly property bool isBtOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
            readonly property string btIcon: isBtOn ? "󰂱" : "󰂲"
            readonly property string btDevice: {
                if (!Bluetooth.defaultAdapter || !isBtOn) return "";
                var devs = Bluetooth.defaultAdapter.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    if (devs[i].connected) return devs[i].name || "";
                }
                return "";
            }
            readonly property string btStatus: isBtOn ? "On" : "Off"

            // Volume — wpctl (Pipewire QML werkt niet op dit systeem)
            property int _volRaw: 0
            property bool isMuted: false

            Process {
                id: volPoller
                command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@"]
                running: barWindow.runtimeActive
                stdout: StdioCollector {
                    onStreamFinished: {
                        let line = this.text.trim();
                        let match = line.match(/Volume:\s+([\d.]+)/);
                        if (match) barWindow._volRaw = Math.round(parseFloat(match[1]) * 100);
                        barWindow.isMuted = line.includes("[MUTED]");
                    }
                }
            }
            Timer {
                interval: 5000; running: barWindow.runtimeActive; repeat: true
                onTriggered: if (!volPoller.running) volPoller.running = true
            }

            readonly property string volPercent: _volRaw + "%"
            readonly property string volIcon: {
                if (isMuted || _volRaw === 0) return "󰝟";
                if (_volRaw >= 70) return "󰕾";
                if (_volRaw >= 30) return "󰖀";
                return "󰕿";
            }

            // Battery — UPower event-driven (vervangt bash compgen check)
            readonly property bool hasBattery: UPower.displayDevice !== null
                && UPower.displayDevice.isLaptopBattery

            readonly property int batCap: UPower.displayDevice ? Math.round(UPower.displayDevice.percentage * 100) : 0
            readonly property bool isCharging: UPower.displayDevice
                ? (UPower.displayDevice.state === UPowerDeviceState.Charging
                   || UPower.displayDevice.state === UPowerDeviceState.FullyCharged
                   || UPower.displayDevice.state === UPowerDeviceState.PendingCharge)
                : false
            readonly property string batPercent: batCap + "%"
            readonly property string batStatus: isCharging ? "Charging"
                : (UPower.displayDevice ? UPowerDeviceState.toString(UPower.displayDevice.state) : "Unknown")
            readonly property string batIcon: {
                if (batCap >= 75) return "\uf240";
                if (batCap >= 30) return "\uf242";
                return "\uf244";
            }
            readonly property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap >= 70) return mocha.blue;
                if (batCap >= 30) return mocha.yellow;
                return mocha.red;
            }

            // Media — MPRIS event-driven (vervangt playerctl polling)
            readonly property string mediaTitle: _activePlayer
                ? (String(_activePlayer.trackTitle || "").trim() !== ""
                    ? _activePlayer.trackTitle
                    : (String(_activePlayer.identity || "").trim() !== "" ? _activePlayer.identity : "Media"))
                : ""
            readonly property string mediaStatus: {
                if (!_activePlayer) return "Stopped";
                var state = _activePlayer.playbackState;
                if (state === MprisPlaybackState.Playing) return "Playing";
                if (state === MprisPlaybackState.Paused)  return "Paused";
                if ((_activePlayer.canTogglePlaying || _activePlayer.canPlay)
                        && (String(_activePlayer.trackTitle || "").trim() !== ""
                            || String(_activePlayer.identity || "").trim() !== "")) {
                    return "Paused";
                }
                return "Stopped";
            }

            // Media — Quickshell.Services.Mpris (event-driven)
            readonly property var _activePlayer: {
                var players = Mpris.players.values;
                var playingWithTitle = null;
                var playingAny = null;
                var pausedWithTitle = null;
                var pausedAny = null;

                for (var i = 0; i < players.length; i++) {
                    var player = players[i];
                    var title = String(player.trackTitle || "").trim();
                    var hasTitle = title !== "";

                    if (player.playbackState === MprisPlaybackState.Playing) {
                        if (playingAny === null) playingAny = player;
                        if (hasTitle && playingWithTitle === null) playingWithTitle = player;
                        continue;
                    }

                    if (player.playbackState === MprisPlaybackState.Paused) {
                        if (pausedAny === null) pausedAny = player;
                        if (hasTitle && pausedWithTitle === null) pausedWithTitle = player;
                    }
                }

                if (playingWithTitle !== null) return playingWithTitle;
                if (playingAny !== null) return playingAny;
                if (pausedWithTitle !== null) return pausedWithTitle;
                if (pausedAny !== null) return pausedAny;

                for (var j = 0; j < players.length; j++) {
                    if (String(players[j].trackTitle || "").trim() !== "") return players[j];
                }

                return players.length > 0 ? players[0] : null;
            }
            readonly property bool isMediaPlaying: _activePlayer !== null
                && _activePlayer.playbackState === MprisPlaybackState.Playing
            readonly property bool isMediaActive: mediaStatus === "Playing" || mediaStatus === "Paused"
            readonly property var musicData: {
                if (!_activePlayer || !isMediaActive)
                    return { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" };
                var state = _activePlayer.playbackState;
                var status = state === MprisPlaybackState.Playing ? "Playing"
                           : "Paused";
                var timeStr = "";
                if (_activePlayer.positionSupported && _activePlayer.lengthSupported && _activePlayer.length > 0) {
                    var pos = Math.floor(_activePlayer.position / 1000000);
                    var len = Math.floor(_activePlayer.length / 1000000);
                    timeStr = Math.floor(pos/60) + ":" + String(pos%60).padStart(2,'0')
                            + " / " + Math.floor(len/60) + ":" + String(len%60).padStart(2,'0');
                }
                var title = String(_activePlayer.trackTitle || "").trim() !== ""
                    ? _activePlayer.trackTitle
                    : (String(_activePlayer.identity || "").trim() !== "" ? _activePlayer.identity : "Media");
                return { "status": status, "title": title,
                         "artUrl": _activePlayer.trackArtUrl || "", "timeStr": timeStr };
            }

            Process {
                id: updatesPoller
                command: ["bash", "-c", "~/.config/quickshell/package_updates.sh 2>/dev/null || echo 0"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let n = parseInt(this.text.trim());
                        if (!isNaN(n) && n >= 0) barWindow.updateCount = n;
                    }
                }
            }

            Timer {
                id: updatesTimer
                interval: 900000
                running: barWindow.runtimeActive
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (barWindow.moduleList.includes("updates") && !updatesPoller.running) {
                        updatesPoller.running = true;
                    }
                }
            }

            onActiveModeChanged: {
                if (barWindow.activeMode === "office" && !updatesPoller.running) {
                    updatesPoller.running = true;
                }
            }

            // Derived properties for UI logic
            property bool isSoundActive: !barWindow.isMuted && barWindow._volRaw > 0

            // ==========================================
            // DATA FETCHING
            // ==========================================

            // Toetsenbordindeling — eenmalig via hyprctl, updates via Hyprland rawEvent
            // kbLayoutCount = aantal geconfigureerde layouts in input:kb_layout (niet apparaten)
            Process {
                id: kbInitPoller
                running: barWindow.runtimeActive
                command: ["bash", "-c",
                    "count=$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // \"us\"' | awk -F, '{n=0; for(i=1;i<=NF;i++) if($i!=\"\") n++; print n}'); " +
                    "active=$(hyprctl devices -j 2>/dev/null | jq -r '.keyboards[] | select(.main==true) | .active_keymap // \"US\"' | head -n1); " +
                    "echo \"$count $active\""
                ]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let parts = this.text.trim().split(" ");
                        barWindow.kbLayoutCount = parseInt(parts[0]) || 1;
                        barWindow.kbLayout = (parts.slice(1).join(" ") || "US").substring(0, 2).toUpperCase();
                    }
                }
            }

            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    if (event.name !== "activelayout") return;
                    let comma = event.data.indexOf(",");
                    if (comma >= 0)
                        barWindow.kbLayout = event.data.substring(comma + 1).trim().substring(0, 2).toUpperCase();
                }
            }

            // Weather remains a slow poll since it fetches from web
            Process {
                id: weatherPoller
                command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/calendar/weather.sh", "--current-summary"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 3) {
                            barWindow.weatherIcon = lines[0];
                            barWindow.weatherTemp = lines[1];
                            barWindow.weatherHex = lines[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer {
                interval: 150000
                running: barWindow.runtimeActive
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!weatherPoller.running) weatherPoller.running = true;
                }
            }

            // Native Qt Time Formatting — only starts after settings are loaded
            Timer {
                interval: 1000; running: barWindow.runtimeActive && barWindow._settingsReady; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    let tf = barWindow._settingsData.timeFormat || "HH:mm:ss";
                    let df = barWindow._settingsData.dateFormat || "dddd, MMMM dd";
                    barWindow.timeStr = Qt.formatDateTime(d, tf);
                    barWindow.fullDateStr = Qt.formatDateTime(d, df);
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            // Typewriter effect timer for the date
            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            // ==========================================
            // AUTO-HIDE (media mode)
            // ==========================================
            property bool autoHideVisible: !barWindow.barAutoHide
            property int autoHideOffsetDistance: barWindow.s(72)
            property int autoHideOffsetX: (!barWindow.barAutoHide || barWindow.autoHideVisible)
                                          ? 0
                                          : (barWindow.isLeftBar ? -barWindow.autoHideOffsetDistance
                                                                 : (barWindow.isRightBar ? barWindow.autoHideOffsetDistance : 0))
            property int autoHideOffsetY: (!barWindow.barAutoHide || barWindow.autoHideVisible)
                                          ? 0
                                          : (barWindow.isBottomBar ? barWindow.autoHideOffsetDistance
                                                                   : (barWindow.isTopBar ? -barWindow.autoHideOffsetDistance : 0))

            MouseArea {
                id: autoHideTriggerHorizontal
                visible: barWindow.barAutoHide && barWindow.isHorizontalBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: barWindow.isTopBar ? parent.top : undefined
                anchors.bottom: barWindow.isBottomBar ? parent.bottom : undefined
                height: barWindow.s(4)
                hoverEnabled: true
                z: 100
                onEntered: {
                    barWindow.autoHideVisible = true;
                    autoHideTimer.restart();
                }
            }

            MouseArea {
                id: autoHideTriggerVertical
                visible: barWindow.barAutoHide && barWindow.isVerticalBar
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: barWindow.isLeftBar ? parent.left : undefined
                anchors.right: barWindow.isRightBar ? parent.right : undefined
                width: barWindow.s(4)
                hoverEnabled: true
                z: 100
                onEntered: {
                    barWindow.autoHideVisible = true;
                    autoHideTimer.restart();
                }
            }

            Timer {
                id: autoHideTimer
                interval: 3000
                onTriggered: {
                    if (barWindow.barAutoHide
                            && !autoHideTriggerHorizontal.containsMouse
                            && !autoHideTriggerVertical.containsMouse)
                        barWindow.autoHideVisible = false;
                }
            }


            Loader {
                anchors.fill: parent
                active: barWindow.runtimeActive
                sourceComponent: barSurfaceComponent
            }

            Component {
                id: barSurfaceComponent
                BarSurface {
                    shell: barWindow
                    mocha: mocha
                }
            }
        }
    }
}
