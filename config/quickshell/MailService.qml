pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool available: false
    property bool running: false
    property bool profileFound: false
    property bool unreadKnown: false
    property int unreadCount: 0
    property var recent: []
    property string lastError: ""

    readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/mail/thunderbird_mail_status.py"
    readonly property string badgeText: unreadKnown && unreadCount > 0
        ? (unreadCount > 99 ? "99+" : String(unreadCount))
        : ""
    readonly property string statusText: {
        if (!available) return "Thunderbird niet gevonden";
        if (!profileFound) return running ? "Thunderbird actief" : "Geen profiel gevonden";
        if (unreadKnown) return unreadCount === 1 ? "1 ongelezen mail" : unreadCount + " ongelezen mails";
        return running ? "Thunderbird actief" : "Thunderbird";
    }

    function refresh() {
        if (!mailPoller.running) mailPoller.running = true;
    }

    function openThunderbird() {
        Quickshell.execDetached(["thunderbird"]);
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 45000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: mailPoller
        command: ["python3", root.scriptPath]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt === "") return;
                try {
                    let data = JSON.parse(txt);
                    root.available = data.available === true;
                    root.running = data.running === true;
                    root.profileFound = data.profileFound === true;
                    root.unreadKnown = data.unreadKnown === true;
                    root.unreadCount = Number(data.unread || 0);
                    root.recent = Array.isArray(data.recent) ? data.recent : [];
                    root.lastError = "";
                } catch (e) {
                    root.lastError = String(e);
                }
            }
        }
    }
}
