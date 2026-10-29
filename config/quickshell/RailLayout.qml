pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Indeling van de rail, per thema: welke onderdelen in welke volgorde staan,
// wat op de tweede rail aan de overkant staat, hoeveel werkruimtes de rail
// toont en welke eigen apps erbij horen. Zonder opgeslagen keuze geldt de
// vaste volgorde van vroeger, zodat er niets verschuift tot je zelf iets
// aanpast. Zichtbaarheid per scherm en mode (ScreenProfiles: modules, Meer,
// extra knoppen) werkt daar gewoon bovenop.
Item {
    id: root

    property var layoutState: ({version: 1, themes: {}, apps: []})
    property string errorText: ""
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/kingstra/rail-layout.json"
    readonly property string helper: Quickshell.env("HOME") + "/.config/quickshell/settings/rail-layout.py"

    // Vaste onderdelen; "gap" (kleine adem) en "fill" (duwt de rest naar
    // onderen) mogen vaker voorkomen. Houd gelijk met rail-layout.py.
    readonly property var known: ["launcher", "workspaces", "specials", "overview", "notifications", "system", "updates",
        "games", "pins", "more", "tray", "audio", "status", "clock", "power", "settings"]
    readonly property var repeatable: ["gap", "fill"]
    readonly property var defaultMain: ["launcher", "workspaces", "specials", "overview", "gap",
        "notifications", "system", "updates", "games", "pins", "more", "fill",
        "tray", "audio", "status", "clock", "power", "settings"]
    readonly property var themes: [{id: "organic", title: "Organic"}, {id: "neon", title: "Neon"},
        {id: "paper", title: "Paper"}, {id: "mono", title: "Mono"}, {id: "mono-accent", title: "Mono accent"}]

    readonly property var meta: ({
        launcher: {title: "Launcher", icon: "󰣇"},
        workspaces: {title: "Werkruimtes", icon: "󰕰"},
        specials: {title: "Kladblokken", icon: "󰆍"},
        overview: {title: "Uitzoomen", icon: "󰊢"},
        notifications: {title: "Meldingen", icon: "󰂚"},
        system: {title: "Systeem", icon: "󰍛"},
        updates: {title: "Updates", icon: "󰚰"},
        games: {title: "Games", icon: "󰊴"},
        pins: {title: "Extra knoppen", icon: "󰐃"},
        more: {title: "Meer", icon: "󰇘"},
        tray: {title: "Systeemvak", icon: "󰀻"},
        audio: {title: "Geluid & media", icon: "󰕾"},
        status: {title: "Netwerk & batterij", icon: "󰤨"},
        clock: {title: "Klok", icon: "󰥔"},
        power: {title: "Afsluitmenu", icon: "󰐥"},
        settings: {title: "Instellingen", icon: "󰒓"},
        gap: {title: "Kleine ruimte", icon: "󰇜"},
        fill: {title: "Duw naar onder", icon: "󰁅"}
    })

    readonly property string theme: ThemeConfig.theme
    readonly property var apps: Array.isArray(layoutState.apps) ? layoutState.apps : []
    readonly property var current: resolve(theme)
    readonly property var main: current.main
    readonly property var second: current.second
    readonly property int workspaceCount: current.workspaces
    // "theme" volgt het thema, "on"/"off" zet de rail in dit thema aan of uit.
    readonly property string railChoice: current.rail

    function app(id) {
        for (let a of apps) if (a && a.id === id) return a;
        return null;
    }
    function isRepeatable(id) {
        return repeatable.indexOf(id) !== -1;
    }
    function itemTitle(id) {
        if (String(id).indexOf("app:") === 0) {
            let a = app(id.substring(4));
            return a ? a.name : id.substring(4);
        }
        return meta[id] ? meta[id].title : id;
    }
    function itemIcon(id) {
        if (String(id).indexOf("app:") === 0) {
            let a = app(id.substring(4));
            return a && a.icon ? a.icon : "󰀻";
        }
        return meta[id] ? meta[id].icon : "";
    }

    function saved(themeId) {
        let all = layoutState.themes || {};
        return all[themeId] || {};
    }
    function hasSaved(themeId) {
        let all = layoutState.themes || {};
        return all[themeId] !== undefined;
    }

    // Maakt een opgeslagen indeling bruikbaar: onbekende of dubbele
    // onderdelen vallen weg, en een onderdeel dat er later bij is gekomen
    // (en dus nergens staat) komt onderaan de hoofdrail, zodat een update
    // nooit stilletjes een knop laat verdwijnen.
    function resolve(themeId) {
        let s = saved(themeId);
        let seen = ({});
        let appIds = ({});
        for (let a of apps) if (a && a.id) appIds[a.id] = true;
        function clean(list) {
            let out = [];
            if (!Array.isArray(list)) return out;
            for (let raw of list) {
                let id = String(raw);
                if (isRepeatable(id)) { out.push(id); continue; }
                let ok = id.indexOf("app:") === 0 ? appIds[id.substring(4)] === true : known.indexOf(id) !== -1;
                if (!ok || seen[id]) continue;
                seen[id] = true;
                out.push(id);
            }
            return out;
        }
        let main = clean(Array.isArray(s.main) ? s.main : defaultMain);
        let second = clean(s.second);
        let hidden = clean(s.hidden);
        for (let id of known) {
            if (!seen[id]) { seen[id] = true; main.push(id); }
        }
        let count = Number(s.workspaces);
        return {
            main: main, second: second, hidden: hidden,
            workspaces: count >= 1 && count <= 10 ? Math.round(count) : 8,
            rail: s.rail === "on" || s.rail === "off" ? s.rail : "theme"
        };
    }

    // Alles wat nergens staat: verborgen onderdelen en nog niet geplaatste apps.
    function pool(themeId) {
        let r = resolve(themeId);
        let out = r.hidden.slice();
        for (let a of apps) {
            let id = "app:" + a.id;
            if (r.main.indexOf(id) === -1 && r.second.indexOf(id) === -1 && out.indexOf(id) === -1) out.push(id);
        }
        return out;
    }

    function _run(args) {
        writer.queue = writer.queue.concat([args]);
        writeTimer.start();
    }

    // Direct lokaal bijwerken zodat slepen meteen klopt; het script bewaart
    // en het bestand bevestigt het daarna.
    function save(themeId, layout) {
        let next = JSON.parse(JSON.stringify(layoutState));
        next.themes = next.themes || {};
        let entry = {main: layout.main, second: layout.second, hidden: layout.hidden || [],
            workspaces: layout.workspaces};
        if (layout.rail === "on" || layout.rail === "off") entry.rail = layout.rail;
        next.themes[themeId] = entry;
        layoutState = next;
        _run(["set", themeId, JSON.stringify(entry)]);
    }
    function change(themeId, changes) {
        let r = resolve(themeId);
        for (let key in changes) r[key] = changes[key];
        save(themeId, r);
    }
    function reset(themeId) {
        let next = JSON.parse(JSON.stringify(layoutState));
        if (next.themes) delete next.themes[themeId];
        layoutState = next;
        _run(["reset", themeId]);
    }
    function saveApps(list) {
        let next = JSON.parse(JSON.stringify(layoutState));
        next.apps = list;
        layoutState = next;
        _run(["apps", JSON.stringify(list)]);
    }

    function launch(id) {
        let a = app(String(id).replace(/^app:/, ""));
        if (!a || !a.command) return;
        // Via de shell, zodat argumenten en ~ werken zoals in een terminal.
        Quickshell.execDetached(["bash", "-lc", "setsid bash -lc \"$1\" >/dev/null 2>&1 &", "bash", a.command]);
    }

    function accept(raw) {
        try {
            let next = JSON.parse(String(raw || "").trim() || "{}");
            if (!next || typeof next !== "object") throw new Error("leeg");
            next.themes = next.themes && typeof next.themes === "object" ? next.themes : {};
            next.apps = Array.isArray(next.apps) ? next.apps : [];
            if (JSON.stringify(next) !== JSON.stringify(layoutState)) layoutState = next;
            errorText = "";
        } catch (e) {
            // Een half geschreven of kapot bestand laat de vorige indeling staan.
        }
    }

    FileView {
        id: fileView
        path: root.stateFile
        preload: true
        watchChanges: true
        onLoaded: if (!writer.running && writer.queue.length === 0) root.accept(text())
        onFileChanged: reload()
    }
    // FileView mist op Quickshell 0.3.0 soms een write van een ander proces
    // (de instellingen-app); een rustige poll vangt dat op.
    Timer {
        interval: 2000; repeat: true; running: true
        onTriggered: if (!writer.running && writer.queue.length === 0) fileView.reload()
    }

    Process {
        id: writer
        property var queue: []
        stdout: StdioCollector { onStreamFinished: if (this.text.trim()) root.accept(this.text) }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim()) root.errorText = this.text.trim() }
    }
    Timer {
        id: writeTimer
        interval: 40; repeat: true
        onTriggered: {
            if (writer.running) return;
            if (!writer.queue.length) { stop(); return; }
            let next = writer.queue.slice(), args = next.shift();
            writer.queue = next;
            writer.command = ["python3", root.helper].concat(args);
            writer.running = true;
        }
    }
}
