import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Eén gedeelde bron van venstergeometrie voor alle schermen. Het helperproces
// pollt Hyprland en duwt alleen een regel als er iets veranderd is, dus de
// shell doet geen polwerk en heeft geen timer nodig.
Scope {
    id: root

    property bool active: false
    property var monitors: []
    property var clients: []

    readonly property string helperPath: Quickshell.env("HOME")
        + "/.config/quickshell/shellsurface/window-frames.py"

    Process {
        running: root.active
        command: ["python3", root.helperPath]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                let payload;
                try {
                    payload = JSON.parse(data);
                } catch (e) {
                    return;
                }
                root.monitors = payload.m || [];
                root.clients = payload.c || [];
            }
        }
    }

    onActiveChanged: {
        if (!active) {
            monitors = [];
            clients = [];
        }
    }
}
