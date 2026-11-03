pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// NightLight — stand van het nachtlicht (kingstra-nightlight + hyprsunset).
// Leest $XDG_RUNTIME_DIR/kingstra-nightlight.json, dat de daemon bijhoudt.
Item {
    id: root

    readonly property string statusFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kingstra-nightlight.json"
    readonly property string command: Quickshell.env("HOME") + "/.local/bin/kingstra-nightlight"

    property bool available: false
    property bool nightOn: false
    property int temperature: 6500
    property int warmth: 4000
    property string manual: ""
    property bool scheduled: true
    property string startTime: "21:00"
    property string endTime: "07:00"

    readonly property string subtitle: {
        if (!available) return "Niet geïnstalleerd";
        if (manual === "on") return "Aan tot " + endTime;
        if (manual === "off") return scheduled ? "Uit tot " + startTime : "Uit";
        if (nightOn) return "Aan tot " + endTime;
        return scheduled ? "Vanaf " + startTime : "Uit";
    }

    function parse(raw) {
        try {
            let data = JSON.parse(raw || "{}");
            root.available = data.temperature !== undefined;
            root.nightOn = data.active === true;
            root.temperature = Number(data.temperature) || 6500;
            root.warmth = Number(data.warmth) || 4000;
            root.manual = String(data.override || "");
            root.scheduled = data.schedule !== false;
            root.startTime = String(data.start || "21:00");
            root.endTime = String(data.end || "07:00");
        } catch (e) {
            root.available = false;
        }
    }

    function toggle() {
        // Meteen tonen; de daemon bevestigt via het statusbestand.
        root.nightOn = !root.nightOn;
        Quickshell.execDetached([root.command, "toggle"]);
    }

    function followSchedule() { Quickshell.execDetached([root.command, "auto"]); }
    function setScheduled(on) { Quickshell.execDetached([root.command, "schedule", on ? "on" : "off"]); }

    FileView {
        id: statusView
        path: root.statusFile
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }

    // Het statusbestand verschijnt pas als de daemon draait; tot dan af en
    // toe opnieuw kijken.
    Timer {
        interval: 15000
        running: !root.available
        repeat: true
        onTriggered: statusView.reload()
    }
}
