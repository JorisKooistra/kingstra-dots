import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import ".."

// Dashboard dat uit de bovenrand groeit. Opzet overgenomen van Caelestia's
// dash-tab: informatie die je in één oogopslag wilt zien (tijd, maand,
// systeembelasting, wat er speelt) in plaats van knoppen die alleen andere
// panelen openen — die staan al in de rail, dus die waren hier dubbelop.
// Drie tabbladen (hover of klik): Overzicht, Vandaag (agenda, meldingen,
// post, updates) en Systeem (processen, netwerk, sessie). Pijltjes in een
// kaart openen het volledige paneel via de PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }

    readonly property int pad: 14
    readonly property int cardRadius: Math.max(12, ThemeConfig.styleWidgetRadius)
    readonly property color cardColor: mocha.shellRaisedFill
    readonly property color cardBorder: mocha.shellOutline

    property var now: new Date()
    // Expliciete locale: de sessie draait op een C/en_US-locale, waardoor
    // dag- en maandnamen anders in het Engels tussen de Nederlandse labels
    // zouden staan.
    readonly property var nl: Qt.locale("nl_NL")
    readonly property string timeText: Qt.formatDateTime(now, "HH:mm")
    readonly property string dayName: now.toLocaleDateString(nl, "dddd")
    readonly property string dateText: now.toLocaleDateString(nl, "d MMMM yyyy")

    property int cpuPercent: 0
    property int ramPercent: 0
    property int diskPercent: 0
    property string cpuTemp: "--"

    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasMedia: activePlayer !== null
                                     && String(activePlayer.trackTitle || "").trim() !== ""

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: metricsPoller.running = true
    }

    Process {
        id: metricsPoller
        command: ["bash", "-lc",
            "cpu=$(awk '/^cpu /{u=$2+$4; t=$2+$3+$4+$5; if(seen){printf \"%.0f\",(u-prevu)*100/(t-prevt); exit} prevt=t; prevu=u; seen=1}' <(cat /proc/stat; sleep 0.25; cat /proc/stat)); " +
            "ram=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf \"%.0f\",((t-a)*100)/t}' /proc/meminfo); " +
            "disk=$(df -P / | awk 'NR==2{gsub(/%/,\"\",$5); print $5}'); " +
            "cput=$(sensors 2>/dev/null | awk '/^(Core 0|Tdie|Package id 0|temp1):/ {gsub(/[^0-9.]/,\" \",$2); if($2+0>0){printf \"%.0f\",$2; exit}}'); " +
            "if [ -z \"$cput\" ]; then cput=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk 'NF{printf \"%.0f\", $1/1000}'); fi; " +
            "printf '%s|%s|%s|%s\\n' \"${cpu:-0}\" \"${ram:-0}\" \"${disk:-0}\" \"${cput:---}\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.trim().split("|");
                if (parts.length < 4) return;
                root.cpuPercent = root.clampPercent(parts[0]);
                root.ramPercent = root.clampPercent(parts[1]);
                root.diskPercent = root.clampPercent(parts[2]);
                root.cpuTemp = (parts[3] === "" || parts[3] === "--") ? "--" : parts[3] + "°";
            }
        }
    }

    // --- Weer en eerstvolgende afspraak --------------------------------------
    // Het weer stond in de oude bar en ontbrak sinds de rail; de afspraak komt
    // uit dezelfde bronnen als het agendapaneel (lokaal + Thunderbird).
    property string weatherIcon: ""
    property string weatherTemp: ""
    property var localEvents: []
    property var thunderbirdEvents: []
    readonly property var nextEvent: {
        let all = localEvents.concat(thunderbirdEvents);
        let todayKey = Qt.formatDate(now, "yyyy-MM-dd");
        let nowTime = Qt.formatTime(now, "HH:mm");
        let best = null;
        for (let i = 0; i < all.length; i++) {
            let ev = all[i];
            if (!ev || !ev.dateKey) continue;
            let timeKey = ev.allDay ? "00:00" : String(ev.timeRaw || ev.time || "00:00");
            if (ev.dateKey < todayKey) continue;
            if (ev.dateKey === todayKey && !ev.allDay && timeKey < nowTime) continue;
            let sortKey = ev.dateKey + " " + timeKey;
            if (!best || sortKey < best.sortKey) best = { sortKey: sortKey, ev: ev };
        }
        return best ? best.ev : null;
    }
    readonly property string nextEventText: {
        let ev = nextEvent;
        if (!ev) return "Geen afspraken gepland";
        let todayKey = Qt.formatDate(now, "yyyy-MM-dd");
        let tomorrowKey = Qt.formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1), "yyyy-MM-dd");
        let when = ev.dateKey === todayKey ? "" : (ev.dateKey === tomorrowKey ? "Morgen " : String(ev.day || ev.dateKey) + " ");
        let time = ev.allDay ? "hele dag" : String(ev.time || "");
        return when + time + " · " + String(ev.title || "");
    }

    function parseEvents(raw) {
        try {
            let data = JSON.parse(String(raw || "{}"));
            return Array.isArray(data.events) ? data.events : [];
        } catch (e) {
            return [];
        }
    }

    Process {
        id: weatherPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/calendar/weather.sh", "--current-summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n");
                if (lines.length < 2) return;
                let temp = lines[1].trim();
                // Zonder API-sleutel levert weather.sh dummydata met 0.0°;
                // dan tonen we liever niets dan een verzonnen temperatuur.
                if (/^0\.0\D*$/.test(temp)) {
                    root.weatherIcon = "";
                    root.weatherTemp = "";
                    return;
                }
                root.weatherIcon = lines[0].trim();
                root.weatherTemp = temp.replace(/\.\d+/, "");
            }
        }
    }

    Process {
        id: localAgendaPoller
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/calendar/agenda_events.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: root.localEvents = root.parseEvents(this.text)
        }
    }

    Process {
        id: thunderbirdPoller
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/calendar/thunderbird_calendar_status.py"]
        stdout: StdioCollector {
            onStreamFinished: root.thunderbirdEvents = root.parseEvents(this.text)
        }
    }

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!weatherPoller.running) weatherPoller.running = true;
            if (!localAgendaPoller.running) localAgendaPoller.running = true;
            if (!thunderbirdPoller.running) thunderbirdPoller.running = true;
        }
    }

    // --- Tabbladen ------------------------------------------------------------
    property int tab: 0
    // PanelHost luistert hiernaar, zodat een pijltje hier het volledige
    // paneel opent met dezelfde blob-overgang als een railklik.
    signal panelSwitchRequested(string entryId)

    // --- Vandaag: agenda, meldingen, post en updates -------------------------
    readonly property var upcomingEvents: {
        let all = localEvents.concat(thunderbirdEvents);
        let todayKey = Qt.formatDate(now, "yyyy-MM-dd");
        let nowTime = Qt.formatTime(now, "HH:mm");
        let out = [];
        for (let i = 0; i < all.length; i++) {
            let ev = all[i];
            if (!ev || !ev.dateKey) continue;
            let timeKey = ev.allDay ? "00:00" : String(ev.timeRaw || ev.time || "00:00");
            if (ev.dateKey < todayKey) continue;
            if (ev.dateKey === todayKey && !ev.allDay && timeKey < nowTime) continue;
            out.push({ sortKey: ev.dateKey + " " + timeKey, ev: ev });
        }
        out.sort((x, y) => x.sortKey < y.sortKey ? -1 : (x.sortKey > y.sortKey ? 1 : 0));
        return out.slice(0, 5).map(item => item.ev);
    }
    function eventWhen(ev) {
        let todayKey = Qt.formatDate(now, "yyyy-MM-dd");
        let tomorrowKey = Qt.formatDate(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1), "yyyy-MM-dd");
        let day = ev.dateKey === todayKey ? "Vandaag" : (ev.dateKey === tomorrowKey ? "Morgen" : String(ev.day || ev.dateKey));
        return day + " · " + (ev.allDay ? "hele dag" : String(ev.time || ""));
    }
    readonly property var latestNotifications: {
        let list = NotificationService.notifications ? NotificationService.notifications.values : [];
        let out = [];
        for (let i = list.length - 1; i >= 0 && out.length < 3; i--) out.push(list[i]);
        return out;
    }

    property int updateCount: -1
    property int packageUpdateCount: 0
    property int flatpakUpdateCount: 0
    property int dotfilesCommitCount: 0

    Process {
        id: updatesPoller
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/package_updates.sh", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let state = JSON.parse(this.text.trim());
                    root.updateCount = Math.max(0, parseInt(state.total) || 0);
                    root.packageUpdateCount = Math.max(0, parseInt(state.packages) || 0);
                    root.flatpakUpdateCount = Math.max(0, parseInt(state.flatpak) || 0);
                    root.dotfilesCommitCount = Math.max(0, parseInt(state.dotfiles_commits) || 0);
                } catch (e) {
                    let total = parseInt(this.text);
                    if (!isNaN(total)) root.updateCount = Math.max(0, total);
                }
            }
        }
    }

    function openUpdatesTerminal() {
        let script = Quickshell.env("HOME") + "/.config/quickshell/package_upgrade.sh";
        Quickshell.execDetached(["kitty", "--hold", "bash", script]);
    }

    // --- Systeem: processen, netwerk, sessie ---------------------------------
    property var topProcesses: []
    property real netRxRate: 0
    property real netTxRate: 0
    property real _lastRx: -1
    property real _lastTx: -1
    property real _lastNetTime: 0
    property string netName: ""
    property string netAddress: ""
    property string uptimeText: "--"
    property string loadText: "--"
    property string kernelText: ""
    readonly property string powerProfileLabel: {
        let p = PowerProfiles.profile;
        if (p === PowerProfile.Performance) return "Prestaties";
        if (p === PowerProfile.PowerSaver) return "Energiebesparing";
        return "Gebalanceerd";
    }

    function formatRate(bytesPerSecond) {
        let v = Math.max(0, bytesPerSecond);
        if (v >= 1048576) return (v / 1048576).toFixed(1) + " MB/s";
        if (v >= 1024) return Math.round(v / 1024) + " KB/s";
        return Math.round(v) + " B/s";
    }

    Process {
        id: systemPoller
        command: ["bash", "-lc",
            "ps -eo %cpu=,%mem=,comm= --sort=-%cpu 2>/dev/null | awk '{cpu=$1; mem=$2; $1=\"\"; $2=\"\"; sub(/^ +/, \"\"); if ($0 != \"ps\") printf \"proc=%s|%s|%s\\n\", $0, cpu, mem}' | head -n 5; " +
            "sed 's/:/ /' /proc/net/dev 2>/dev/null | awk 'NR>2 && $1!=\"lo\" {rx+=$2; tx+=$10} END {printf \"net=%.0f|%.0f\\n\", rx, tx}'; " +
            "printf 'conn=%s\\n' \"$(nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo$' | head -n1)\"; " +
            "printf 'ip=%s\\n' \"$(ip -4 -o addr show scope global 2>/dev/null | awk '{print $4; exit}')\"; " +
            "printf 'up=%s\\n' \"$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); if (d>0) printf \"%dd %du %02dm\", d, h, m; else printf \"%du %02dm\", h, m}' /proc/uptime 2>/dev/null)\"; " +
            "printf 'load=%s\\n' \"$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)\"; " +
            "printf 'kernel=%s\\n' \"$(uname -r 2>/dev/null)\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let procs = [];
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    let eq = line.indexOf("=");
                    if (eq <= 0) continue;
                    let key = line.substring(0, eq);
                    let value = line.substring(eq + 1).trim();
                    if (key === "proc") {
                        let parts = value.split("|");
                        if (parts.length >= 3)
                            procs.push({ name: parts[0], cpu: parseFloat(parts[1]) || 0, mem: parseFloat(parts[2]) || 0 });
                    } else if (key === "net") {
                        let parts = value.split("|");
                        let rx = parseFloat(parts[0]) || 0;
                        let tx = parseFloat(parts[1]) || 0;
                        let t = Date.now();
                        if (root._lastRx >= 0 && t > root._lastNetTime) {
                            let dt = (t - root._lastNetTime) / 1000;
                            root.netRxRate = Math.max(0, (rx - root._lastRx) / dt);
                            root.netTxRate = Math.max(0, (tx - root._lastTx) / dt);
                        }
                        root._lastRx = rx;
                        root._lastTx = tx;
                        root._lastNetTime = t;
                    } else if (key === "conn") {
                        root.netName = value;
                    } else if (key === "ip") {
                        root.netAddress = value;
                    } else if (key === "up") {
                        root.uptimeText = value !== "" ? value : "--";
                    } else if (key === "load") {
                        root.loadText = value !== "" ? value : "--";
                    } else if (key === "kernel") {
                        root.kernelText = value;
                    }
                }
                root.topProcesses = procs;
            }
        }
    }

    // Alleen pollen voor het tabblad dat je ziet.
    Timer {
        interval: 2000
        running: root.tab === 2
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!systemPoller.running) systemPoller.running = true
    }

    onTabChanged: {
        if (tab === 1) {
            if (!updatesPoller.running) updatesPoller.running = true;
            MailService.refresh();
        }
    }

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        // Tabbladen, zoals het dashboard van Caelestia. Het paneel houdt bij
        // elk tabblad dezelfde maat, zodat de blob niet verspringt.
        ColumnLayout {
            Layout.preferredWidth: 34
            Layout.fillHeight: true
            spacing: 6

            TabButton { index: 0; icon: "󰕮"; label: "Overzicht" }
            TabButton { index: 1; icon: "󰃭"; label: "Vandaag" }
            TabButton { index: 2; icon: "󰍛"; label: "Systeem" }
            Item { Layout.fillHeight: true }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Tab 0: Overzicht --------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 10
                opacity: root.tab === 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }

                // --- Tijd en datum ---------------------------------------------------
                Card {
                    Layout.preferredWidth: 190
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 20
                        spacing: 0

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.timeText
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 46
                            font.weight: Font.Black
                            color: mocha.text
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dayName
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: mocha.primary
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.dateText
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext0
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            Layout.bottomMargin: 6
                            Layout.preferredHeight: 1
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            visible: root.weatherTemp !== ""
                            text: root.weatherIcon + "  " + root.weatherTemp
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: mocha.text
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            text: root.nextEventText
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: root.nextEvent ? mocha.primary : mocha.subtext0
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.Wrap
                        }
                    }
                }

                // --- Maandkalender ---------------------------------------------------
                Card {
                    Layout.preferredWidth: 250
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            Layout.fillWidth: true
                            text: root.now.toLocaleDateString(root.nl, "MMMM yyyy")
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: mocha.text
                            horizontalAlignment: Text.AlignHCenter
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7
                            rowSpacing: 1
                            columnSpacing: 1

                            Repeater {
                                model: ["ma", "di", "wo", "do", "vr", "za", "zo"]
                                delegate: Text {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    text: modelData
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 9
                                    color: mocha.subtext0
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            // 6 weken * 7 dagen dekt elke maandindeling.
                            Repeater {
                                model: 42
                                delegate: Item {
                                    required property int index

                                    // Maandag = 0. JS telt zondag als 0, vandaar de shift.
                                    readonly property int firstDow: {
                                        let d = new Date(root.now.getFullYear(), root.now.getMonth(), 1).getDay();
                                        return (d + 6) % 7;
                                    }
                                    readonly property int daysInMonth: new Date(
                                        root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate()
                                    readonly property int dayNum: index - firstDow + 1
                                    readonly property bool valid: dayNum >= 1 && dayNum <= daysInMonth
                                    readonly property bool isToday: valid && dayNum === root.now.getDate()

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 17

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 18
                                        height: 16
                                        radius: 5
                                        visible: parent.isToday
                                        color: mocha.primary
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: parent.valid
                                        text: parent.valid ? parent.dayNum : ""
                                        font.family: ThemeConfig.monoFont
                                        font.pixelSize: 10
                                        font.weight: parent.isToday ? Font.Black : Font.Normal
                                        color: parent.isToday ? mocha.base : mocha.text
                                    }
                                }
                            }
                        }
                    }
                }

                // --- Systeembelasting ------------------------------------------------
                Card {
                    Layout.preferredWidth: 210
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        Meter {
                            label: "CPU"
                            value: root.cpuPercent
                            suffix: root.cpuTemp === "--" ? "" : root.cpuTemp
                            accent: mocha.peach
                        }
                        Meter {
                            label: "Geheugen"
                            value: root.ramPercent
                            accent: mocha.blue
                        }
                        Meter {
                            label: "Schijf"
                            value: root.diskPercent
                            accent: mocha.teal
                        }
                    }
                }

                // --- Media -----------------------------------------------------------
                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 56
                            Layout.preferredHeight: 56
                            radius: 14
                            color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.14)
                            clip: true

                            Image {
                                id: cover
                                anchors.fill: parent
                                source: root.activePlayer && root.activePlayer.trackArtUrl
                                    ? root.activePlayer.trackArtUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cover.status !== Image.Ready
                                text: "󰎆"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: 24
                                color: mocha.green
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: root.hasMedia ? root.activePlayer.trackTitle : "Geen media actief"
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: mocha.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.hasMedia ? String(root.activePlayer.trackArtist || "") : ""
                                visible: text !== ""
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                color: mocha.subtext0
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                Layout.topMargin: 4
                                spacing: 6
                                visible: root.hasMedia

                                MediaButton {
                                    icon: "󰒮"
                                    onTriggered: if (root.activePlayer && root.activePlayer.canGoPrevious)
                                        root.activePlayer.previous()
                                }
                                MediaButton {
                                    icon: root.activePlayer
                                        && root.activePlayer.playbackState === MprisPlaybackState.Playing
                                        ? "󰏤" : "󰐊"
                                    onTriggered: if (root.activePlayer && root.activePlayer.canTogglePlaying)
                                        root.activePlayer.togglePlaying()
                                }
                                MediaButton {
                                    icon: "󰒭"
                                    onTriggered: if (root.activePlayer && root.activePlayer.canGoNext)
                                        root.activePlayer.next()
                                }
                            }
                        }
                    }
                }
            }

            // --- Tab 1: Vandaag ----------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 10
                opacity: root.tab === 1 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }

                Card {
                    Layout.preferredWidth: 330
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        CardHeader { title: "Agenda"; target: "calendar" }

                        Repeater {
                            model: root.upcomingEvents
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.title || "")
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.eventWhen(modelData)
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 9
                                    color: mocha.primary
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        EmptyText { visible: root.upcomingEvents.length === 0; text: "Geen afspraken gepland" }
                        Item { Layout.fillHeight: true }
                    }
                }

                Card {
                    Layout.preferredWidth: 300
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        CardHeader {
                            title: NotificationService.count > 0 ? "Meldingen (" + NotificationService.count + ")" : "Meldingen"
                            target: "notifications"
                        }

                        Repeater {
                            model: root.latestNotifications
                            delegate: ColumnLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.summary || modelData.appName || "Melding")
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: text !== ""
                                    text: String(modelData.appName || "")
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 9
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        EmptyText { visible: NotificationService.count === 0; text: "Geen meldingen" }
                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            ChipButton {
                                icon: NotificationService.dnd ? "󰂛" : "󰂚"
                                label: "Niet storen"
                                active: NotificationService.dnd
                                onTriggered: NotificationService.toggleDnd()
                            }
                            Item { Layout.fillWidth: true }
                            ChipButton {
                                visible: NotificationService.count > 0
                                icon: "󰎟"
                                label: "Wissen"
                                onTriggered: NotificationService.clearAll()
                            }
                        }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        CardHeader { title: "Post"; target: "mail" }

                        Text {
                            Layout.fillWidth: true
                            text: MailService.statusText
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: MailService.unreadKnown && MailService.unreadCount > 0 ? mocha.primary : mocha.subtext0
                            elide: Text.ElideRight
                        }

                        Repeater {
                            model: MailService.recent.slice(0, 2)
                            delegate: Text {
                                required property var modelData
                                Layout.fillWidth: true
                                text: String(modelData.title || "Bericht")
                                    + (String(modelData.sender || "") !== "" ? "  ·  " + String(modelData.sender) : "")
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 10
                                color: mocha.text
                                elide: Text.ElideRight
                            }
                        }

                        Item { Layout.fillHeight: true }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Text {
                                    text: "Updates"
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: mocha.text
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.updateCount < 0 ? "Controleren…"
                                        : (root.updateCount === 0 ? "Alles is bijgewerkt"
                                            : "Arch/AUR " + root.packageUpdateCount + " · Flatpak " + root.flatpakUpdateCount
                                              + (root.dotfilesCommitCount > 0 ? " · dotfiles " + root.dotfilesCommitCount : ""))
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 9
                                    color: mocha.subtext0
                                    elide: Text.ElideRight
                                }
                            }
                            ChipButton {
                                visible: root.updateCount > 0
                                icon: "󰚰"
                                label: "Bijwerken (" + root.updateCount + ")"
                                active: true
                                onTriggered: root.openUpdatesTerminal()
                            }
                        }
                    }
                }
            }

            // --- Tab 2: Systeem ----------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 10
                opacity: root.tab === 2 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity {
                    NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
                }

                Card {
                    Layout.preferredWidth: 330
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5

                        CardHeader { title: "Processen"; target: "performance" }

                        Repeater {
                            model: root.topProcesses
                            delegate: RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    Layout.fillWidth: true
                                    text: String(modelData.name || "")
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 11
                                    color: mocha.text
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.preferredWidth: 58
                                    horizontalAlignment: Text.AlignRight
                                    text: Number(modelData.cpu).toFixed(1) + "%"
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: mocha.peach
                                }
                                Text {
                                    Layout.preferredWidth: 58
                                    horizontalAlignment: Text.AlignRight
                                    text: Number(modelData.mem).toFixed(1) + "%"
                                    font.family: ThemeConfig.monoFont
                                    font.pixelSize: 11
                                    color: mocha.blue
                                }
                            }
                        }

                        EmptyText { visible: root.topProcesses.length === 0; text: "Processen laden…" }
                        Item { Layout.fillHeight: true }
                    }
                }

                Card {
                    Layout.preferredWidth: 250
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        CardHeader { title: "Netwerk"; target: "network" }

                        StatLine { icon: "󰁅"; label: "Download"; value: root.formatRate(root.netRxRate); accent: mocha.teal }
                        StatLine { icon: "󰁝"; label: "Upload"; value: root.formatRate(root.netTxRate); accent: mocha.peach }
                        StatLine { icon: "󰖩"; label: "Verbinding"; value: root.netName !== "" ? root.netName : "Geen"; accent: mocha.accent3 }
                        StatLine { icon: "󰩟"; label: "Adres"; value: root.netAddress !== "" ? root.netAddress : "--"; accent: mocha.accent1 }
                        Item { Layout.fillHeight: true }
                    }
                }

                Card {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 6

                        CardHeader { title: "Sessie"; target: "" }

                        StatLine { icon: "󰔟"; label: "Actief sinds"; value: root.uptimeText; accent: mocha.accent1 }
                        StatLine { icon: "󰓅"; label: "Belasting"; value: root.loadText; accent: mocha.peach }
                        StatLine { icon: "󰾅"; label: "Energieprofiel"; value: root.powerProfileLabel; accent: mocha.accent3 }
                        StatLine { icon: "󰌽"; label: "Kernel"; value: root.kernelText; accent: mocha.subtext1 }
                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            ChipButton {
                                icon: "󰄪"
                                label: "btop"
                                onTriggered: Quickshell.execDetached(["kitty", "--title=btop", "btop"])
                            }
                        }
                    }
                }
            }
        }
    }

    component TabButton: Rectangle {
        id: tabBtn
        property int index: 0
        property string icon: ""
        property string label: ""
        readonly property bool active: root.tab === index

        Layout.preferredWidth: 34
        Layout.preferredHeight: 34
        radius: Math.min(root.cardRadius, 12)
        color: active
            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.22)
            : (tabMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : "transparent")
        border.width: active ? 1 : 0
        border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.42)
        scale: tabMouse.containsMouse && !active ? 1.07 : 1.0
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Text {
            anchors.centerIn: parent
            text: tabBtn.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 16
            color: tabBtn.active ? mocha.primary : mocha.subtext0
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            // Hover wisselt ook al: het hele paneel werkt op hover, dus een
            // klik zou overbodig voelen.
            onEntered: hoverSwitch.restart()
            onExited: hoverSwitch.stop()
            onClicked: root.tab = tabBtn.index
        }

        Timer {
            id: hoverSwitch
            interval: 140
            onTriggered: root.tab = tabBtn.index
        }
    }

    component CardHeader: RowLayout {
        id: header
        property string title: ""
        property string target: ""
        Layout.fillWidth: true
        spacing: 4

        Text {
            Layout.fillWidth: true
            text: header.title
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            font.weight: Font.Bold
            color: mocha.text
            elide: Text.ElideRight
        }

        Rectangle {
            visible: header.target !== ""
            Layout.preferredWidth: 22
            Layout.preferredHeight: 20
            radius: 6
            color: headerMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10) : "transparent"
            Behavior on color {
                ColorAnimation { duration: ThemeConfig.durationToken("fast") }
            }
            Text {
                anchors.centerIn: parent
                text: "󰅂"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 13
                color: headerMouse.containsMouse ? mocha.text : mocha.subtext0
            }
            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.panelSwitchRequested(header.target)
            }
        }
    }

    component EmptyText: Text {
        Layout.fillWidth: true
        font.family: ThemeConfig.uiFont
        font.pixelSize: 11
        color: mocha.subtext0
        elide: Text.ElideRight
    }

    component StatLine: RowLayout {
        id: stat
        property string icon: ""
        property string label: ""
        property string value: ""
        property color accent: mocha.text
        Layout.fillWidth: true
        spacing: 8
        Text {
            text: stat.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: stat.accent
        }
        Text {
            text: stat.label
            font.family: ThemeConfig.uiFont
            font.pixelSize: 11
            color: mocha.subtext1
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: stat.value
            font.family: ThemeConfig.monoFont
            font.pixelSize: 11
            font.weight: Font.Bold
            color: mocha.text
            elide: Text.ElideLeft
        }
    }

    component ChipButton: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property bool active: false
        signal triggered()

        implicitWidth: chipRow.implicitWidth + 16
        implicitHeight: 24
        radius: height / 2
        color: active
            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, chipMouse.containsMouse ? 0.32 : 0.20)
            : (chipMouse.containsMouse
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06))
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 12
                color: chip.active ? mocha.primary : mocha.subtext1
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: mocha.text
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.triggered()
        }
    }

    component Card: Rectangle {
        clip: true
        radius: root.cardRadius
        color: root.cardColor
        border.width: 1
        border.color: root.cardBorder
    }

    component Meter: ColumnLayout {
        id: meter

        property string label: ""
        property int value: 0
        property string suffix: ""
        property color accent: mocha.text

        Layout.fillWidth: true
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: meter.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                color: mocha.subtext1
            }
            Item { Layout.fillWidth: true }
            Text {
                text: meter.value + "%" + (meter.suffix !== "" ? "  " + meter.suffix : "")
                font.family: ThemeConfig.monoFont
                font.pixelSize: 11
                font.weight: Font.Bold
                color: mocha.text
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 5
            radius: 3
            color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)

            Rectangle {
                width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
                height: parent.height
                radius: parent.radius
                color: meter.accent

                Behavior on width {
                    NumberAnimation {
                        duration: ThemeConfig.durationToken("medium")
                        easing.type: ThemeConfig.easingToken("standard")
                    }
                }
            }
        }
    }

    component MediaButton: Rectangle {
        id: btn

        property string icon: ""
        signal triggered()

        implicitWidth: 28
        implicitHeight: 24
        radius: 8
        color: btnMouse.containsMouse
            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.22)
            : Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.30)

        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast") }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 13
            color: mocha.text
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.triggered()
        }
    }
}
