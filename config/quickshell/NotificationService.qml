pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Item {
    id: root

    readonly property var notifications: server.trackedNotifications
    readonly property int count: server.trackedNotifications.values.length
    property bool dnd: false
    property string lastCommand: ""

    // Aankomsttijd per melding-id, voor "5 min geleden". Meldingen die een
    // shell-herstart overleven hebben geen tijd en tonen er dan ook geen.
    property var arrivedAt: ({})
    // Tikt elke halve minuut, zodat relatieve tijden meelopen.
    property double now: Date.now()

    // Nieuwe melding die als pop-up getoond mag worden. Niet bij Niet storen:
    // de melding komt dan wel in het archief, alleen stil.
    signal popupRequested(var notification)

    // --- Regels per app, uitstellen, geschiedenis en terughalen ---------------
    // Regel per app-naam: "normaal" (standaard), "stil" (alleen in het
    // centrum, geen pop-up), "nooit" (niet tonen, wel in de geschiedenis) of
    // "altijd" (pop-up, ook bij Niet storen).
    property var rules: ({})
    readonly property var ruleOrder: ["normaal", "stil", "nooit", "altijd"]
    readonly property var ruleLabels: ({ normaal: "Normaal", stil: "Stil", nooit: "Nooit", altijd: "Altijd" })
    readonly property string rulesFile: Quickshell.env("HOME") + "/.config/kingstra/notification-rules.json"
    // Geschiedenis van de laatste 24 uur (tekst, nooit afbeeldingen).
    property var history: []
    readonly property string historyFile: Quickshell.env("HOME") + "/.local/state/kingstra/notification-history.json"
    readonly property int historyHours: 24
    readonly property int historyMax: 400
    // Uitgestelde meldingen: [{ due, app, summary, body, icon, urgency }].
    property var snoozed: []
    readonly property string snoozeFile: Quickshell.env("HOME") + "/.local/state/kingstra/notification-snoozed.json"
    // Laatst weggeklikte melding, voor terughalen.
    property var lastDismissed: null
    // Uitgestelde meldingen tellen niet als weggeklikt.
    property var skipRecall: ({})
    property bool snoozeLoaded: false

    readonly property string dndStateFile: Quickshell.env("HOME") + "/.local/state/kingstra/notification-dnd"
    property bool dndLoaded: false

    onDndChanged: {
        if (!dndLoaded) return;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "sh", dndStateFile, dnd ? "1" : "0"]);
    }

    // Samenvatting voor het vergrendelscherm: alleen app-namen en aantallen,
    // nooit de inhoud. Lock.qml draait als eigen proces en leest dit bestand.
    readonly property string summaryFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/kingstra-notification-summary.json"
    onCountChanged: summaryTimer.restart()
    Timer {
        id: summaryTimer
        interval: 400
        onTriggered: {
            let summary = root.groups().map(g => ({ app: g.app, count: g.items.length }));
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"",
                "sh", root.summaryFile, JSON.stringify({ total: root.count, apps: summary })]);
        }
    }

    function appKey(notification) {
        return String(notification && notification.appName ? notification.appName : "").trim() || "Overig";
    }

    function ruleFor(app) {
        let r = rules[app];
        return ruleOrder.indexOf(r) !== -1 ? r : "normaal";
    }

    function setRule(app, rule) {
        let next = Object.assign({}, rules);
        if (rule === "normaal") delete next[app];
        else next[app] = rule;
        rules = next;
        writeJson(rulesFile, next);
    }

    function cycleRule(app) {
        let i = ruleOrder.indexOf(ruleFor(app));
        setRule(app, ruleOrder[(i + 1) % ruleOrder.length]);
    }

    function writeJson(path, value) {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1.tmp\" && mv -f \"$1.tmp\" \"$1\"",
            "sh", path, JSON.stringify(value)]);
    }

    function plainText(value) {
        return String(value || "")
            .replace(/<br\s*\/?>/gi, "\n")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
            .trim().substring(0, 500);
    }

    function snapshot(notification) {
        if (!notification) return null;
        return {
            app: appKey(notification),
            summary: plainText(notification.summary),
            body: plainText(notification.body),
            icon: String(notification.appIcon || ""),
            urgency: urgencyName(notification),
            at: arrivalTime(notification) || Date.now()
        };
    }

    function pruneHistory(list) {
        let cutoff = Date.now() - historyHours * 3600 * 1000;
        let out = list.filter(h => h && Number(h.at) >= cutoff);
        return out.length > historyMax ? out.slice(out.length - historyMax) : out;
    }

    function remember(snap) {
        if (!snap) return;
        history = pruneHistory(history.concat([snap]));
        historySaveTimer.restart();
    }

    // Nieuwste eerst, gefilterd op app, titel of tekst.
    function searchHistory(query) {
        let q = String(query || "").trim().toLowerCase();
        let list = history.slice().reverse();
        if (q === "") return list;
        return list.filter(h => (h.app + " " + h.summary + " " + h.body).toLowerCase().indexOf(q) !== -1);
    }

    // Opnieuw afleveren via notify-send, zodat de melding weer gewoon
    // binnenkomt (pop-up, centrum, regels). Knoppen van de app gaan daarbij
    // verloren; de tekst blijft.
    function resend(snap) {
        if (!snap) return;
        let cmd = ["notify-send", "-a", String(snap.app || "Melding"), "-u", String(snap.urgency || "normal")];
        if (String(snap.icon || "") !== "") cmd.push("-i", String(snap.icon));
        cmd.push(String(snap.summary || snap.app || "Melding"));
        if (String(snap.body || "") !== "") cmd.push(String(snap.body));
        Quickshell.execDetached(cmd);
    }

    // minutes: aantal minuten, of "morgen" voor morgen 08:00.
    function snooze(notification, minutes) {
        let snap = snapshot(notification);
        if (!snap) return;
        let due;
        if (minutes === "morgen") {
            let d = new Date();
            d.setDate(d.getDate() + 1);
            d.setHours(8, 0, 0, 0);
            due = d.getTime();
        } else {
            due = Date.now() + Math.max(1, Number(minutes) || 30) * 60000;
        }
        snap.due = due;
        let skip = Object.assign({}, skipRecall);
        skip[notification.id] = true;
        skipRecall = skip;
        snoozed = snoozed.concat([snap]);
        writeJson(snoozeFile, snoozed);
    }

    function snoozeLabel(minutes) {
        if (minutes === "morgen") return "morgen 08:00";
        let m = Number(minutes) || 0;
        return m >= 60 ? (m / 60) + " uur" : m + " min";
    }

    function deliverDueSnoozes() {
        if (!snoozeLoaded || snoozed.length === 0) return;
        let t = Date.now();
        let due = snoozed.filter(s => Number(s.due) <= t);
        if (due.length === 0) return;
        snoozed = snoozed.filter(s => Number(s.due) > t);
        writeJson(snoozeFile, snoozed);
        for (let i = 0; i < due.length; i++) resend(due[i]);
    }

    function recall() {
        if (!lastDismissed) return false;
        let snap = lastDismissed;
        lastDismissed = null;
        resend(snap);
        return true;
    }

    function toggleDnd() {
        dnd = !dnd;
    }

    function arrivalTime(notification) {
        if (!notification) return 0;
        return Number(arrivedAt[notification.id] || 0);
    }

    function relativeTime(notification) {
        let t = arrivalTime(notification);
        if (t <= 0) return "";
        let seconds = Math.max(0, Math.floor((now - t) / 1000));
        if (seconds < 60) return "nu";
        let minutes = Math.floor(seconds / 60);
        if (minutes < 60) return minutes + " min geleden";
        let hours = Math.floor(minutes / 60);
        if (hours < 24) return hours + " uur geleden";
        let date = new Date(t);
        return Qt.formatDateTime(date, "d MMM HH:mm");
    }

    // App-icoon als bruikbare image-source, of "" als er geen is.
    function iconSource(notification) {
        if (!notification) return "";
        let icon = String(notification.appIcon || "").trim();
        if (icon === "") return "";
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
        if (icon.startsWith("/")) return "file://" + icon;
        return Quickshell.iconPath(icon, true);
    }

    function invokeDefault(notification) {
        if (!notification) return false;
        let actions = notification.actions || [];
        for (let i = 0; i < actions.length; i++) {
            if (String(actions[i].identifier || "") === "default") {
                actions[i].invoke();
                return true;
            }
        }
        return false;
    }

    // Groepen per app, nieuwste eerst: [{ app, items: [notification...] }].
    function groups() {
        let list = server.trackedNotifications.values.slice();
        list.sort((a, b) => arrivalTime(b) - arrivalTime(a) || Number(b.id) - Number(a.id));
        let byApp = {};
        let order = [];
        for (let i = 0; i < list.length; i++) {
            let app = String(list[i].appName || "").trim() || "Overig";
            if (!byApp[app]) {
                byApp[app] = [];
                order.push(app);
            }
            byApp[app].push(list[i]);
        }
        return order.map(app => ({ app: app, items: byApp[app] }));
    }

    function dismissApp(appName) {
        let list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) {
            let app = String(list[i].appName || "").trim() || "Overig";
            if (app === appName) list[i].dismiss();
        }
    }

    function clearAll() {
        let list = server.trackedNotifications.values.slice();
        for (let i = 0; i < list.length; i++) {
            list[i].dismiss();
        }
    }

    function dismiss(notification) {
        if (notification) notification.dismiss();
    }

    function expire(notification) {
        if (notification) notification.expire();
    }

    function urgencyName(notification) {
        if (!notification) return "normal";
        if (notification.urgency === NotificationUrgency.Critical) return "critical";
        if (notification.urgency === NotificationUrgency.Low) return "low";
        return "normal";
    }

    function handleCommand(rawCommand) {
        let command = String(rawCommand || "").trim();
        if (command === "" || command === lastCommand) return;
        lastCommand = command;

        let action = command.split(":")[0];
        if (action === "clear") clearAll();
        if (action === "dnd-toggle") toggleDnd();
        if (action === "dnd-on") dnd = true;
        if (action === "dnd-off") dnd = false;
        if (action === "recall") recall();
    }

    Component.onCompleted: {
        Quickshell.execDetached(["sh", "-c", "touch /tmp/qs_notifications_command"]);
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true
        inlineReplySupported: true

        onNotification: notification => {
            let rule = root.ruleFor(root.appKey(notification));
            let snap = root.snapshot(notification);
            snap.at = Date.now();
            root.remember(snap);
            // "Nooit": niet tonen en niet bewaren; alleen in de geschiedenis.
            if (rule === "nooit") return;
            // Niet storen bewaart de melding stil in het archief, in plaats
            // van hem weg te gooien. Kritieke meldingen komen altijd door.
            notification.tracked = true;
            let times = Object.assign({}, root.arrivedAt);
            times[notification.id] = Date.now();
            root.arrivedAt = times;
            try {
                notification.closed.connect(reason => {
                    if (reason === NotificationCloseReason.Dismissed && !root.skipRecall[notification.id])
                        root.lastDismissed = snap;
                });
            } catch (e) {}
            if (rule === "stil") return;
            if (rule === "altijd" || !root.dnd || notification.urgency === NotificationUrgency.Critical)
                root.popupRequested(notification);
        }
    }

    FileView {
        path: root.rulesFile
        preload: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            try {
                let data = JSON.parse(text() || "{}");
                root.rules = (data && typeof data === "object" && !Array.isArray(data)) ? data : ({});
            } catch (e) { root.rules = ({}); }
        }
        onFileChanged: reload()
    }

    FileView {
        path: root.historyFile
        preload: true
        printErrors: false
        onLoaded: {
            try {
                let data = JSON.parse(text() || "[]");
                // Meldingen die al binnenkwamen voor het laden blijven staan.
                if (Array.isArray(data)) root.history = root.pruneHistory(data.concat(root.history));
            } catch (e) {}
        }
    }

    Timer {
        id: historySaveTimer
        interval: 2000
        onTriggered: root.writeJson(root.historyFile, root.pruneHistory(root.history))
    }

    FileView {
        path: root.snoozeFile
        preload: true
        printErrors: false
        onLoaded: {
            try {
                let data = JSON.parse(text() || "[]");
                if (Array.isArray(data)) root.snoozed = data.concat(root.snoozed);
            } catch (e) {}
            root.snoozeLoaded = true;
            root.deliverDueSnoozes();
        }
        onLoadFailed: root.snoozeLoaded = true
    }

    Timer {
        interval: 20000
        running: root.snoozed.length > 0
        repeat: true
        onTriggered: root.deliverDueSnoozes()
    }

    FileView {
        path: root.dndStateFile
        preload: true
        onLoaded: {
            root.dnd = String(text() || "").trim() === "1";
            root.dndLoaded = true;
        }
        onLoadFailed: root.dndLoaded = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    FileView {
        path: "/tmp/qs_notifications_command"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.handleCommand(__text || "")
    }

    Process {
        id: commandPoller
        command: ["sh", "-c", "cat /tmp/qs_notifications_command 2>/dev/null || true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.handleCommand(this.text || "")
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: if (!commandPoller.running) commandPoller.running = true
    }
}
