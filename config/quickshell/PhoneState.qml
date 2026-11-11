pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PhoneState — korte stand van de gekoppelde telefoon voor de barknoppen
// (rail, statusstrip, Matte-balk). Eén poll voor alle schermen, elke 20 s,
// via `phone.py bar`: leest alleen wat KDE Connect op de pc al weet en start
// de dienst niet (geen autostart), dus het kost de telefoon niets.
Item {
    id: root

    property bool present: false
    property bool reachable: false
    property string name: ""
    property int battery: -1
    property bool charging: false
    property int notifications: 0

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/phone.py"
    readonly property string icon: "󰄜"
    readonly property string batteryText: reachable && battery >= 0 ? battery + "%" : ""
    readonly property string tooltip: {
        if (!present) return "Telefoon";
        let label = name !== "" ? name : "Telefoon";
        if (!reachable) return label + " · niet bereikbaar · klik om te zoeken";
        let parts = [label];
        if (battery >= 0) parts.push(battery + "%" + (charging ? " (laadt op)" : ""));
        if (notifications > 0) parts.push(notifications === 1 ? "1 melding" : notifications + " meldingen");
        return parts.join(" · ");
    }

    function refresh() { if (!proc.running) proc.running = true; }

    Process {
        id: proc
        command: ["python3", root.script, "bar"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim() || "{}");
                    root.present = !!d.present;
                    root.reachable = !!d.reachable;
                    root.name = String(d.name || "");
                    root.battery = typeof d.battery === "number" ? d.battery : -1;
                    root.charging = !!d.charging;
                    root.notifications = typeof d.notifications === "number" ? d.notifications : 0;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}
