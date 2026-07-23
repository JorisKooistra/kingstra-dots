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

    function toggleDnd() {
        dnd = !dnd;
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
            if (root.dnd && notification.urgency !== NotificationUrgency.Critical) {
                notification.dismiss();
                return;
            }
            notification.tracked = true;
        }
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
