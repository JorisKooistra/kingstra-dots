pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Modules uit het controlecentrum die als mini-tegel in de rail staan,
// zoals je bij macOS een module in de menubalk vastzet. Rechtsklik op een
// pil in het controlecentrum pint vast of los; middelklik op de tegel in
// de rail maakt hem ook los. Opgeslagen als komma-lijst, zodat de keuze een
// herstart overleeft.
Item {
    id: root

    // Volgorde in de rail = volgorde van vastpinnen.
    property var pins: []
    readonly property var known: ["wifi", "bt", "dnd", "power", "media"]
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/kingstra/rail-pins"

    function isPinned(id) {
        return pins.indexOf(id) !== -1;
    }

    function toggle(id) {
        if (known.indexOf(id) === -1) return;
        let next = pins.slice();
        let i = next.indexOf(id);
        if (i >= 0) next.splice(i, 1);
        else next.push(id);
        pins = next;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "sh", stateFile, next.join(",")]);
    }

    function parse(text) {
        let out = [];
        let parts = String(text || "").trim().split(",");
        for (let i = 0; i < parts.length; i++) {
            let id = parts[i].trim();
            if (known.indexOf(id) !== -1 && out.indexOf(id) === -1) out.push(id);
        }
        pins = out;
    }

    FileView {
        path: root.stateFile
        preload: true
        watchChanges: true
        onLoaded: root.parse(text())
        onFileChanged: reload()
    }
}
