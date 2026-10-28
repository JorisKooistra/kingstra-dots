pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var subscribers: []
    property var gpus: []
    property string errorText: ""
    function request(owner, wanted) {
        let next = subscribers.filter(item => item !== owner);
        if (wanted) next.push(owner);
        subscribers = next;
        if (wanted && !reader.running) reader.running = true;
    }
    Process {
        id: reader
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/gpu-metrics.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.gpus = JSON.parse(this.text).gpus || []; root.errorText = ""; }
                catch (e) { root.errorText = "GPU-informatie niet beschikbaar"; }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = "GPU-informatie niet beschikbaar" }
    }
    Timer {
        interval: 5000; repeat: true; running: root.subscribers.length > 0
        onTriggered: if (!reader.running) reader.running = true
    }
}
