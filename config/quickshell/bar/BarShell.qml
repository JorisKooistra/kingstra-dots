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
                top: ThemeConfig.barPosition !== "bottom"
                bottom: ThemeConfig.barPosition === "bottom"
                left: true
                right: true
            }
            
            // --- Responsive Scaling Logic ---
            Scaler {
                id: scaler
                currentWidth: barWindow.width
            }

            property real baseScale: scaler.baseScale
            
            // Helper function mapped to the external scaler
            function s(val) { 
                return scaler.s(val); 
            }

            property int barHeight: s(ThemeConfig.barHeight > 0 ? ThemeConfig.barHeight : 48)
            property string uiFontFamily: ThemeConfig.uiFont
            property string monoFontFamily: ThemeConfig.monoFont
            property string displayFontFamily: ThemeConfig.displayFont
            property real themeLetterSpacing: ThemeConfig.letterSpacing
            property int themeFontWeight: ThemeConfig.fontWeight

            // THICKER BAR, MINIMAL MARGINS (Scaled)
            implicitHeight: barHeight
            margins {
                top: ThemeConfig.barPosition === "bottom" ? 0 : s(8)
                bottom: ThemeConfig.barPosition === "bottom" ? s(8) : 0
                left: s(4)
                right: s(4)
            }
            
            // exclusiveZone = 0 bij auto-hide (media mode), anders height + top margin
            exclusiveZone: barWindow.barAutoHide ? 0 : barHeight + (ThemeConfig.barPosition === "bottom" ? s(8) : s(4))
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
            property var moduleList: ["workspaces", "clock", "network", "battery", "volume", "bluetooth", "notifications"]
            property bool barAutoHide: false
            property bool barVisible: true

            function _defaultModules(mode) {
                if (mode === "gaming") return ["workspaces", "cpu_temp", "gpu_temp", "ram_usage", "volume", "game_launcher", "clock"];
                if (mode === "media")  return ["volume", "brightness", "media_controls", "clock"];
                return ["workspaces", "clock", "network", "battery", "volume", "bluetooth", "notifications"];
            }

            Process {
                id: loadModeProc
                command: ["bash", "-c", "cat ~/.config/kingstra/state/mode.json 2>/dev/null"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        try {
                            let m = JSON.parse(this.text);
                            if (m.name) barWindow.activeMode = m.name;
                            barWindow.moduleList = (m.modules && m.modules.length > 0)
                                ? m.modules
                                : barWindow._defaultModules(m.name || "office");
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

                                let newVol = data.audio.volume.toString() + "%";
                                if (barWindow.volPercent !== newVol) barWindow.volPercent = newVol;
                                if (barWindow.volIcon !== data.audio.icon) barWindow.volIcon = data.audio.icon;
                                
                                let newMuted = (data.audio.is_muted === "true");
                                if (barWindow.isMuted !== newMuted) barWindow.isMuted = newMuted;

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

            // Toon bar bij hover op de bovenrand van het scherm
            MouseArea {
                id: autoHideTrigger
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: barWindow.barAutoHide ? barWindow.s(4) : 0
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
                    if (barWindow.barAutoHide && !autoHideTrigger.containsMouse)
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
