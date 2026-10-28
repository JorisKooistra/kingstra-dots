pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var state: ({profiles: {screens: {}}, monitors: [], presets: {}, fallback: {name: "office"}})
    property string errorText: ""
    property var commands: []
    readonly property bool busy: writer.running || commands.length > 0
    readonly property var monitors: state.monitors || []
    readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/settings/screen-profile.py"

    function monitor(name) {
        for (let m of monitors) if (m.name === name) return m;
        return null;
    }
    function profile(name, fallbackName) {
        let m = monitor(name);
        let saved = m ? ((state.profiles.screens || {})[m.key] || {}) : {};
        let mode = saved.mode || fallbackName || state.fallback.name || "office";
        let modes = saved.modes || {};
        let values = modes[mode] || {};
        return {mode: mode, inherited: !saved.mode, rail: values.rail || {},
            nowPlaying: values.nowPlaying || "auto",
            desktopMedia: values.desktopMedia !== undefined ? values.desktopMedia : (!saved.mode || mode === "media"),
            playerStyle: values.playerStyle || "theme",
            wallpaperDrift: saved.wallpaperDrift !== false};
    }
    function resolveMode(name, fallback) {
        let p = profile(name, fallback.name);
        let base = state.presets[p.mode] || fallback;
        let modules = p.rail.modules !== undefined ? p.rail.modules : base.modules;
        return {name: p.mode, modules: modules || [], explicitModules: p.rail.modules !== undefined,
            bar_autohide: p.rail.autohide !== undefined ? p.rail.autohide : base.bar_autohide === true};
    }
    function musicVisible(name) {
        let p = profile(name);
        if (p.nowPlaying === "show") return true;
        if (p.nowPlaying === "hide") return false;
        let key = state.profiles.mediaScreen || "";
        let available = false;
        for (let m of monitors) if (m.key === key) available = true;
        if (!available) {
            let preferred = monitors.filter(m => profile(m.name).mode === "media");
            let candidates = preferred.length ? preferred : monitors;
            key = candidates.length ? candidates[0].key : "";
        }
        let m = monitor(name);
        return m !== null && m.key === key;
    }
    function action(args) {
        commands = commands.concat([args]);
        actionTimer.start();
    }
    // Extra railknoppen: een scherm met eigen keuzes gebruikt die lijst,
    // anders de gedeelde lijst van RailPins. Vastpinnen vanuit het
    // controlecentrum loopt hier ook langs, zodat het op elk scherm werkt.
    function pinsFor(name) {
        let p = profile(name);
        return p.rail.pins !== undefined ? p.rail.pins : RailPins.pins;
    }
    function isPinnedOn(name, id) {
        return pinsFor(name).indexOf(id) !== -1;
    }
    function togglePinOn(name, id) {
        let p = profile(name);
        if (name && p.rail.pins !== undefined) togglePin(name, id, p.rail.pins);
        else RailPins.toggle(id);
    }
    function togglePin(name, id, current) {
        let list = current.slice();
        let i = list.indexOf(id);
        if (i >= 0) list.splice(i, 1); else list.push(id);
        action(["set", name, "rail.pins", JSON.stringify(list)]);
    }
    function accept(raw) {
        try {
            let next = JSON.parse(raw);
            if (JSON.stringify(next) !== JSON.stringify(state)) state = next;
            errorText = "";
        } catch (e) { errorText = "Schermprofielen konden niet worden gelezen"; }
    }
    Process {
        id: reader
        command: ["python3", root.helper, "status"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.accept(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Process {
        id: writer
        stdout: StdioCollector { onStreamFinished: root.accept(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Timer {
        id: actionTimer
        interval: 40; repeat: true
        onTriggered: {
            if (writer.running) return;
            if (!root.commands.length) { stop(); return; }
            let next = root.commands.slice(), args = next.shift();
            root.commands = next;
            writer.command = ["python3", root.helper].concat(args);
            writer.running = true;
        }
    }
    Timer { interval: 2000; repeat: true; running: true; onTriggered: if (!reader.running && !root.busy) reader.running = true }
}
