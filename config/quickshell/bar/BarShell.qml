import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import ".."

Variants {
    model: Quickshell.screens
    
    delegate: Component {
        PanelWindow {
        id: barWindow

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
            property bool animatedVerticalBar: isVerticalBar && activeThemeNormalized === "animated"
            property int minBarHeight: s(touchOptimized ? 44 : 40)
            property int themedBarHeight: s(ThemeConfig.barHeight > 0 ? ThemeConfig.barHeight : 48)
            property int barHeight: Math.max(minBarHeight, themedBarHeight)
            property int minBarThickness: animatedVerticalBar ? s(touchOptimized ? 66 : 52) : s(touchOptimized ? 78 : 62)
            property int verticalBarPadding: animatedVerticalBar ? s(6) : s(18)
            property int barThickness: Math.max(minBarThickness, barHeight + verticalBarPadding)
            property bool edgeAttachedBar: ThemeConfig.barAttachToScreenEdge
                                          && ThemeConfig.barWidthMode === "full"
                                          && !ThemeConfig.barFloating
            property string uiFontFamily: ThemeConfig.uiFont
            property string monoFontFamily: ThemeConfig.monoFont
            property string displayFontFamily: ThemeConfig.displayFont
            property real themeLetterSpacing: ThemeConfig.letterSpacing
            property int themeFontWeight: ThemeConfig.fontWeight
            property int cyberUnderhang: (isHorizontalBar && isTopBar && activeThemeNormalized === "cyber") ? 0 : 0
            property int topEdgeBleed: (isHorizontalBar
                                        && isTopBar
                                        && edgeAttachedBar
                                        && (activeThemeNormalized === "botanical"
                                            || activeThemeNormalized === "rocky"
                                            || activeThemeNormalized === "cyber")) ? 2 : 0
            property string particleType: ThemeConfig.particleType
            property int particleCount: ThemeConfig.particleCount
            property real particleSpeed: ThemeConfig.particleSpeed
            property string textureOverlayAsset: ThemeConfig.textureOverlayAsset

            // THICKER BAR, MINIMAL MARGINS (Scaled)
            implicitHeight: barWindow.isHorizontalBar
                            ? (barHeight + (barWindow.isTopBar ? cyberUnderhang : 0))
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
                    return barWindow.barThickness + (barWindow.isRightBar ? margins.right : margins.left);
                }
                return barWindow.barHeight
                       + (barWindow.isTopBar ? barWindow.cyberUnderhang : 0)
                       + (barWindow.isBottomBar ? margins.bottom : margins.top);
            }
            color: "transparent"

            // Dynamic Matugen Palette
            MatugenColors {
                id: mocha
            }

            // User settings (date/time format)
            property var _settingsData: ({})

            // Load settings via Process instead of FileView
            Process {
                id: loadTopBarSettingsProc
                command: ["bash", "-c", "cat ~/.config/quickshell/settings/settings.json 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try { barWindow._settingsData = JSON.parse(this.text); } catch(e) {}
                    }
                }
            }

            // Watch for changes every 2 seconds
            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: {
                    if (!loadTopBarSettingsProc.running) loadTopBarSettingsProc.running = true;
                }
            }

            // --- Mode State ---
            property string activeMode: "office"
            property var moduleList: ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications"]
            property bool barAutoHide: false
            property bool barVisible: true
            property int updateCount: 0
            property int volumeWheelAccumulator: 0

            function _defaultModules(mode) {
                if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "battery", "volume", "game_launcher", "clock"];
                if (mode === "media")  return ["volume", "brightness", "media_controls", "battery", "clock"];
                return ["workspaces", "clock", "updates", "cpu_temp", "network", "battery", "volume", "bluetooth", "notifications"];
            }

            function _normalizeModules(mode, modules) {
                let normalized = Array.isArray(modules) ? modules.slice() : [];
                if (mode === "office" && normalized.indexOf("updates") === -1) {
                    normalized.push("updates");
                }
                if (mode === "office" && normalized.indexOf("cpu_temp") === -1) {
                    normalized.push("cpu_temp");
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
                Quickshell.execDetached(["kitty", "--hold", "bash", "-lc", cmd]);
                Quickshell.execDetached(["bash", "-c", "rm -f ~/.cache/quickshell/package_updates_count"]);
                updatesPoller.running = true;
                Quickshell.execDetached(["notify-send", "Updates", "Update gestart in terminal"]);
            }

            function switchKeyboardLayout() {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"]);
                keyboardRefreshTimer.restart();
            }

            function handleVolumeWheel(deltaY) {
                if (!deltaY || deltaY === 0) return;
                barWindow.volumeWheelAccumulator += deltaY;
                let steps = 0;
                while (barWindow.volumeWheelAccumulator >= 120) { steps += 1; barWindow.volumeWheelAccumulator -= 120; }
                while (barWindow.volumeWheelAccumulator <= -120) { steps -= 1; barWindow.volumeWheelAccumulator += 120; }
                if (steps === 0) return;
                if (steps > 0) {
                    Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ +" + steps + "%"]);
                } else {
                    Quickshell.execDetached(["bash", "-c", "pactl set-sink-volume @DEFAULT_SINK@ " + steps + "%"]);
                }
                if (!volPoller.running) volPoller.running = true;
            }

            Process {
                id: loadModeProc
                command: ["bash", "-c", "cat ~/.config/kingstra/state/mode.json 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let m = JSON.parse(this.text);
                            if (m.name) barWindow.activeMode = m.name;
                            let resolvedModules = (m.modules && m.modules.length > 0)
                                ? m.modules
                                : barWindow._defaultModules(m.name || "office");
                            barWindow.moduleList = barWindow._normalizeModules(m.name || "office", resolvedModules);
                            barWindow.barAutoHide = m.bar_autohide === true;
                        } catch(e) {}
                    }
                }
            }
            Timer {
                interval: 2000; running: true; repeat: true
                onTriggered: {
                    if (!loadModeProc.running) loadModeProc.running = true;
                }
            }

            // --- State Variables ---

            // Triggers layout animations immediately to feel fast
            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            // Prevents repeaters (Workspaces/Tray) from flickering on data updates
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            // Data gating to prevent startup layout jumping
            property bool sysPollerLoaded: false
            property bool fastPollerLoaded: false
            
            // FIXED: Only wait for the instant data to load the UI. 
            // The slow network scripts will populate smoothly when they finish.
            property bool isDataReady: fastPollerLoaded
            // Failsafe: Force the layout to show after 600ms even if fast poller hangs
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            property string kbLayout: "US"
            property int kbLayoutCount: 1
            
            // WiFi — Quickshell.Networking (event-driven)
            readonly property var _wifiDevice: {
                var devs = Networking.devices.values;
                for (var i = 0; i < devs.length; i++) {
                    if (devs[i].type === DeviceType.Wifi) return devs[i];
                }
                return null;
            }
            readonly property var _wifiNetwork: {
                if (!_wifiDevice) return null;
                var nets = _wifiDevice.networks.values;
                for (var i = 0; i < nets.length; i++) {
                    if (nets[i].connected) return nets[i];
                }
                return null;
            }
            readonly property bool isWifiOn: _wifiDevice ? _wifiDevice.connected : false
            readonly property string wifiSsid: _wifiNetwork ? _wifiNetwork.name : ""
            readonly property string wifiIcon: {
                if (!_wifiDevice || !isWifiOn) return "󰤮";
                var sig = _wifiNetwork ? _wifiNetwork.signalStrength : 0;
                if (sig >= 0.80) return "󰤨";
                if (sig >= 0.60) return "󰤥";
                if (sig >= 0.40) return "󰤢";
                if (sig >= 0.20) return "󰤟";
                return "󰤯";
            }

            // Bluetooth — Quickshell.Bluetooth (event-driven)
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

            // Volume — pactl (meest betrouwbaar, zelfde waarde als VolumePopup)
            property int _volRaw: 0
            property bool isMuted: false

            Process {
                id: volPoller
                command: ["bash", "-c", "pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\\d+(?=%)' | head -1; pactl get-sink-mute @DEFAULT_SINK@ | grep -oP '(?<=Mute: )\\S+'"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        let lines = this.text.trim().split("\n");
                        if (lines.length >= 1) barWindow._volRaw = parseInt(lines[0]) || 0;
                        if (lines.length >= 2) barWindow.isMuted = lines[1].trim() === "yes";
                    }
                }
            }
            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: if (!volPoller.running) volPoller.running = true
            }

            readonly property string volPercent: _volRaw + "%"
            readonly property string volIcon: {
                if (isMuted || _volRaw === 0) return "󰝟";
                if (_volRaw >= 70) return "󰕾";
                if (_volRaw >= 30) return "󰖀";
                return "󰕿";
            }

            // Battery — Quickshell.Services.UPower (event-driven)
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

            // Media — Quickshell.Services.Mpris (event-driven)
            readonly property var _activePlayer: {
                var players = Mpris.players;
                for (var i = 0; i < players.length; i++) {
                    if (players[i].playbackState !== MprisPlaybackState.Stopped) return players[i];
                }
                return players.length > 0 ? players[0] : null;
            }
            readonly property bool isMediaActive: _activePlayer !== null
                && _activePlayer.playbackState !== MprisPlaybackState.Stopped
                && _activePlayer.trackTitle !== ""
            readonly property var musicData: {
                if (!_activePlayer || !isMediaActive)
                    return { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" };
                var state = _activePlayer.playbackState;
                var status = state === MprisPlaybackState.Playing ? "Playing"
                           : state === MprisPlaybackState.Paused  ? "Paused" : "Stopped";
                var timeStr = "";
                if (_activePlayer.positionSupported && _activePlayer.lengthSupported && _activePlayer.length > 0) {
                    var pos = Math.floor(_activePlayer.position / 1000000);
                    var len = Math.floor(_activePlayer.length / 1000000);
                    timeStr = Math.floor(pos/60) + ":" + String(pos%60).padStart(2,'0')
                            + " / " + Math.floor(len/60) + ":" + String(len%60).padStart(2,'0');
                }
                return { "status": status, "title": _activePlayer.trackTitle || "",
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
                running: true
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

            // Unified System Info ------------------------
            Process {
                id: sysPoller
                running: true
                command: ["bash", "-c", "~/.config/quickshell/sys_info.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (data.keyboard) {
                                    let nextLayout = data.keyboard.layout || "US";
                                    let nextCount = parseInt(data.keyboard.count || 1);
                                    barWindow.kbLayout = nextLayout;
                                    barWindow.kbLayoutCount = isNaN(nextCount) ? 1 : nextCount;
                                }
                                barWindow.sysPollerLoaded = true;
                                barWindow.fastPollerLoaded = true;
                            } catch(e) {}
                        }
                        if (!sysWaiter.running) sysWaiter.running = true;
                    }
                }
            }
            
            Process {
                id: sysWaiter
                command: ["bash", "-c", "~/.config/quickshell/sys_waiter.sh"]
                // Strictly use onExited. Quickshell will no longer hook into stdout, preventing pipe deadlocks.
                onExited: sysPoller.running = true 
            }

            Timer {
                id: keyboardRefreshTimer
                interval: 180
                repeat: false
                onTriggered: {
                    if (!sysPoller.running) sysPoller.running = true;
                }
            }

            // Weather remains a slow poll since it fetches from web
            Process {
                id: weatherPoller
                command: ["bash", "-c", `
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-icon)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-temp)"
                    echo "$(~/.config/quickshell/calendar/weather.sh --current-hex)"
                `]
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
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!weatherPoller.running) weatherPoller.running = true;
                }
            }

            // Native Qt Time Formatting
            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    let tf = barWindow._settingsData.timeFormat || "hh:mm:ss AP";
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


            BarSurface {
                id: barSurface
                anchors.fill: parent
                shell: barWindow
                mocha: mocha
            }
        }
    }
}
