pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isTouchscreen: false
    property int touchscreenCount: 0
    property string source: "none"
    property real uiScale: 1.0
    property real windowScale: 1.0
    property real hitTargetScale: 1.0
    property real scrollDragScale: 1.0
    property string rawJson: ""

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    function parseNum(value, fallback) {
        let num = Number(value);
        return isNaN(num) ? fallback : num;
    }

    function applyProfile(data) {
        let count = parseInt(data.touchscreen_count);
        if (isNaN(count) || count < 0) count = 0;

        let touch = !!data.is_touchscreen || count > 0;
        root.isTouchscreen = touch;
        root.touchscreenCount = count;
        root.source = String(data.source || "none");
        root.uiScale = root.clamp(parseNum(data.ui_scale, touch ? 1.10 : 1.0), 1.0, 1.35);
        root.windowScale = root.clamp(parseNum(data.window_scale, touch ? 1.08 : 1.0), 1.0, 1.30);
        root.hitTargetScale = root.clamp(parseNum(data.hit_target_scale, touch ? 1.22 : 1.0), 1.0, 1.6);
        root.scrollDragScale = root.clamp(parseNum(data.scroll_drag_scale, touch ? 1.20 : 1.0), 1.0, 2.0);
    }

    Process {
        id: touchProfileProc
        command: [
            "bash", "-lc",
            "if command -v kingstra-touch-detect >/dev/null 2>&1; then " +
            "  kingstra-touch-detect --json; " +
            "elif [ -x \"$HOME/.local/bin/kingstra-touch-detect\" ]; then " +
            "  \"$HOME/.local/bin/kingstra-touch-detect\" --json; " +
            "elif [ -x \"$HOME/.config/shared/scripts/kingstra-touch-detect\" ]; then " +
            "  \"$HOME/.config/shared/scripts/kingstra-touch-detect\" --json; " +
            "else " +
            "  echo '{\"is_touchscreen\":false,\"touchscreen_count\":0,\"source\":\"none\",\"ui_scale\":1.0,\"window_scale\":1.0,\"hit_target_scale\":1.0,\"scroll_drag_scale\":1.0}'; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "" || txt === root.rawJson) return;
                root.rawJson = txt;
                try {
                    let data = JSON.parse(txt);
                    root.applyProfile(data || {});
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: touchProfileProc.running = true
    }
}
