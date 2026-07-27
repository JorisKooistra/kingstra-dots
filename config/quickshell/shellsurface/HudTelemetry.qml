import QtQuick
import Quickshell
import Quickshell.Io
import ".."

Scope {
    id: root

    property bool active: false

    property int cpuPercent: 0
    property int ramPercent: 0
    property int gpuPercent: -1
    property int diskPercent: 0
    property int cpuTemperature: 0
    property int gpuTemperature: 0
    property int batteryPercent: -1
    property int fan1Rpm: 0
    property int fan2Rpm: 0
    property int fan3Rpm: 0
    property int fan4Rpm: 0
    property real downloadKiB: 0
    property real uploadKiB: 0
    property string uptimeText: "--"
    property string interfaceName: "--"
    property string hostName: "localhost"
    property string kernelVersion: "--"
    property string gpuName: "GPU"
    property string cpuName: "CPU"
    property string coreCount: "--"
    property string ipAddress: "--"
    property string platformProfile: "--"

    property double previousCpuTotal: 0
    property double previousCpuIdle: 0
    property double previousRxBytes: 0
    property double previousTxBytes: 0
    property double previousSampleMs: 0
    property bool staticLoaded: false
    property bool warmupDone: false

    readonly property string helperPath: Quickshell.env("HOME")
        + "/.config/quickshell/shellsurface/hud-telemetry.sh"
    readonly property bool gpuAvailable: gpuPercent >= 0
    readonly property bool cpuTemperatureAvailable: cpuTemperature > 0
    readonly property bool gpuTemperatureAvailable: gpuTemperature > 0
    readonly property bool batteryAvailable: batteryPercent >= 0
    readonly property string linkState: interfaceName === "--" ? "OFFLINE" : "LINKED"

    function clampPercent(value) {
        const parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    function formatUptime(seconds) {
        const total = Math.max(0, parseInt(seconds) || 0);
        const days = Math.floor(total / 86400);
        const hours = Math.floor((total % 86400) / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        if (days > 0) return days + "d " + hours + "h";
        return hours + "h " + String(minutes).padStart(2, "0") + "m";
    }

    function formatRate(kib) {
        const value = Math.max(0, Number(kib) || 0);
        if (value >= 1024) return (value / 1024).toFixed(value >= 10240 ? 0 : 1) + " MiB/s";
        return value.toFixed(value >= 100 ? 0 : 1) + " KiB/s";
    }

    function requestStaticData() {
        if (active && !staticLoaded && !staticPoll.running) staticPoll.running = true;
    }

    onActiveChanged: {
        if (!active) return;
        requestStaticData();
        if (!dynamicPoll.running) dynamicPoll.running = true;
    }

    Component.onCompleted: {
        requestStaticData();
        if (active && !dynamicPoll.running) dynamicPoll.running = true;
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: if (!dynamicPoll.running) dynamicPoll.running = true
    }

    Timer {
        id: warmupPoll
        interval: 250
        repeat: false
        onTriggered: if (root.active && !dynamicPoll.running) dynamicPoll.running = true
    }

    Process {
        id: staticPoll
        command: ["bash", root.helperPath, "--static"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                if (parts.length < 6) return;
                root.hostName = parts[0] || "localhost";
                root.kernelVersion = parts[1] || "--";
                root.gpuName = parts[2] || "GPU";
                root.cpuName = parts[3] || "CPU";
                root.coreCount = parts[4] || "--";
                root.ipAddress = parts[5] || "--";
                root.staticLoaded = true;
            }
        }
    }

    Process {
        id: dynamicPoll
        command: ["bash", root.helperPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("|");
                if (parts.length < 16) return;

                const total = Number(parts[0]) || 0;
                const idle = Number(parts[1]) || 0;
                const totalDelta = total - root.previousCpuTotal;
                const idleDelta = idle - root.previousCpuIdle;
                if (root.previousCpuTotal > 0 && totalDelta > 0)
                    root.cpuPercent = root.clampPercent(100 * (totalDelta - idleDelta) / totalDelta);
                root.previousCpuTotal = total;
                root.previousCpuIdle = idle;

                root.ramPercent = root.clampPercent(parts[2]);
                root.gpuPercent = parts[3] === "" || parts[3] === "--"
                    ? -1 : root.clampPercent(parts[3]);
                root.gpuTemperature = parseInt(parts[4]) || 0;
                root.diskPercent = root.clampPercent(parts[5]);
                root.uptimeText = root.formatUptime(parts[6]);
                root.cpuTemperature = parseInt(parts[7]) || 0;
                root.fan1Rpm = Math.max(0, parseInt(parts[8]) || 0);
                root.fan2Rpm = Math.max(0, parseInt(parts[9]) || 0);
                root.fan3Rpm = Math.max(0, parseInt(parts[10]) || 0);
                root.fan4Rpm = Math.max(0, parseInt(parts[11]) || 0);

                const now = Date.now();
                const rx = Number(parts[12]) || 0;
                const tx = Number(parts[13]) || 0;
                const elapsed = (now - root.previousSampleMs) / 1000;
                if (root.previousSampleMs > 0 && elapsed > 0) {
                    root.downloadKiB = Math.max(0, (rx - root.previousRxBytes) / elapsed / 1024);
                    root.uploadKiB = Math.max(0, (tx - root.previousTxBytes) / elapsed / 1024);
                }
                root.previousRxBytes = rx;
                root.previousTxBytes = tx;
                root.previousSampleMs = now;
                root.interfaceName = parts[14] || "--";
                root.batteryPercent = parts[15] === "" || parts[15] === "--"
                    ? -1 : root.clampPercent(parts[15]);
                root.platformProfile = parts.length > 16 && parts[16] !== "" ? parts[16] : "--";

                if (!root.warmupDone) {
                    root.warmupDone = true;
                    warmupPoll.restart();
                }
            }
        }
    }
}
