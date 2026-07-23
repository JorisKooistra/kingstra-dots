import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import ".."

Item {
    id: root

    required property var mocha
    property int shellBorderWidth: 8
    property int railWidth: 48
    property int stripHeight: 34

    readonly property bool active: String(ThemeConfig.theme || ThemeConfig.styleFamily || "").toLowerCase() === "neon"
    readonly property color cyan: mocha.teal || "#9be8ff"
    readonly property color cyanSoft: mocha.sky || mocha.blue || "#7fcfff"
    readonly property color magenta: mocha.pink || "#ff72d2"
    readonly property color glass: mocha.crust || "#020712"
    readonly property real hudAlpha: 0.96
    readonly property real panelAlpha: 0.44

    property string uptimeText: "--h --m"
    property string loadText: "-- -- --"
    property int cpuPercent: 0
    property int ramPercent: 0
    property int gpuPercent: 0
    property bool gpuAvailable: false
    property bool gpuPresent: false
    property string gpuName: "GPU"
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan3Rpm: 0
    property int fan4Rpm: 0
    property bool fan1Available: false
    property bool fan2Available: false
    property bool fan3Available: false
    property bool fan4Available: false
    readonly property string gpuDisplay: gpuAvailable ? (gpuPercent + "%") : (gpuPresent ? gpuName : "n/a")

    anchors.fill: parent
    visible: active
    opacity: active ? 1.0 : 0.0

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    Timer {
        interval: 3000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!telemetryPoll.running) telemetryPoll.running = true
    }

    Process {
        id: telemetryPoll
        command: ["bash", "-lc",
            "up=$(awk '{printf \"%dh %02dm\", int($1/3600), int(($1%3600)/60)}' /proc/uptime 2>/dev/null || echo '--h --m'); " +
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(seen){printf \"%.0f\",(u-prevu)*100/(t-prevt); exit} prevt=t; prevu=u; seen=1}' <(cat /proc/stat; sleep 0.20; cat /proc/stat)); " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo 2>/dev/null); " +
            "gpu=''; " +
            "if command -v nvidia-smi >/dev/null 2>&1; then gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | awk '$1 ~ /^[0-9]+([.][0-9]+)?$/ {printf \"%.0f\", $1; exit}'); fi; " +
            "if [ -z \"$gpu\" ]; then for p in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do [ -r \"$p\" ] || continue; gpu=$(cat \"$p\" 2>/dev/null | awk '$1 ~ /^[0-9]+([.][0-9]+)?$/ {printf \"%.0f\", $1; exit}'); [ -n \"$gpu\" ] && break; done; fi; " +
            "if [ -z \"$gpu\" ]; then for p in /sys/class/drm/card[0-9]/gt/gt*/rc6_residency_ms /sys/class/drm/card[0-9]/device/drm/card[0-9]/gt/gt*/rc6_residency_ms; do [ -r \"$p\" ] || continue; a=$(cat \"$p\" 2>/dev/null); sleep 0.25; b=$(cat \"$p\" 2>/dev/null); gpu=$(awk -v a=\"$a\" -v b=\"$b\" 'BEGIN{busy=100-((b-a)*100/250); if(busy<0)busy=0; if(busy>100)busy=100; printf \"%.0f\", busy}'); break; done; fi; " +
            "label=$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA|3D|Display/ {if ($0 ~ /Intel/) print \"iGPU\"; else if ($0 ~ /NVIDIA/) print \"NVIDIA\"; else if ($0 ~ /AMD|Radeon/) print \"AMD\"; else print \"GPU\"; exit}'); " +
            "[ -n \"$label\" ] || label='GPU'; " +
            "fans=$(for p in /sys/class/hwmon/hwmon*/fan*_input; do [ -r \"$p\" ] || continue; awk '$1+0>0{print int($1)}' \"$p\" 2>/dev/null; done | head -4 | xargs); " +
            "set -- $fans; " +
            "if [ -z \"$gpu\" ]; then gpu='--'; fi; " +
            "load=$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo '-- -- --'); " +
            "printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\\n' \"${up:-'--h --m'}\" \"${cpu:-0}\" \"${ram:-0}\" \"$gpu\" \"$load\" \"$label\" \"${1:-0}\" \"${2:-0}\" \"${3:-0}\" \"${4:-0}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 10) return;
                root.uptimeText = parts[0] || "--h --m";
                root.cpuPercent = root.clampPercent(parts[1]);
                root.ramPercent = root.clampPercent(parts[2]);
                root.gpuAvailable = parts[3] !== "" && parts[3] !== "--";
                root.gpuPercent = root.gpuAvailable ? root.clampPercent(parts[3]) : 0;
                root.loadText = parts[4] || "-- -- --";
                root.gpuName = parts[5] || "GPU";
                root.gpuPresent = root.gpuAvailable || root.gpuName !== "";
                root.fan1Rpm = Math.max(0, parseInt(parts[6]) || 0);
                root.fan2Rpm = Math.max(0, parseInt(parts[7]) || 0);
                root.fan1Available = root.fan1Rpm > 0;
                root.fan2Available = root.fan2Rpm > 0;
                root.fan3Rpm = Math.max(0, parseInt(parts[8]) || 0);
                root.fan4Rpm = Math.max(0, parseInt(parts[9]) || 0);
                root.fan3Available = root.fan3Rpm > 0;
                root.fan4Available = root.fan4Rpm > 0;
            }
        }
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(root.cyanSoft.r, root.cyanSoft.g, root.cyanSoft.b, 0.032) }

    PerspectiveFrame {
        anchors.fill: parent
        anchors.margins: Math.max(root.shellBorderWidth + 20, 28)
        accent: root.cyan
    }

    TelemetryPanel {
        x: root.railWidth + 48
        y: Math.max(root.stripHeight + 92, root.height * 0.16)
        width: Math.min(root.width * 0.20, 360)
        height: 184
        rotation: -1.4
        accent: root.cyan
    }

    VerticalMeter {
        x: root.railWidth + 66
        y: root.height - height - root.shellBorderWidth - 150
        width: 86
        height: Math.min(root.height * 0.34, 330)
        rotation: -1.4
        label: "RAM"
        value: root.ramPercent
        display: root.ramPercent + "%"
        accent: root.cyan
    }

    HudFrame {
        id: topVisor
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(root.stripHeight + 26, 46)
        width: Math.min(parent.width * 0.42, 800)
        height: 96
        rotation: -0.6
        accent: root.cyan
        label: "SYSTEM MONITOR"
        primary: "UP " + root.uptimeText
        secondary: "LOAD " + root.loadText
        primaryPixelSize: 26
    }

    HudFrame {
        x: root.width - width - root.shellBorderWidth - 56
        y: Math.max(root.stripHeight + 94, root.height * 0.16)
        width: Math.min(root.width * 0.25, 460)
        height: 164
        rotation: 1.1
        accent: root.cyan
        label: "SUMMARY"
        primary: "SESSION STABLE"
        secondary: "CPU " + root.cpuPercent + "%  RAM " + root.ramPercent + "%  GPU " + root.gpuDisplay
        primaryPixelSize: 24
    }

    Radar {
        x: root.width - width - root.shellBorderWidth - 70
        y: root.height - height - root.shellBorderWidth - 84
        size: Math.min(root.width * 0.14, 210)
        accent: root.cyan
    }

    FanGridPanel {
        x: root.width - width - root.shellBorderWidth - 70
        y: Math.max(root.stripHeight + 292, root.height * 0.36)
        width: Math.min(root.width * 0.18, 340)
        height: 206
        rotation: 1.1
        accent: root.cyan
    }

    HudFrame {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height - height - root.shellBorderWidth - 32
        width: Math.min(parent.width * 0.28, 520)
        height: 92
        rotation: 1.1
        accent: root.cyan
        label: "UPTIME"
        primary: root.uptimeText
        secondary: "LOAD " + root.loadText + " / GPU " + root.gpuDisplay
        primaryPixelSize: 30
    }

    Rectangle {
        id: scanSweep
        x: -width
        y: topVisor.y + topVisor.height + 18
        width: Math.max(220, root.width * 0.16)
        height: 1
        opacity: 0.42
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.50; color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.95) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        SequentialAnimation on x {
            running: root.active
            loops: Animation.Infinite
            NumberAnimation { to: root.width; duration: ThemeConfig.duration(12500); easing.type: Easing.Linear }
            NumberAnimation { to: -scanSweep.width; duration: 0 }
        }
    }

    component PerspectiveFrame: Item {
        required property color accent
        property real lineAlpha: 0.94

        Canvas {
            id: convexOutline
            anchors.fill: parent
            opacity: 1.0
            onPaint: {
                let ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.lineWidth = 2.2;
                ctx.strokeStyle = Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha);
                ctx.shadowColor = Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.72);
                ctx.shadowBlur = 18;

                let w = width;
                let h = height;
                let m = 18;
                let notch = Math.min(92, w * 0.055);
                let bulgeX = Math.min(34, w * 0.018);
                let bulgeY = Math.min(26, h * 0.030);

                ctx.beginPath();
                ctx.moveTo(m + notch, m + 12);
                ctx.quadraticCurveTo(w * 0.50, m + bulgeY, w - m - notch, m + 12);
                ctx.lineTo(w - m - 18, m + notch);
                ctx.quadraticCurveTo(w - m - bulgeX, h * 0.50, w - m - 18, h - m - notch);
                ctx.lineTo(w - m - notch, h - m - 12);
                ctx.quadraticCurveTo(w * 0.50, h - m - bulgeY, m + notch, h - m - 12);
                ctx.lineTo(m + 18, h - m - notch);
                ctx.quadraticCurveTo(m + bulgeX, h * 0.50, m + 18, m + notch);
                ctx.closePath();
                ctx.stroke();

                ctx.lineWidth = 1.2;
                ctx.globalAlpha = 0.70;
                ctx.beginPath();
                ctx.moveTo(m + 52, m + 48);
                ctx.quadraticCurveTo(w * 0.50, m + 74, w - m - 52, m + 48);
                ctx.moveTo(m + 52, h - m - 48);
                ctx.quadraticCurveTo(w * 0.50, h - m - 74, w - m - 52, h - m - 48);
                ctx.stroke();

                ctx.globalAlpha = 0.84;
                ctx.lineWidth = 2.0;
                ctx.beginPath();
                ctx.moveTo(w * 0.35, m + 6);
                ctx.lineTo(w * 0.40, m + 44);
                ctx.lineTo(w * 0.60, m + 44);
                ctx.lineTo(w * 0.65, m + 6);
                ctx.moveTo(w * 0.40, h - m - 44);
                ctx.lineTo(w * 0.36, h - m - 8);
                ctx.lineTo(w * 0.64, h - m - 8);
                ctx.lineTo(w * 0.60, h - m - 44);
                ctx.stroke();
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        Rectangle {
            x: 70
            y: 46
            width: parent.width * 0.22
            height: 1
            rotation: 18
            transformOrigin: Item.Left
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha * 0.82)
        }
        Rectangle {
            x: parent.width - parent.width * 0.25 - 76
            y: parent.height - 60
            width: parent.width * 0.25
            height: 1
            rotation: -16
            transformOrigin: Item.Left
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha * 0.82)
        }

        Repeater {
            model: 4
            Rectangle {
                width: index % 2 === 0 ? 62 : 38
                height: 1
                x: index < 2 ? 18 + index * 64 : parent.width - 118 + (index - 2) * 52
                y: index % 2 === 0 ? 34 : parent.height - 58
                rotation: index < 2 ? 25 : -25
                color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, parent.lineAlpha * 0.74)
            }
        }
    }

    component TelemetryPanel: Item {
        required property color accent

        HudPanelChrome {
            anchors.fill: parent
            accent: parent.accent
        }

        Text {
            x: 18
            y: 14
            text: "TELEMETRY"
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.96)
            renderType: Text.NativeRendering
        }

        Text {
            x: 18
            y: 42
            width: parent.width - 36
            text: "SYSTEM LOAD"
            elide: Text.ElideRight
            font.family: ThemeConfig.displayFont
            font.pixelSize: 22
            font.weight: Font.Light
            color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.98)
            renderType: Text.NativeRendering
        }

        ColumnLayout {
            x: 20
            y: 86
            width: parent.width - 40
            spacing: 12
            StatBar { label: "CPU"; value: root.cpuPercent; accent: root.cyan }
            StatBar { label: "RAM"; value: root.ramPercent; accent: root.cyanSoft }
            StatBar { label: "GPU"; value: root.gpuPercent; display: root.gpuDisplay; accent: root.magenta; available: root.gpuPresent }
        }
    }

    component FanGridPanel: Item {
        required property color accent

        HudPanelChrome {
            anchors.fill: parent
            accent: parent.accent
        }

        Text {
            x: 16
            y: 13
            text: "THERMAL"
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.96)
        }

        GridLayout {
            x: 14
            y: 38
            width: parent.width - 28
            height: parent.height - 52
            columns: 2
            columnSpacing: 10
            rowSpacing: 10
            FanTile { label: "FAN 1"; rpm: root.fan1Rpm; available: root.fan1Available; accent: root.cyan }
            FanTile { label: "FAN 2"; rpm: root.fan2Rpm; available: root.fan2Available; accent: root.cyanSoft }
            FanTile { label: "FAN 3"; rpm: root.fan3Rpm; available: root.fan3Available; accent: root.cyan }
            FanTile { label: "FAN 4"; rpm: root.fan4Rpm; available: root.fan4Available; accent: root.cyanSoft }
        }
    }

    component HudPanelChrome: Item {
        required property color accent

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.24)
            radius: 2
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, root.panelAlpha)
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, root.hudAlpha)
            radius: 2
        }
        Rectangle { x: 0; y: 0; width: parent.width * 0.38; height: 2; color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.98) }
        Rectangle { x: parent.width * 0.70; y: parent.height - 2; width: parent.width * 0.30; height: 2; color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.98) }
        Rectangle { x: parent.width - 42; y: 0; width: 62; height: 1; rotation: 34; color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.80) }
        Rectangle { x: -18; y: parent.height - 1; width: 72; height: 1; rotation: -30; color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.72) }
    }

    component VerticalMeter: Item {
        required property string label
        required property int value
        required property string display
        required property color accent

        HudPanelChrome {
            anchors.fill: parent
            accent: parent.accent
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 46
            width: 16
            height: parent.height - 92
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.28)
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.42)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width - 4
                height: (parent.height - 4) * Math.max(0.0, Math.min(1.0, value / 100.0))
                color: Qt.rgba(parent.parent.accent.r, parent.parent.accent.g, parent.parent.accent.b, 0.86)
                Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            }
        }
        Text {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 14
            text: label
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Black
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.88)
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 14
            text: display
            font.family: ThemeConfig.displayFont
            font.pixelSize: 18
            color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.90)
        }
    }

    component FanTile: Item {
        required property string label
        required property int rpm
        required property bool available
        required property color accent
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 64

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, available ? 0.34 : 0.18)
            border.width: 1
            border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, available ? 0.82 : 0.30)
            radius: 2
        }
        Item {
            id: fanGlyph
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            height: 42
            opacity: available ? 0.95 : 0.28
            property color glyphAccent: parent.accent

            Canvas {
                id: fanRings
                anchors.fill: parent
                antialiasing: true
                opacity: available ? 0.98 : 0.50
                onPaint: {
                    let ctx = getContext("2d");
                    let w = width;
                    let h = height;
                    let cx = w / 2;
                    let cy = h / 2;
                    let r = Math.min(w, h) / 2 - 3;
                    ctx.clearRect(0, 0, w, h);
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82);
                    ctx.shadowColor = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.70);
                    ctx.shadowBlur = 8;

                    ctx.lineWidth = 1.8;
                    for (let i = 0; i < 4; i++) {
                        let start = i * Math.PI / 2 + 0.12;
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, start, start + Math.PI / 2 - 0.34);
                        ctx.stroke();
                    }

                    ctx.shadowBlur = 0;
                    ctx.lineWidth = 1.0;
                    ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.38);
                    ctx.beginPath();
                    ctx.arc(cx, cy, r * 0.58, 0, Math.PI * 2);
                    ctx.stroke();

                    ctx.fillStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.88);
                    for (let i = 0; i < 8; i++) {
                        let a = i * Math.PI / 4;
                        let x1 = cx + Math.cos(a) * (r + 1);
                        let y1 = cy + Math.sin(a) * (r + 1);
                        ctx.save();
                        ctx.translate(x1, y1);
                        ctx.rotate(a);
                        ctx.fillRect(-1.5, -0.8, 3, 1.6);
                        ctx.restore();
                    }
                }
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
            }

            Item {
                id: rotorSpin
                anchors.fill: parent

                Canvas {
                    anchors.fill: parent
                    antialiasing: true
                    onPaint: {
                        let ctx = getContext("2d");
                        let w = width;
                        let h = height;
                        let cx = w / 2;
                        let cy = h / 2;
                        let r = Math.min(w, h) / 2 - 5;
                        ctx.clearRect(0, 0, w, h);
                        ctx.translate(cx, cy);
                        ctx.shadowColor = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82);
                        ctx.shadowBlur = 10;

                        for (let i = 0; i < 5; i++) {
                            ctx.save();
                            ctx.rotate(i * Math.PI * 2 / 5);
                            let blade = ctx.createLinearGradient(0, -2, r * 0.78, -9);
                            blade.addColorStop(0.0, Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.12));
                            blade.addColorStop(0.45, Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.82));
                            blade.addColorStop(1.0, Qt.rgba(root.magenta.r, root.magenta.g, root.magenta.b, 0.30));
                            ctx.fillStyle = blade;
                            ctx.beginPath();
                            ctx.moveTo(3, -2);
                            ctx.quadraticCurveTo(r * 0.42, -12, r * 0.78, -5);
                            ctx.quadraticCurveTo(r * 0.55, 5, 6, 4);
                            ctx.closePath();
                            ctx.fill();
                            ctx.restore();
                        }

                        ctx.shadowBlur = 0;
                        ctx.strokeStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.76);
                        ctx.lineWidth = 1.3;
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.30, 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.fillStyle = Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.84);
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.18, 0, Math.PI * 2);
                        ctx.fill();
                        ctx.fillStyle = Qt.rgba(fanGlyph.glyphAccent.r, fanGlyph.glyphAccent.g, fanGlyph.glyphAccent.b, 0.92);
                        ctx.beginPath();
                        ctx.arc(0, 0, r * 0.09, 0, Math.PI * 2);
                        ctx.fill();
                    }
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }
                RotationAnimation on rotation {
                    running: root.active && available
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: Math.max(850, 4600 - rpm)
                }
            }
        }
        ColumnLayout {
            x: 64
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            spacing: 2
            Text {
                Layout.fillWidth: true
                text: label
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                font.weight: Font.Black
                color: Qt.rgba(parent.parent.accent.r, parent.parent.accent.g, parent.parent.accent.b, 0.84)
            }
            Text {
                Layout.fillWidth: true
                text: available ? (rpm + " RPM") : "offline"
                elide: Text.ElideRight
                font.family: ThemeConfig.displayFont
                font.pixelSize: 15
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, available ? 0.90 : 0.38)
            }
        }
    }

    component HudFrame: Item {
        required property color accent
        required property string label
        required property string primary
        required property string secondary
        property int primaryPixelSize: Math.max(18, Math.min(42, height * 0.38))

        HudPanelChrome {
            anchors.fill: parent
            accent: parent.accent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 3
            Text {
                text: label
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                font.weight: Font.Black
                color: Qt.rgba(parent.parent.accent.r, parent.parent.accent.g, parent.parent.accent.b, 0.96)
                renderType: Text.NativeRendering
            }
            Text {
                text: primary
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: ThemeConfig.displayFont
                font.pixelSize: parent.parent.primaryPixelSize
                font.weight: Font.Light
                color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, 0.96)
                renderType: Text.NativeRendering
            }
            Text {
                text: secondary
                Layout.fillWidth: true
                elide: Text.ElideRight
                font.family: ThemeConfig.monoFont
                font.pixelSize: 10
                color: Qt.rgba(root.cyanSoft.r, root.cyanSoft.g, root.cyanSoft.b, 0.88)
                renderType: Text.NativeRendering
            }
        }
    }

    component StatBar: ColumnLayout {
        required property string label
        required property int value
        required property color accent
        property bool available: true
        property string display: available ? (value + "%") : "n/a"
        Layout.fillWidth: true
        spacing: 3
        RowLayout {
            Layout.fillWidth: true
            Text { text: label; font.family: ThemeConfig.monoFont; font.pixelSize: 10; font.weight: Font.Black; color: Qt.rgba(accent.r, accent.g, accent.b, 0.96) }
            Item { Layout.fillWidth: true }
            Text { text: display; font.family: ThemeConfig.monoFont; font.pixelSize: 10; color: Qt.rgba(root.cyan.r, root.cyan.g, root.cyan.b, available ? 0.92 : 0.42) }
        }
        Rectangle {
            Layout.fillWidth: true
            height: 4
            color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.42)
            border.width: 1
            border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.30)
            Rectangle {
                width: available ? parent.width * Math.max(0.0, Math.min(1.0, value / 100.0)) : 0
                height: parent.height
                color: Qt.rgba(accent.r, accent.g, accent.b, 0.88)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }
        }
    }

    component Radar: Item {
        required property real size
        required property color accent
        width: size
        height: size
        opacity: 0.72

        Repeater {
            model: 4
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * (0.25 + index * 0.20)
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.24 + index * 0.04)
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.86
            height: 1
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.42)
        }
        Rectangle {
            anchors.centerIn: parent
            width: 1
            height: parent.height * 0.86
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.30)
        }
        Rectangle {
            id: radarNeedle
            x: parent.width / 2
            y: parent.height / 2
            width: parent.width * 0.43
            height: 2
            transformOrigin: Item.Left
            color: Qt.rgba(parent.accent.r, parent.accent.g, parent.accent.b, 0.66)
            RotationAnimation on rotation {
                running: root.active
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: ThemeConfig.duration(18000)
            }
        }
    }
}
