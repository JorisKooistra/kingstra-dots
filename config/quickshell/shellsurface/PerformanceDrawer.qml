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

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function refresh() {
        metricsPoller.running = true;
        fpsPoller.running = true;
    }

    Component.onCompleted: refresh()

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
            "printf '%s|%s|%s|%s|%s\\n' \"${cpu:-0}\" \"${ram:-0}\" \"${gpu:-0}\" \"${cput:---}\" \"${gput:---}\""
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
        anchors.fill: parent
        anchors.margins: 22
        spacing: 14

        MetricRow { label: "CPU"; value: root.cpuPercent + "%"; detail: root.cpuTemperature; fraction: root.cpuPercent / 100.0; accent: mocha.accent1 }
        MetricRow { label: "RAM"; value: root.ramPercent + "%"; detail: "geheugen"; fraction: root.ramPercent / 100.0; accent: mocha.accent3 }
        MetricRow { label: "GPU"; value: root.gpuPercent + "%"; detail: root.gpuTemperature; fraction: root.gpuPercent / 100.0; accent: mocha.accent2 }
        MetricRow { label: "FPS"; value: root.fps; detail: "actief scherm"; fraction: 1.0; accent: mocha.accent1Container; showTrack: false }
    }

    component MetricRow: ColumnLayout {
        required property string label
        required property string value
        required property string detail
        required property real fraction
        required property color accent
        property bool showTrack: true

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
    }
}
