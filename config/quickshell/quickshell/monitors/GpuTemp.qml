import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"

// GpuTemp — Leest GPU temperatuur (nvidia-smi of /sys/class/drm)
Rectangle {
    id: root
    property var mocha
    property int pillHeight: 34
    property bool isHovered: gpuMouse.containsMouse

    color: isHovered
        ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6)
        : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
    radius: 10
    height: pillHeight
    clip: true

    Behavior on color { ColorAnimation { duration: 200 } }

    property string tempStr: ""
    property string usagePct: ""
    property string gpuName: "GPU"
    property color tempColor: mocha.green

    function _colorForTemp(t) {
        if (t >= 90) return mocha.red;
        if (t >= 80) return mocha.peach;
        if (t >= 65) return mocha.yellow;
        return mocha.green;
    }

    Process {
        id: gpuPoller
        command: ["bash", "-c",
            // Nvidia exposes both metrics; AMD often exposes sysfs metrics; Intel iGPU may expose neither.
            "if command -v nvidia-smi >/dev/null 2>&1; then " +
                "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', *' 'NF>=2{print $1\"%|\"$2\"°C|NVIDIA\"; exit}' && exit 0; " +
            "fi; " +
            "busy=''; temp=''; " +
            "for p in /sys/class/drm/card[0-9]/device/gpu_busy_percent; do [ -r \"$p\" ] && { busy=$(cat \"$p\" 2>/dev/null | head -1); break; }; done; " +
            "if [ -z \"$busy\" ]; then " +
                "for p in /sys/class/drm/card[0-9]/gt/gt*/rc6_residency_ms /sys/class/drm/card[0-9]/device/drm/card[0-9]/gt/gt*/rc6_residency_ms; do " +
                    "[ -r \"$p\" ] || continue; " +
                    "a=$(cat \"$p\" 2>/dev/null); sleep 0.25; b=$(cat \"$p\" 2>/dev/null); " +
                    "busy=$(awk -v a=\"$a\" -v b=\"$b\" 'BEGIN{busy=100-((b-a)*100/250); if(busy<0)busy=0; if(busy>100)busy=100; printf \"%.0f\", busy}'); " +
                    "break; " +
                "done; " +
            "fi; " +
            "for p in /sys/class/drm/card[0-9]/device/hwmon/hwmon*/temp*_input; do [ -r \"$p\" ] && { temp=$(cat \"$p\" 2>/dev/null | head -1); break; }; done; " +
            "label=$(lspci 2>/dev/null | awk 'BEGIN{IGNORECASE=1} /VGA|3D|Display/ {if ($0 ~ /Intel/) print \"iGPU\"; else if ($0 ~ /NVIDIA/) print \"NVIDIA\"; else if ($0 ~ /AMD|Radeon/) print \"AMD\"; else print \"GPU\"; exit}'); " +
            "[ -n \"$label\" ] || label='GPU'; " +
            "usage=''; temp_c=''; " +
            "[ -n \"$busy\" ] && usage=\"${busy}%\"; " +
            "[ -n \"$temp\" ] && temp_c=$(awk -v t=\"$temp\" 'BEGIN{printf \"%.0f°C\", t/1000}'); " +
            "printf '%s|%s|%s\\n' \"$usage\" \"$temp_c\" \"$label\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let t = this.text.trim().replace(/\s+/g, " ");
                if (t !== "") {
                    let parts = t.split("|");
                    root.usagePct = parts[0] || "";
                    root.tempStr = parts.length > 1 ? parts[1] : "";
                    root.gpuName = parts.length > 2 && parts[2] !== "" ? parts[2] : "GPU";
                    let val = parseFloat(root.tempStr);
                    if (!isNaN(val)) root.tempColor = root._colorForTemp(val);
                }
            }
        }
    }

    Timer { interval: 3000; running: true; repeat: true; onTriggered: gpuPoller.running = true }
    Component.onCompleted: gpuPoller.running = true

    property real targetWidth: gpuRow.width + 24
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    Row {
        id: gpuRow
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "GPU"
            font.family: "JetBrains Mono"; font.pixelSize: 11; font.weight: Font.Black
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.usagePct
            visible: root.usagePct !== ""
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.tempStr
            visible: root.tempStr !== ""
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
        Text {
            text: root.gpuName
            visible: root.usagePct === "" && root.tempStr === ""
            font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black
            color: root.tempColor
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    MouseArea {
        id: gpuMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: Quickshell.execDetached(["bash", "-c", "kitty --class floating-btop -e btop 2>/dev/null || btop 2>/dev/null || true"])
    }
}
