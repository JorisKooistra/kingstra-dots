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
    property string selectedAccount: ""
    property var accounts: []
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
    readonly property var filteredRecent: filterRecent()
    readonly property var filterOptions: buildFilterOptions()

    function refresh() {
        if (!mailPoller.running) mailPoller.running = true;
    }

    function accountExists(address) {
        let needle = String(address || "").toLowerCase();
        if (needle === "") return true;
        for (let i = 0; i < accounts.length; i++) {
            if (String(accounts[i].address || "").toLowerCase() === needle) return true;
        }
        return false;
    }

    function buildFilterOptions() {
        let options = [{
            "address": "",
            "label": "Alles",
            "name": "",
            "count": recent.length,
            "known": true
        }];
        for (let i = 0; i < accounts.length; i++) {
            let account = accounts[i] || {};
            let address = String(account.address || "");
            if (address === "") continue;
            options.push({
                "address": address,
                "label": String(account.label || address),
                "name": String(account.name || ""),
                "count": Number(account.count || 0),
                "known": account.known === true
            });
        }
        return options;
    }

    function filterRecent() {
        let needle = String(selectedAccount || "").toLowerCase();
        if (needle === "") return recent;
        let filtered = [];
        for (let i = 0; i < recent.length; i++) {
            let item = recent[i] || {};
            if (String(item.account || "").toLowerCase() === needle) {
                filtered.push(item);
                continue;
            }
            let recipients = Array.isArray(item.recipients) ? item.recipients : [];
            for (let j = 0; j < recipients.length; j++) {
                if (String(recipients[j] || "").toLowerCase() === needle) {
                    filtered.push(item);
                    break;
                }
            }
        }
        return filtered;
    }

    function selectAccount(address) {
        selectedAccount = String(address || "");
    }

    function openThunderbird() {
        Quickshell.execDetached(["thunderbird"]);
    }

    Component.onCompleted: refresh()
    onAccountsChanged: {
        if (!accountExists(selectedAccount)) selectedAccount = "";
    }

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
                    root.accounts = Array.isArray(data.accounts) ? data.accounts : [];
                    root.recent = Array.isArray(data.recent) ? data.recent : [];
                    root.lastError = "";
                } catch (e) {
                    root.lastError = String(e);
                }
            }
        }
    }
}
