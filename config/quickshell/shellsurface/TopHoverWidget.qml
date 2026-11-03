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
// Eén overzicht; wat vroeger het tabblad Systeem was (processen, netwerk,
// sessie, GPU) staat nu in het prestatiepaneel. Pijltjes in een kaart
// openen het volledige paneel via de PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }
    readonly property var mochaPalette: mocha

    readonly property int pad: 14
    readonly property int cardRadius: Math.max(12, ThemeConfig.styleWidgetRadius)
    readonly property color cardColor: mocha.shellRaisedFill
    readonly property color cardBorder: mocha.shellOutline

    property var now: new Date()
    // Gezet door PanelHost: vastpinnen in de rail geldt voor dit scherm.
    property string screenName: ""
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
    readonly property bool mediaPlaying: activePlayer !== null
                                         && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property real mediaLength: activePlayer && activePlayer.lengthSupported ? Number(activePlayer.length || 0) : 0
    property real mediaPosition: 0

    // Mpris werkt `position` niet zelf bij; zonder tik staat de balk stil.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.hasMedia && root.mediaLength > 0
        onTriggered: {
            if (!root.activePlayer || !root.activePlayer.positionSupported) return;
            root.activePlayer.positionChanged();
            root.mediaPosition = Number(root.activePlayer.position || 0);
        }
    }

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
    // uit de lokale agenda, net als het agendapaneel.
    property string weatherIcon: ""
    property string weatherTemp: ""
    property var localEvents: []
    readonly property var nextEvent: {
        let all = localEvents;
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

    Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!weatherPoller.running) weatherPoller.running = true;
            if (!localAgendaPoller.running) localAgendaPoller.running = true;
        }
    }

    // --- Schermtijd (Focus-daemon) ------------------------------------------
    // De daemon schrijft de stand van vandaag naar een state-file; die lezen
    // we hier alleen, net als het Focus-paneel.
    property int screenTimeTotal: 0
    property var screenTimeApps: []

    function formatDuration(seconds) {
        let s = Math.max(0, Math.round(Number(seconds) || 0));
        let h = Math.floor(s / 3600);
        let m = Math.floor((s % 3600) / 60);
        if (h > 0) return h + "u " + (m < 10 ? "0" : "") + m + "m";
        return m + "m";
    }

    Process {
        id: screenTimePoller
        command: ["sh", "-c", "cat \"${XDG_RUNTIME_DIR:-/tmp}/focustime_state.json\" 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text.trim() || "{}");
                    if (data.selected_date !== Qt.formatDate(new Date(), "yyyy-MM-dd")) {
                        root.screenTimeTotal = 0;
                        root.screenTimeApps = [];
                        return;
                    }
                    root.screenTimeTotal = Number(data.total || 0);
                    let apps = Array.isArray(data.apps) ? data.apps : [];
                    let hidden = ["Desktop", "Locked", "Quickshell", "Unknown"];
                    root.screenTimeApps = apps.filter(a => hidden.indexOf(String(a["class"] || "")) === -1).slice(0, 3);
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!screenTimePoller.running) screenTimePoller.running = true
    }

    // --- Koppeling met PanelHost ----------------------------------------------
    // PanelHost leest dit bij een wissel naar het netwerkpaneel.
    property string requestedNetworkMode: ""
    // Eerste klik in het paneel: PanelHost zet het dan vast, zodat een
    // via hover geopend controlecentrum niet dichtklapt zodra je even
    // buiten beweegt.
    signal interacted()
    // PanelHost luistert hiernaar, zodat een pijltje hier het volledige
    // paneel opent met dezelfde blob-overgang als een railklik.
    signal panelSwitchRequested(string entryId)

    function clampPercent(value) {
        let parsed = parseInt(value);
        return isNaN(parsed) ? 0 : Math.max(0, Math.min(100, parsed));
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: 10

        // Smalle kolom: Systeem opent het prestatiepaneel (daar staan nu
        // processen, netwerk, sessie en GPU), onderaan Instellingen.
        ColumnLayout {
            Layout.preferredWidth: 34
            Layout.fillHeight: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: Math.min(root.cardRadius, 12)
                color: systemMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : "transparent"
                scale: systemMouse.containsMouse ? 1.07 : 1.0
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }
                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") } }
                Text { anchors.centerIn: parent; text: "󰍛"; font.family: ThemeConfig.iconFont; font.pixelSize: 16; color: systemMouse.containsMouse ? mocha.primary : mocha.subtext0 }
                MouseArea {
                    id: systemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.panelSwitchRequested("performance")
                }
            }
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 34
                radius: 8
                color: bedieningMouse.containsMouse ? mocha.shellHoverFill : "transparent"
                Text { anchors.centerIn: parent; text: "󰒓"; font.family: ThemeConfig.iconFont; font.pixelSize: 18; color: mocha.text }
                MouseArea {
                    id: bedieningMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "open", "settings", "start"])
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // --- Tab 0: Controlecentrum --------------------------------------
            // Drie kolommen, zoals het control center van macOS en de snelle
            // instellingen van GNOME: links schakelen en schuiven, midden tijd
            // en agenda, rechts media, meldingen en schermtijd.
            RowLayout {
                anchors.fill: parent
                spacing: 10

                // --- Snelle instellingen -------------------------------------
                Card {
                    Layout.preferredWidth: 350
                    Layout.fillHeight: true

                    Flickable {
                        id: togglesFlick
                        anchors.fill: parent
                        anchors.margins: 12
                        clip: true
                        contentWidth: width
                        contentHeight: toggles.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ControlToggles {
                            id: toggles
                            width: togglesFlick.width
                            screenName: root.screenName
                            onPanelSwitchRequested: (entryId) => {
                                root.requestedNetworkMode = toggles.requestedNetworkMode;
                                root.panelSwitchRequested(entryId);
                            }
                        }
                    }
                }

                // --- Tijd, agenda en belasting ------------------------------
                ColumnLayout {
                    Layout.preferredWidth: 270
                    Layout.fillHeight: true
                    spacing: 10

                    // --- Tijd en datum ---------------------------------------------------
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 168

                        ColumnLayout {
                            anchors.centerIn: parent
                            width: parent.width - 20
                            spacing: 0

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.timeText
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 46
                                font.weight: ThemeConfig.headingWeight
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
                                font.family: ThemeConfig.iconFont
                                font.pixelSize: 13
                                font.weight: ThemeConfig.emphasisWeight
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
                        Layout.fillWidth: true
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
                                font.weight: ThemeConfig.emphasisWeight
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
                        Layout.fillWidth: true
                        Layout.preferredHeight: 116

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

                }

                // Rechterkolom: media, meldingen, schermtijd.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    // --- Media -----------------------------------------------------------
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104

                        // Rechtsklik: play/pauze als mini-tegel in de rail.
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: ScreenProfiles.togglePinOn(root.screenName, "media")
                        }
                        Text {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            z: 2
                            text: "󰐃"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 10
                            color: mocha.green
                            opacity: ScreenProfiles.isPinnedOn(root.screenName, "media") ? 0.9 : 0
                            Behavior on opacity {
                                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            // Zelfde draaitafel als in Geluid & media, klein en
                            // zonder arm; hij draait alleen tijdens afspelen.
                            MediaVinyl {
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 60
                                mocha: root.mochaPalette
                                accent: mocha.green
                                artUrl: ArtCache.local(root.activePlayer && root.activePlayer.trackArtUrl
                                    ? String(root.activePlayer.trackArtUrl) : "")
                                playing: root.mediaPlaying
                                showArm: false
                                coverRadius: 14
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        Layout.fillWidth: true
                                        text: root.hasMedia ? root.activePlayer.trackTitle : "Geen media actief"
                                        font.family: ThemeConfig.displayFont
                                        font.pixelSize: 15
                                        font.weight: ThemeConfig.emphasisWeight
                                        color: mocha.text
                                        elide: Text.ElideRight
                                    }
                                    // Opent Geluid & media met de kaart Nu speelt.
                                    CardHeader { Layout.fillWidth: false; target: "audiomedia" }
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

                                // Voortgang van de track.
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 3
                                    Layout.preferredHeight: 3
                                    visible: root.hasMedia && root.mediaLength > 0
                                    radius: 1.5
                                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                                    Rectangle {
                                        height: parent.height
                                        radius: parent.radius
                                        width: Math.max(height, parent.width
                                            * Math.max(0, Math.min(1, root.mediaPosition / Math.max(1, root.mediaLength))))
                                        color: mocha.green
                                        opacity: root.mediaPlaying ? 0.9 : 0.45
                                        Behavior on width {
                                            NumberAnimation { duration: 900; easing.type: Easing.Linear }
                                        }
                                        Behavior on opacity {
                                            NumberAnimation { duration: ThemeConfig.durationToken("fast") }
                                        }
                                    }
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

                    // --- Meldingen ------------------------------------------------------
                    // Het meldingencentrum zit hier, naast de schakelaars, zoals
                    // bij GNOME en macOS. Klik = actie van de app, kruisje =
                    // wegdoen; het pijltje opent het volledige meldingenpaneel.
                    Card {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: NotificationService.dnd ? "󰂛" : "󰂚"
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: 13
                                    color: NotificationService.dnd ? mocha.accent2 : mocha.primary
                                }
                                CardHeader {
                                    title: NotificationService.count > 0
                                        ? "Meldingen  ·  " + NotificationService.count
                                        : "Meldingen"
                                    target: "notifications"
                                }
                                ChipButton {
                                    visible: NotificationService.count > 0
                                    icon: "󰎟"
                                    label: "Wis alles"
                                    onTriggered: NotificationService.clearAll()
                                }
                            }

                            ListView {
                                id: notifList
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                // Per app gegroepeerd, nieuwste app bovenaan: een kopregel
                                // per app (kruisje wist de hele groep), daaronder de meldingen.
                                model: {
                                    let dep = NotificationService.count;
                                    let rows = [];
                                    let groups = NotificationService.groups();
                                    for (let g = 0; g < groups.length; g++) {
                                        rows.push({ header: true, app: groups[g].app, count: groups[g].items.length });
                                        for (let i = 0; i < groups[g].items.length; i++)
                                            rows.push({ header: false, app: groups[g].app, n: groups[g].items[i] });
                                    }
                                    return rows;
                                }

                                add: Transition {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: ThemeConfig.durationToken("fast") }
                                }
                                remove: Transition {
                                    NumberAnimation { property: "opacity"; to: 0; duration: ThemeConfig.durationToken("fast") }
                                }

                                delegate: Rectangle {
                                    id: notifRow
                                    required property var modelData
                                    readonly property bool isHeader: !!modelData.header
                                    readonly property var n: modelData.n || null
                                    width: notifList.width
                                    height: isHeader ? 24 : 46
                                    radius: Math.min(root.cardRadius, 14)
                                    color: isHeader ? "transparent" : notifMouse.containsMouse
                                        ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                                        : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.04)
                                    Behavior on color {
                                        ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                                    }

                                    // Kopregel van een app-groep.
                                    RowLayout {
                                        visible: notifRow.isHeader
                                        anchors.fill: parent
                                        anchors.leftMargin: 6
                                        anchors.rightMargin: 6
                                        spacing: 6
                                        Text {
                                            Layout.fillWidth: true
                                            text: String(notifRow.modelData.app || "") + (notifRow.modelData.count > 1 ? "  ·  " + notifRow.modelData.count : "")
                                            font.family: ThemeConfig.uiFont
                                            font.pixelSize: 10
                                            font.weight: ThemeConfig.emphasisWeight
                                            color: mocha.subtext1
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: "󰅖"
                                            font.family: ThemeConfig.iconFont
                                            font.pixelSize: 11
                                            color: groupCloseMouse.containsMouse ? mocha.red : mocha.subtext0
                                            MouseArea {
                                                id: groupCloseMouse
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotificationService.dismissApp(notifRow.modelData.app)
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: notifMouse
                                        visible: !notifRow.isHeader
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            NotificationService.invokeDefault(notifRow.n);
                                            NotificationService.dismiss(notifRow.n);
                                        }
                                    }

                                    RowLayout {
                                        visible: !notifRow.isHeader
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 6
                                        spacing: 8

                                        Item {
                                            Layout.preferredWidth: 24
                                            Layout.preferredHeight: 24
                                            Image {
                                                id: notifIcon
                                                anchors.fill: parent
                                                sourceSize.width: 48
                                                sourceSize.height: 48
                                                source: NotificationService.iconSource(notifRow.n)
                                                visible: status === Image.Ready
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                visible: !notifIcon.visible
                                                text: "󰂚"
                                                font.family: ThemeConfig.iconFont
                                                font.pixelSize: 14
                                                color: mocha.subtext0
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 0
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: notifRow.n ? String(notifRow.n.summary || notifRow.n.appName || "") : ""
                                                    font.family: ThemeConfig.uiFont
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: mocha.text
                                                    elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: NotificationService.relativeTime(notifRow.n)
                                                    visible: text !== ""
                                                    font.family: ThemeConfig.uiFont
                                                    font.pixelSize: 9
                                                    color: mocha.subtext0
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: String(notifRow.n ? notifRow.n.body || "" : "").replace(/<[^>]*>/g, "").replace(/\s+/g, " ")
                                                visible: text !== ""
                                                font.family: ThemeConfig.uiFont
                                                font.pixelSize: 10
                                                color: mocha.subtext0
                                                elide: Text.ElideRight
                                                maximumLineCount: 1
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 11
                                            color: closeMouse.containsMouse
                                                ? Qt.rgba(mocha.red.r, mocha.red.g, mocha.red.b, 0.20) : "transparent"
                                            Behavior on color {
                                                ColorAnimation { duration: ThemeConfig.durationToken("fast") }
                                            }
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                font.family: ThemeConfig.iconFont
                                                font.pixelSize: 12
                                                color: closeMouse.containsMouse ? mocha.red : mocha.subtext0
                                            }
                                            MouseArea {
                                                id: closeMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: NotificationService.dismiss(notifRow.n)
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                visible: NotificationService.count === 0
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 2
                                Item { Layout.fillHeight: true }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: NotificationService.dnd ? "󰂛" : "󰂜"
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: 26
                                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.25)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: NotificationService.dnd ? "Niet storen staat aan" : "Geen meldingen"
                                    font.family: ThemeConfig.uiFont
                                    font.pixelSize: 11
                                    color: mocha.subtext0
                                }
                                Item { Layout.fillHeight: true }
                            }
                        }
                    }

                    // --- Schermtijd (Focus) ---------------------------------------------
                    // Stond als knop in de rail; hier zie je het in één oogopslag.
                    // Het pijltje opent het volledige Focus-paneel.
                    Card {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text {
                                    text: "󰥔"
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: 13
                                    color: mocha.primary
                                }
                                CardHeader {
                                    title: "Schermtijd vandaag  ·  " + root.formatDuration(root.screenTimeTotal)
                                    target: "focustime"
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                EmptyText {
                                    visible: root.screenTimeApps.length === 0
                                    text: "Nog geen gegevens van vandaag"
                                }

                                Repeater {
                                    model: root.screenTimeApps
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.preferredHeight: 24
                                        Layout.fillWidth: true
                                        Layout.maximumWidth: 150
                                        radius: 12
                                        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 6
                                            anchors.rightMargin: 9
                                            spacing: 5
                                            Image {
                                                Layout.preferredWidth: 14
                                                Layout.preferredHeight: 14
                                                sourceSize.width: 28
                                                sourceSize.height: 28
                                                source: modelData.icon ? (String(modelData.icon).startsWith("/")
                                                    ? "file://" + modelData.icon : Quickshell.iconPath(modelData.icon, true)) : ""
                                                visible: status === Image.Ready
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: String(modelData.name || modelData["class"] || "")
                                                font.family: ThemeConfig.uiFont
                                                font.pixelSize: 10
                                                color: mocha.text
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: root.formatDuration(modelData.seconds || 0)
                                                font.family: ThemeConfig.monoFont
                                                font.pixelSize: 9
                                                color: mocha.subtext0
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true; visible: root.screenTimeApps.length > 0 && root.screenTimeApps.length < 3 }
                            }
                        }
                    }
                }
            }
        }
    }

    // Ziet elke klik in het paneel, maar laat hem door naar wat eronder
    // ligt; het wiel gaat ook door, anders scrollt er niets meer.
    MouseArea {
        anchors.fill: parent
        z: 1000
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => {
            root.interacted();
            mouse.accepted = false;
        }
        onWheel: (wheel) => wheel.accepted = false
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
            font.weight: ThemeConfig.emphasisWeight
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
                font.family: ThemeConfig.iconFont
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
                font.family: ThemeConfig.iconFont
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
                font.weight: ThemeConfig.emphasisWeight
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
            font.family: ThemeConfig.iconFont
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
