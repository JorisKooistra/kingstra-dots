import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: root

    MatugenColors { id: mocha }

    property int cpuPercent: 0
    property int ramPercent: 0
    property int gpuPercent: 0
    property string cpuTemperature: "--"
    property string gpuTemperature: "--"
    property string fps: "--"
    property string powerProfile: "balanced"
    property bool powerProfilesAvailable: false
    property string uptime: "--"
    // Laatste minuut per meter (24 samples van 2,5 s) voor de mini-grafiekjes.
    readonly property int historyLength: 24
    property var cpuHistory: []
    property var ramHistory: []
    property var gpuHistory: []
    property real diskRootUsed: 0
    property real diskRootTotal: 0
    property real diskHomeUsed: 0
    property real diskHomeTotal: 0
    property real netRxRate: -1
    property real netTxRate: -1
    property real _netRxPrev: -1
    property real _netTxPrev: -1
    property real _netPrevTime: 0
    property real powerWatts: 0
    property string powerState: ""
    property var topProcesses: []
    // Welke meters de drawer toont volgt de actieve mode: Office vraagt
    // cpu_temp/ram_usage, Gaming de volledige set. Zonder bruikbare
    // mode-state blijft de rustige Office-set de fallback.
    property var modeModules: ["cpu_temp", "ram_usage"]
    readonly property bool showCpu: hasModule("cpu_temp") || !anyMeterEnabled
    readonly property bool showRam: hasModule("ram_usage") || !anyMeterEnabled
    readonly property bool showGpu: hasModule("gpu_temp")
    readonly property bool showFps: hasModule("fps")
    readonly property bool anyMeterEnabled: hasModule("cpu_temp") || hasModule("ram_usage")
        || hasModule("gpu_temp") || hasModule("fps")
    // PanelHost gebruikt deze maat, zodat de drawer krimpt als Office
    // alleen CPU/RAM toont in plaats van een leeg vlak onder de meters.
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + content.anchors.margins * 2)

    function hasModule(name) {
        return Array.isArray(modeModules) && modeModules.indexOf(name) !== -1;
    }

    function applyModeState(rawText) {
        let raw = String(rawText || "").trim();
        if (raw === "") return;
        try {
            let m = JSON.parse(raw);
            let mode = m.name || "office";
            let modules = Array.isArray(m.modules) && m.modules.length > 0 ? m.modules : null;
            if (!modules) {
                modules = mode === "gaming"
                    ? ["cpu_temp", "gpu_temp", "ram_usage", "fps"]
                    : ["cpu_temp", "ram_usage"];
            }
            root.modeModules = modules;
        } catch (e) {
            // mode.json kan tijdens een atomaire herschrijving half zichtbaar zijn.
        }
    }

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function profileLabel(profile) {
        if (profile === "performance") return "Performance";
        if (profile === "power-saver") return "Energiezuinig";
        return "Balanced";
    }

    function pushHistory(list, value) {
        let next = (list || []).slice(-(root.historyLength - 1));
        next.push(value);
        return next;
    }

    function formatBytes(kib) {
        let gib = kib / 1048576;
        if (gib >= 1000) return (gib / 1024).toFixed(1) + " TB";
        if (gib >= 100) return Math.round(gib) + " GB";
        return gib.toFixed(1) + " GB";
    }

    function formatRate(bytesPerSecond) {
        if (bytesPerSecond < 0) return "--";
        if (bytesPerSecond >= 1048576) return (bytesPerSecond / 1048576).toFixed(1) + " MB/s";
        if (bytesPerSecond >= 1024) return Math.round(bytesPerSecond / 1024) + " KB/s";
        return Math.round(bytesPerSecond) + " B/s";
    }

    function setProfile(profile) {
        if (!root.powerProfilesAvailable || profile === root.powerProfile) return;
        root.powerProfile = profile;
        Quickshell.execDetached(["powerprofilesctl", "set", profile]);
    }

    function applyNetCounters(rxText, txText) {
        let rx = parseFloat(rxText);
        let tx = parseFloat(txText);
        let now = Date.now();
        if (isNaN(rx) || isNaN(tx)) return;
        if (root._netRxPrev >= 0 && root._netPrevTime > 0 && now > root._netPrevTime) {
            let seconds = (now - root._netPrevTime) / 1000;
            // Tellers kunnen terugvallen na een herverbinding; toon dan even niets.
            root.netRxRate = rx >= root._netRxPrev ? (rx - root._netRxPrev) / seconds : -1;
            root.netTxRate = tx >= root._netTxPrev ? (tx - root._netTxPrev) / seconds : -1;
        }
        root._netRxPrev = rx;
        root._netTxPrev = tx;
        root._netPrevTime = now;
    }

    function profileAccent(profile) {
        if (profile === "performance") return mocha.red;
        if (profile === "power-saver") return mocha.green;
        return mocha.accent1;
    }

    function refresh() {
        // Poll-fallback naast de watcher, net als ShellChrome.
        modeFileView.reload();
        metricsPoller.running = true;
        processPoller.running = true;
        if (root.showFps) fpsPoller.running = true;
    }

    function openBtop() {
        Quickshell.execDetached(["kitty", "--title", "btop — Kingstra", "bash", "-lc", "exec btop"]);
    }

    Component.onCompleted: refresh()

    FileView {
        id: modeFileView
        path: Quickshell.env("HOME") + "/.config/kingstra/state/mode.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.applyModeState(__text)
    }

    Timer {
        interval: 2500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: metricsPoller
        command: ["bash", "-lc",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(seen){printf \"%.0f\",(u-prevu)*100/(t-prevt); exit} prevt=t; prevu=u; seen=1}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)); " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo); " +
            "gpu=''; gput=''; " +
            "if command -v nvidia-smi >/dev/null 2>&1; then read -r gpu gput < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr ',' ' '); fi; " +
            "if [ -z \"$gpu\" ]; then gpu=$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1); fi; " +
            "if [ -z \"$gput\" ]; then gput=$(cat /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1 | awk 'NF{printf \"%.0f\", $1/1000}'); fi; " +
            "cput=$(sensors 2>/dev/null | awk '/^(Core 0|Tdie|Package id 0|temp1):/ {gsub(/[^0-9.]/,\" \",$2); if($2+0>0){printf \"%.0f\",$2; exit}}'); " +
            "if [ -z \"$cput\" ]; then cput=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk 'NF{printf \"%.0f\", $1/1000}'); fi; " +
            "profile=$(powerprofilesctl get 2>/dev/null || echo none); " +
            "up=$(awk '{h=int($1/3600); m=int(($1%3600)/60); printf \"%dh %02dm\",h,m}' /proc/uptime 2>/dev/null || echo --); " +
            "read -r rootu roott < <(df -kP / 2>/dev/null | awk 'NR==2{print $3, $2}'); " +
            "homeu=''; homet=''; " +
            "if [ -d \"$HOME\" ] && [ \"$(stat -c %d \"$HOME\" 2>/dev/null)\" != \"$(stat -c %d / 2>/dev/null)\" ]; then read -r homeu homet < <(df -kP \"$HOME\" 2>/dev/null | awk 'NR==2{print $3, $2}'); fi; " +
            "read -r rx tx < <(awk -F'[: ]+' 'NR>2 && $2 != \"lo\" {rx+=$3; tx+=$11} END{printf \"%.0f %.0f\", rx, tx}' /proc/net/dev 2>/dev/null); " +
            "watts=''; pstate=''; " +
            "for bat in /sys/class/power_supply/BAT*; do [ -d \"$bat\" ] || continue; pstate=$(cat \"$bat/status\" 2>/dev/null); " +
            "if [ -r \"$bat/power_now\" ]; then watts=$(awk 'NF{printf \"%.1f\", $1/1000000}' \"$bat/power_now\"); " +
            "elif [ -r \"$bat/current_now\" ] && [ -r \"$bat/voltage_now\" ]; then watts=$(awk 'NR==FNR{c=$1; next} {printf \"%.1f\", c*$1/1000000000000}' \"$bat/current_now\" \"$bat/voltage_now\"); fi; break; done; " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"${cpu:-0}\" \"${ram:-0}\" \"${gpu:-0}\" \"${cput:---}\" \"${gput:---}\" \"${profile:-none}\" \"${up:---}\" " +
            "\"${rootu:-0}\" \"${roott:-0}\" \"${homeu:-0}\" \"${homet:-0}\" \"${rx:-}\" \"${tx:-}\" \"${watts:-0}\" \"${pstate:-}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 5) return;
                root.cpuPercent = root.clampPercent(parts[0]);
                root.ramPercent = root.clampPercent(parts[1]);
                root.gpuPercent = root.clampPercent(parts[2]);
                root.cpuTemperature = parts[3] === "" || parts[3] === "--" ? "--" : parts[3] + " C";
                root.gpuTemperature = parts[4] === "" || parts[4] === "--" ? "--" : parts[4] + " C";
                let profile = parts.length > 5 ? parts[5].trim() : "";
                root.powerProfilesAvailable = profile !== "" && profile !== "none";
                root.powerProfile = root.powerProfilesAvailable ? profile : "balanced";
                root.uptime = parts.length > 6 && parts[6] !== "" ? parts[6] : "--";
                root.cpuHistory = root.pushHistory(root.cpuHistory, root.cpuPercent);
                root.ramHistory = root.pushHistory(root.ramHistory, root.ramPercent);
                root.gpuHistory = root.pushHistory(root.gpuHistory, root.gpuPercent);
                if (parts.length < 15) return;
                root.diskRootUsed = parseFloat(parts[7]) || 0;
                root.diskRootTotal = parseFloat(parts[8]) || 0;
                root.diskHomeUsed = parseFloat(parts[9]) || 0;
                root.diskHomeTotal = parseFloat(parts[10]) || 0;
                root.applyNetCounters(parts[11], parts[12]);
                root.powerWatts = parseFloat(parts[13]) || 0;
                root.powerState = parts[14].trim();
            }
        }
    }

    // Een tweede top-meting geeft het actuele verbruik; de eerste is het
    // gemiddelde sinds de start van elk proces. Gedeeld door het aantal
    // cores, zodat de procenten optellen tot de CPU-meter.
    Process {
        id: processPoller
        command: ["bash", "-lc",
            "cores=$(nproc 2>/dev/null || echo 1); " +
            "top -b -n 2 -d 0.3 -w 512 2>/dev/null | awk -v cores=\"$cores\" '/^ *PID /{block++; next} block==2 && NF>=12 && $12 != \"top\" {printf \"%s:%.1f\\n\", $12, $9/cores; if(++n==3) exit}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let rows = [];
                let lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let idx = lines[i].lastIndexOf(":");
                    if (idx <= 0) continue;
                    rows.push({ name: lines[i].slice(0, idx), cpu: parseFloat(lines[i].slice(idx + 1)) || 0 });
                }
                root.topProcesses = rows;
            }
        }
    }

    Process {
        id: fpsPoller
        command: ["bash", "-lc",
            "fps=$(cat \"${XDG_RUNTIME_DIR:-/tmp}/kingstra-current-fps\" \"$HOME/.cache/quickshell/current_fps\" 2>/dev/null | awk 'NF{gsub(/[^0-9.]/,\"\",$1); if($1 != \"\") {printf \"%.0f\", $1; exit}}'); " +
            "if [ -z \"$fps\" ] && command -v hyprctl >/dev/null 2>&1; then fps=$(hyprctl -j monitors 2>/dev/null | jq -r '([.[] | select(.focused == true) | .refreshRate][0] // .[0].refreshRate // empty)' | awk 'NF{printf \"%.0f\", $1; exit}'); fi; " +
            "printf '%s\\n' \"${fps:---}\""
        ]
        stdout: StdioCollector { onStreamFinished: root.fps = this.text.trim() || "--" }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: "Systeem"; font.family: ThemeConfig.displayFont; font.pixelSize: 17; font.weight: Font.Black; color: mocha.text }
                Text { text: "Actief sinds " + root.uptime; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
            }

            Rectangle {
                readonly property color accent: root.powerState === "Charging" ? mocha.green : mocha.yellow
                visible: root.powerWatts > 0
                Layout.preferredHeight: 26
                Layout.preferredWidth: wattsText.implicitWidth + 18
                radius: height / 2
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.46)
                Text {
                    id: wattsText
                    anchors.centerIn: parent
                    text: (root.powerState === "Charging" ? "󱐋 " : "") + root.powerWatts.toFixed(1) + " W"
                    font.family: ThemeConfig.monoFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: parent.accent
                }
            }

            // Zonder power-profiles-daemon blijft het oude, alleen-lezen label staan.
            Rectangle {
                readonly property color accent: root.profileAccent(root.powerProfile)
                visible: !root.powerProfilesAvailable
                Layout.preferredHeight: 26
                Layout.preferredWidth: profileText.implicitWidth + 18
                radius: height / 2
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.46)
                Text {
                    id: profileText
                    anchors.centerIn: parent
                    text: root.profileLabel(root.powerProfile)
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: parent.accent
                }
            }
        }

        // Energieprofiel direct wisselen; het gekozen segment glijdt mee.
        Rectangle {
            id: profileSwitch
            readonly property var profiles: ["power-saver", "balanced", "performance"]
            readonly property int activeIndex: Math.max(0, profiles.indexOf(root.powerProfile))
            visible: root.powerProfilesAvailable
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: height / 2
            color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

            Rectangle {
                readonly property color accent: root.profileAccent(root.powerProfile)
                x: 3 + profileSwitch.activeIndex * ((profileSwitch.width - 6) / 3)
                y: 3
                width: (profileSwitch.width - 6) / 3
                height: profileSwitch.height - 6
                radius: height / 2
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
                border.width: 1
                border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.56)
                Behavior on x { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 3
                Repeater {
                    model: profileSwitch.profiles
                    delegate: Item {
                        required property string modelData
                        width: (profileSwitch.width - 6) / 3
                        height: profileSwitch.height - 6
                        Text {
                            anchors.centerIn: parent
                            text: root.profileLabel(parent.modelData)
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                            color: root.powerProfile === parent.modelData ? root.profileAccent(parent.modelData) : mocha.subtext0
                            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setProfile(parent.modelData)
                        }
                    }
                }
            }
        }

        MetricRow { visible: root.showCpu; label: "CPU"; value: root.cpuPercent + "%"; detail: root.cpuTemperature; fraction: root.cpuPercent / 100.0; accent: mocha.accent1; history: root.cpuHistory }
        MetricRow { visible: root.showRam; label: "RAM"; value: root.ramPercent + "%"; detail: "geheugen"; fraction: root.ramPercent / 100.0; accent: mocha.accent3; history: root.ramHistory }
        MetricRow { visible: root.showGpu; label: "GPU"; value: root.gpuPercent + "%"; detail: root.gpuTemperature; fraction: root.gpuPercent / 100.0; accent: mocha.accent2; history: root.gpuHistory }
        MetricRow { visible: root.showFps; label: "FPS"; value: root.fps; detail: "actief scherm"; fraction: 1.0; accent: mocha.accent1Container; showTrack: false }

        MetricRow {
            visible: root.diskRootTotal > 0
            label: "SSD"
            value: Math.round(root.diskRootUsed * 100 / Math.max(1, root.diskRootTotal)) + "%"
            detail: "/  " + root.formatBytes(root.diskRootTotal - root.diskRootUsed) + " vrij"
            fraction: root.diskRootUsed / Math.max(1, root.diskRootTotal)
            accent: mocha.accent2
        }
        MetricRow {
            visible: root.diskHomeTotal > 0
            label: "HOME"
            value: Math.round(root.diskHomeUsed * 100 / Math.max(1, root.diskHomeTotal)) + "%"
            detail: root.formatBytes(root.diskHomeTotal - root.diskHomeUsed) + " vrij"
            fraction: root.diskHomeUsed / Math.max(1, root.diskHomeTotal)
            accent: mocha.accent2
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "NET"; font.family: ThemeConfig.monoFont; font.pixelSize: 12; font.weight: Font.Bold; color: mocha.accent3 }
            Item { Layout.fillWidth: true }
            Text { text: "󰇚 " + root.formatRate(root.netRxRate); font.family: ThemeConfig.monoFont; font.pixelSize: 11; font.weight: Font.Bold; color: mocha.text }
            Text { text: "󰕒 " + root.formatRate(root.netTxRate); font.family: ThemeConfig.monoFont; font.pixelSize: 11; font.weight: Font.Bold; color: mocha.subtext0 }
        }

        ColumnLayout {
            visible: root.topProcesses.length > 0
            Layout.fillWidth: true
            spacing: 4
            Text { text: "Zwaarste processen"; font.family: ThemeConfig.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold; color: mocha.subtext0 }
            Repeater {
                model: root.topProcesses
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    radius: height / 2
                    color: Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.62)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        Text {
                            text: modelData.name
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.text
                        }
                        Text {
                            text: modelData.cpu.toFixed(1) + "%"
                            font.family: ThemeConfig.monoFont
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: mocha.accent1
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: Math.max(10, ThemeConfig.styleWidgetRadius)
            color: btopMouse.containsMouse
                ? Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, 0.22)
                : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.78)
            border.width: 1
            border.color: Qt.rgba(mocha.accent1.r, mocha.accent1.g, mocha.accent1.b, btopMouse.containsMouse ? 0.70 : 0.34)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                Text { text: "󰍛"; font.family: "Iosevka Nerd Font"; font.pixelSize: 17; color: mocha.accent1 }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { text: "Open btop"; font.family: ThemeConfig.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: mocha.text }
                    Text { text: "processen en detailinspectie"; font.family: ThemeConfig.uiFont; font.pixelSize: 10; color: mocha.subtext0 }
                }
                Text { text: "󰅂"; font.family: "Iosevka Nerd Font"; font.pixelSize: 14; color: mocha.subtext0 }
            }

            MouseArea {
                id: btopMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openBtop()
            }
        }
    }

    component MetricRow: ColumnLayout {
        required property string label
        required property string value
        required property string detail
        required property real fraction
        required property color accent
        property bool showTrack: true
        property var history: []

        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Text { text: label; font.family: ThemeConfig.monoFont; font.pixelSize: 12; font.weight: Font.Bold; color: accent }
            Item { Layout.fillWidth: true }
            Text { text: detail; font.family: ThemeConfig.uiFont; font.pixelSize: 11; color: mocha.subtext0 }
            Text { text: value; font.family: ThemeConfig.monoFont; font.pixelSize: 14; font.weight: Font.Black; color: mocha.text; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight }
        }
        Rectangle {
            visible: showTrack
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Qt.rgba(mocha.surface2.r, mocha.surface2.g, mocha.surface2.b, 0.72)
            Rectangle {
                width: parent.width * Math.max(0.0, Math.min(1.0, fraction))
                height: parent.height
                radius: parent.radius
                color: accent
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }
        }
        Sparkline {
            visible: showTrack && history.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            values: history
            accent: parent.accent
        }
    }

    // Afgeronde lijn met zachte vulling; 0-100 over de hele hoogte.
    component Sparkline: Canvas {
        property var values: []
        property color accent: mocha.accent1
        onValuesChanged: requestPaint()
        onAccentChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        function rgba(alpha) {
            return "rgba(" + Math.round(accent.r * 255) + "," + Math.round(accent.g * 255) + ","
                + Math.round(accent.b * 255) + "," + alpha + ")";
        }
        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let n = values.length;
            if (n < 2 || width <= 0 || height <= 0) return;
            let step = width / (root.historyLength - 1);
            let x0 = width - (n - 1) * step;
            function yFor(v) { return 1.5 + (height - 3) * (1 - Math.max(0, Math.min(100, v)) / 100); }
            ctx.beginPath();
            ctx.moveTo(x0, yFor(values[0]));
            for (let i = 1; i < n; i++) ctx.lineTo(x0 + i * step, yFor(values[i]));
            ctx.lineJoin = "round";
            ctx.lineCap = "round";
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = rgba(0.9);
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            let grad = ctx.createLinearGradient(0, 0, 0, height);
            grad.addColorStop(0, rgba(0.28));
            grad.addColorStop(1, rgba(0));
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
}
