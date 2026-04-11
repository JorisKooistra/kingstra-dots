import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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
            property int minBarHeight: s(touchOptimized ? 44 : 40)
            property int themedBarHeight: s(ThemeConfig.barHeight > 0 ? ThemeConfig.barHeight : 48)
            property int barHeight: Math.max(minBarHeight, themedBarHeight)
            property int minBarThickness: s(touchOptimized ? 102 : 86)
            property int barThickness: Math.max(minBarThickness, barHeight + s(18))
            property bool edgeAttachedBar: ThemeConfig.barAttachToScreenEdge
                                          && ThemeConfig.barWidthMode === "full"
                                          && !ThemeConfig.barFloating
            property string uiFontFamily: ThemeConfig.uiFont
            property string monoFontFamily: ThemeConfig.monoFont
            property string displayFontFamily: ThemeConfig.displayFont
            property real themeLetterSpacing: ThemeConfig.letterSpacing
            property int themeFontWeight: ThemeConfig.fontWeight
            property string activeThemeName: ThemeConfig.theme
            property string activeThemeNormalized: String(activeThemeName || "").toLowerCase()
            property int cyberUnderhang: (isHorizontalBar && isTopBar && activeThemeNormalized === "cyber") ? 0 : 0
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
                     ? (barWindow.isBottomBar ? 0 : (barWindow.edgeAttachedBar ? 0 : s(8)))
                     : (barWindow.edgeAttachedBar ? 0 : s(8))
                bottom: barWindow.isHorizontalBar
                        ? (barWindow.isBottomBar ? (barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
                        : (barWindow.edgeAttachedBar ? 0 : s(8))
                left: barWindow.isHorizontalBar
                      ? (barWindow.edgeAttachedBar ? 0 : s(8))
                      : (barWindow.isLeftBar ? (barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
                right: barWindow.isHorizontalBar
                       ? (barWindow.edgeAttachedBar ? 0 : s(8))
                       : (barWindow.isRightBar ? (barWindow.edgeAttachedBar ? 0 : s(8)) : 0)
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
                onTriggered: loadTopBarSettingsProc.running = true
            }

            // --- Mode State ---
            property string activeMode: "office"
            property var moduleList: ["workspaces", "clock", "updates", "network", "battery", "volume", "bluetooth", "notifications"]
            property bool barAutoHide: false
            property bool barVisible: true
            property int updateCount: 0
            property int volumeWheelAccumulator: 0

            function _defaultModules(mode) {
                if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "battery", "volume", "game_launcher", "clock"];
                if (mode === "media")  return ["volume", "brightness", "media_controls", "battery", "clock"];
                return ["workspaces", "clock", "updates", "network", "battery", "volume", "bluetooth", "notifications"];
            }

            function _normalizeModules(mode, modules) {
                let normalized = Array.isArray(modules) ? modules.slice() : [];
                if (mode === "office" && normalized.indexOf("updates") === -1) {
                    normalized.push("updates");
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

            function volumeIconFor(volumePercent, muted) {
                let vol = Math.max(0, Math.min(150, parseInt(volumePercent) || 0));
                if (muted || vol === 0) return "󰝟";
                if (vol >= 70) return "󰕾";
                if (vol >= 30) return "󰖀";
                return "󰕿";
            }

            function applyAudioState(volumePercent, muted) {
                let vol = Math.max(0, Math.min(150, parseInt(volumePercent) || 0));
                let mutedBool = (muted === true || muted === "true");
                let newVol = vol.toString() + "%";
                let newIcon = volumeIconFor(vol, mutedBool);
                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                if (barWindow.isMuted !== mutedBool) barWindow.isMuted = mutedBool;
                if (barWindow.volIcon !== newIcon) barWindow.volIcon = newIcon;
            }

            function handleVolumeWheel(deltaY) {
                if (!deltaY || deltaY === 0) return;
                barWindow.volumeWheelAccumulator += deltaY;
                let steps = 0;

                while (barWindow.volumeWheelAccumulator >= 120) {
                    steps += 1;
                    barWindow.volumeWheelAccumulator -= 120;
                }
                while (barWindow.volumeWheelAccumulator <= -120) {
                    steps -= 1;
                    barWindow.volumeWheelAccumulator += 120;
                }

                if (steps === 0) return;

                let current = parseInt(String(barWindow.volPercent).replace("%", "")) || 0;
                let next = current + steps;
                next = Math.max(0, Math.min(150, next));

                applyAudioState(next, false);

                if (steps > 0) {
                    Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/sys_info.sh --vol-up " + steps]);
                } else {
                    Quickshell.execDetached(["bash", "-c", "~/.config/quickshell/sys_info.sh --vol-down " + Math.abs(steps)]);
                }

                if (!audioPoller.running) audioPoller.running = true;
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
                onTriggered: loadModeProc.running = true
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
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string batPercent: "100%"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            property string kbLayout: "us"
            
            ListModel { id: workspacesModel }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

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
                    if (barWindow.moduleList.includes("updates")) {
                        updatesPoller.running = true;
                    }
                }
            }

            onActiveModeChanged: {
                if (barWindow.activeMode === "office") {
                    updatesPoller.running = true;
                }
            }

            // Derived properties for UI logic
            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap >= 70) return mocha.blue;
                if (batCap >= 30) return mocha.yellow;
                return mocha.red;
            }

            // ==========================================
            // DATA FETCHING 
            // ==========================================

            // Workspaces --------------------------------
            // 1. The continuous background daemon
            Process {
                id: wsDaemon
                command: ["bash", "-c", "~/.config/quickshell/workspaces.sh"]
                running: true
            }

            // 2. The lightweight reader
            Process {
                id: wsReader
                command: ["bash", "-c", "cat /tmp/qs_workspaces.json 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { 
                                let newData = JSON.parse(txt);
                                if (workspacesModel.count !== newData.length) {
                                    workspacesModel.clear();
                                    for (let i = 0; i < newData.length; i++) {
                                        workspacesModel.append({ "wsId": newData[i].id.toString(), "wsState": newData[i].state });
                                    }
                                } else {
                                    for (let i = 0; i < newData.length; i++) {
                                        if (workspacesModel.get(i).wsState !== newData[i].state) {
                                            workspacesModel.setProperty(i, "wsState", newData[i].state);
                                        }
                                        if (workspacesModel.get(i).wsId !== newData[i].id.toString()) {
                                            workspacesModel.setProperty(i, "wsId", newData[i].id.toString());
                                        }
                                    }
                                }
                            } catch(e) {}
                        }
                    }
                }
            }

            // 3. Ultra-fast 50ms loop.
            Timer { 
                interval: 50 
                running: true 
                repeat: true 
                onTriggered: wsReader.running = true 
            }

            // Music -------------------------------------
            // 1. Fast cache reader to smoothly update the timestamp 
            Process {
                id: musicPoller
                command: ["bash", "-c", "cat /tmp/music_info.json 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            // 2. Direct executor for zero-latency UI state changes (play/pause skips)
            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/quickshell/music/music_info.sh | tee /tmp/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {}
                        }
                    }
                }
            }

            // 3. Lightweight timer to update the progress clock without freezing
            Timer {
                interval: 1000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: musicPoller.running = true
            }

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
                                
                                // Targeted Updates
                                if (barWindow.wifiStatus !== data.wifi.status) barWindow.wifiStatus = data.wifi.status;
                                if (barWindow.wifiIcon !== data.wifi.icon) barWindow.wifiIcon = data.wifi.icon;
                                if (barWindow.wifiSsid !== data.wifi.ssid) barWindow.wifiSsid = data.wifi.ssid;

                                if (barWindow.btStatus !== data.bt.status) barWindow.btStatus = data.bt.status;
                                if (barWindow.btIcon !== data.bt.icon) barWindow.btIcon = data.bt.icon;
                                if (barWindow.btDevice !== data.bt.connected) barWindow.btDevice = data.bt.connected;

                                applyAudioState(data.audio.volume, data.audio.is_muted);

                                let newBat = data.battery.percent.toString() + "%";
                                if (barWindow.batPercent !== newBat) barWindow.batPercent = newBat;
                                if (barWindow.batIcon !== data.battery.icon) barWindow.batIcon = data.battery.icon;
                                if (barWindow.batStatus !== data.battery.status) barWindow.batStatus = data.battery.status;

                                if (barWindow.kbLayout !== data.keyboard.layout) barWindow.kbLayout = data.keyboard.layout;

                                barWindow.sysPollerLoaded = true;
                                barWindow.fastPollerLoaded = true;
                            } catch(e) {}
                        }
                        // When the system/music waiter finishes, instantly refresh the music state
                        musicForceRefresh.running = true; 
                        sysWaiter.running = true;
                    }
                }
            }
            
            Process {
                id: sysWaiter
                command: ["bash", "-c", "~/.config/quickshell/sys_waiter.sh"]
                // Strictly use onExited. Quickshell will no longer hook into stdout, preventing pipe deadlocks.
                onExited: sysPoller.running = true 
            }

            // Fast audio poller so topbar volume stays in sync with external changes.
            Process {
                id: audioPoller
                command: ["bash", "-c", `
                    if command -v wpctl >/dev/null 2>&1; then
                        line="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
                        vol="$(printf '%s\\n' "$line" | grep -oE '[0-9]+(\\.[0-9]+)?' | head -n1)"
                        if [[ -z "$vol" ]]; then vol="0"; fi
                        pct="$(awk "BEGIN { v=$vol; if (v < 0) v=0; if (v > 1.5) v=1.5; printf \\"%d\\", int(v*100) }")"
                        if printf '%s' "$line" | grep -q "MUTED"; then muted="true"; else muted="false"; fi
                        printf '%s|%s\\n' "$pct" "$muted"
                    elif command -v pamixer >/dev/null 2>&1; then
                        vol="$(pamixer --get-volume 2>/dev/null || echo 0)"
                        muted="$(pamixer --get-mute 2>/dev/null || echo false)"
                        printf '%s|%s\\n' "$vol" "$muted"
                    elif command -v pactl >/dev/null 2>&1; then
                        vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -n1 | tr -d '%' || echo 0)"
                        if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q 'yes'; then muted="true"; else muted="false"; fi
                        printf '%s|%s\\n' "$vol" "$muted"
                    else
                        printf '0|false\\n'
                    fi
                `]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let line = this.text.trim();
                        if (line === "") return;
                        let parts = line.split("|");
                        if (parts.length < 2) return;
                        applyAudioState(parts[0], parts[1]);
                    }
                }
            }
            Timer {
                interval: 450
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    if (!audioPoller.running) audioPoller.running = true;
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
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherPoller.running = true }

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
