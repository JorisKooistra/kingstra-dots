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

    readonly property string dndStateFile: Quickshell.env("HOME") + "/.local/state/kingstra/notification-dnd"
    property bool dndLoaded: false

    onDndChanged: {
        if (!dndLoaded) return;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname \"$1\")\" && printf '%s\\n' \"$2\" > \"$1\"",
            "sh", dndStateFile, dnd ? "1" : "0"]);
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
            // Niet storen bewaart de melding stil in het archief, in plaats
            // van hem weg te gooien. Kritieke meldingen komen altijd door.
            notification.tracked = true;
            let times = Object.assign({}, root.arrivedAt);
            times[notification.id] = Date.now();
            root.arrivedAt = times;
            if (!root.dnd || notification.urgency === NotificationUrgency.Critical)
                root.popupRequested(notification);
        }
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
