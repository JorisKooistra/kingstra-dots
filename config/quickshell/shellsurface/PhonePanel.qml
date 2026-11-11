import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import ".."

// Telefoon (KDE Connect), in dezelfde vormtaal als Batterij & energie en
// Snelle instellingen: afgeronde tegels, Matugen-kleuren, ThemeConfig-
// animaties. De vorm (blob, hoeken, groei) komt uit PanelHost.
//  - kaart met naam, verbindingsstatus, batterij (balk met laadglans) en
//    mobiel netwerk; duidelijke uitleg als hij gekoppeld maar weg is;
//  - koppelen, koppelverzoek van de telefoon accepteren of weigeren;
//  - tegels: zoek telefoon, klembord, bestand(en) sturen, bestanden
//    bladeren (sshfs), sms en testbericht;
//  - scherm: telefoon op de pc (scrcpy, eigen venster "Telefoon") en de pc
//    op de telefoon (wayvnc via Tailscale), met status en aan/uit hier;
//  - media van de telefoon: titel, vorige/afspelen/volgende en volume;
//  - meldingen van de telefoon: wegvegen en (waar het kan) antwoorden.
// Alles via je eigen netwerk, niets via internet (phone.py, D-Bus).
Item {
    id: root

    MatugenColors { id: mocha }
    // Voor PanelSlider: `mocha: mocha` zou op de eigen property kunnen binden.
    readonly property var mochaPalette: mocha

    signal panelSwitchRequested(string entryId)

    readonly property string script: Quickshell.env("HOME") + "/.config/hypr/scripts/phone.py"
    readonly property string feedbackScript: Quickshell.env("HOME") + "/.config/hypr/scripts/feedback.sh"
    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property bool matteStyle: ThemeConfig.styleFamily === "matte"
    readonly property int preferredPanelWidth: 420
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

    // --- Gegevens -------------------------------------------------------------
    property bool loaded: false
    property bool fresh: false
    property bool installed: true
    property bool hasSshfs: false
    property bool hasSmsApp: false
    // Scherm delen (phone-screen.sh tools).
    readonly property string screenScript: Quickshell.env("HOME") + "/.config/hypr/scripts/phone-screen.sh"
    property var screenInfo: ({ scrcpy: false, wayvnc: false, vnc: false, mirror: false, wifiKnown: false, tailscale: "", port: 5900 })
    readonly property bool hasScreenTools: !!screenInfo.scrcpy || !!screenInfo.wayvnc
    property var devices: []
    property string selectedId: ""
    readonly property var dev: {
        for (let i = 0; i < devices.length; i++)
            if (devices[i].id === selectedId) return devices[i];
        return devices.length > 0 ? devices[0] : null;
    }
    readonly property bool usable: !!(dev && dev.reachable && dev.paired)
    readonly property var media: usable && dev.media ? dev.media : null
    readonly property var notes: usable && Array.isArray(dev.notifications) ? dev.notifications : []

    // Welke actie loopt er (voor "bezig"), en welke is net gelukt (vinkje).
    property string busy: ""
    property string done: ""
    property bool searching: false
    property bool smsOpen: false
    property bool showAllNotes: false
    property string replyTo: ""
    property bool mediaVolumeDragging: false

    readonly property color phoneAccent: mocha.accent2
    readonly property color batColor: {
        if (!usable || dev.battery < 0) return mocha.subtext0;
        if (dev.charging) return mocha.green;
        if (dev.battery >= 50) return mocha.accent1;
        if (dev.battery >= 20) return mocha.yellow;
        return mocha.red;
    }

    function refresh() { if (!statusProc.running) statusProc.running = true; }
    function feedback(icon, title, detail) {
        Quickshell.execDetached(["bash", feedbackScript, icon, title, detail || "", "3500"]);
    }
    function act(action, extra) {
        if (!dev || busy !== "") return;
        busy = action;
        let cmd = ["python3", script, action, dev.id];
        if (extra) cmd = cmd.concat(extra);
        actProc.command = cmd;
        actProc.running = true;
    }
    function batteryIcon() {
        if (!usable || dev.battery < 0) return "󰂑";
        if (dev.charging) return "󰂄";
        let steps = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"];
        return steps[Math.max(0, Math.min(10, Math.round(dev.battery / 10)))];
    }
    function signalIcon(s) {
        return ["󰢿", "󰢼", "󰢽", "󰢾", "󰣺"][Math.max(0, Math.min(4, s))];
    }
    function statusLine() {
        if (!dev) return root.loaded ? "Geen telefoon gevonden" : "Zoeken…";
        if (dev.pairIncoming) return "Wil koppelen";
        if (dev.pairRequested) return "Wacht op je telefoon…";
        if (!dev.paired) return "Niet gekoppeld";
        if (!dev.reachable) return root.searching ? "Zoeken…" : "Niet bereikbaar";
        return "Verbonden";
    }

    Component.onCompleted: { cacheProc.running = true; refresh(); }

    function apply(data) {
        root.installed = data.installed !== false;
        root.hasSshfs = !!data.sshfs;
        root.hasSmsApp = !!data.smsApp;
        root.devices = Array.isArray(data.devices) ? data.devices : [];
        if (root.selectedId === "" && root.devices.length > 0) root.selectedId = root.devices[0].id;
        root.loaded = true;
    }

    Process {
        id: cacheProc
        command: ["python3", root.script, "cached"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.fresh) return;
                try { root.apply(JSON.parse(this.text.trim() || "{}")); } catch (e) {}
            }
        }
    }
    Process {
        id: statusProc
        command: ["python3", root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.apply(JSON.parse(this.text.trim() || "{}"));
                    root.fresh = true;
                } catch (e) {
                    root.loaded = true;
                }
            }
        }
    }
    Process {
        id: screenProc
        command: ["bash", root.screenScript, "tools"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { root.screenInfo = JSON.parse(this.text.trim()); } catch (e) {} }
        }
    }
    function screenAction(args) {
        Quickshell.execDetached(["bash", root.screenScript].concat(args));
        screenRecheck.restart();
    }
    Timer { id: screenRecheck; interval: 1200; onTriggered: if (!screenProc.running) screenProc.running = true }

    Process {
        id: actProc
        onExited: (code) => {
            let what = root.busy;
            root.busy = "";
            if (code === 0) {
                root.done = what;
                doneTimer.restart();
                if (what === "sms") { smsText.text = ""; root.smsOpen = false; }
                if (what === "reply") root.replyTo = "";
            } else if (code === 3) {
                // Bestandskiezer geannuleerd: niets melden.
            } else if (code === 4) {
                root.feedback("󰉋", "sshfs ontbreekt", "Nodig om de bestanden van je telefoon te bladeren. Draai kingstra update.");
            } else {
                root.feedback("󰄜", "Telefoon niet bereikt",
                    "Open KDE Connect op je telefoon en controleer of hij op hetzelfde netwerk zit.");
            }
            root.refresh();
        }
    }
    Process {
        id: searchProc
        command: ["python3", root.script, "refresh"]
        onExited: searchDone.restart()
    }
    Timer { id: searchDone; interval: 3500; onTriggered: { root.searching = false; root.refresh(); } }
    Timer { id: doneTimer; interval: 1400; onTriggered: root.done = "" }
    // Zolang het paneel open is: batterij, meldingen en media bijhouden.
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: { root.refresh(); if (!screenProc.running) screenProc.running = true; }
    }

    function search() {
        if (root.searching) return;
        root.searching = true;
        searchProc.running = true;
    }

    // ------------------------------------------------------------------------
    // Weergave
    // ------------------------------------------------------------------------
    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: Math.min(root.itemRadius, 18)
                color: Qt.rgba(root.phoneAccent.r, root.phoneAccent.g, root.phoneAccent.b, 0.22)
                Text {
                    anchors.centerIn: parent
                    text: root.dev && root.dev.type === "tablet" ? "󰓶" : "󰄜"
                    font.family: ThemeConfig.iconFont
                    font.pixelSize: 18
                    color: root.phoneAccent
                }
                // Groene stip: verbonden.
                Rectangle {
                    width: 10; height: 10; radius: 5
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -1
                    color: root.usable ? mocha.green : (root.dev && root.dev.paired ? mocha.subtext0 : "transparent")
                    border.width: 2
                    border.color: mocha.base
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: "Telefoon"
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 17
                    font.weight: ThemeConfig.headingWeight
                    color: mocha.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: "KDE Connect · alleen via je eigen netwerk"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    color: mocha.subtext0
                    elide: Text.ElideRight
                }
            }

            IconButton {
                icon: "󰑐"
                accent: root.phoneAccent
                spinning: root.searching
                tip: "Opnieuw zoeken"
                onTriggered: root.search()
            }
            IconButton {
                icon: "󰒓"
                accent: mocha.subtext1
                tip: "KDE Connect-instellingen"
                onTriggered: Quickshell.execDetached(["python3", root.script, "app"])
            }
            IconButton {
                icon: "󰅁"
                accent: mocha.subtext1
                tip: "Terug naar Snelle instellingen"
                onTriggered: root.panelSwitchRequested("quicksettings")
            }
        }

        // --- Apparaatkeuze (alleen bij meer dan één) ----------------------------
        Flow {
            Layout.fillWidth: true
            visible: root.devices.length > 1
            spacing: 6
            Repeater {
                model: root.devices
                delegate: Rectangle {
                    id: devChip
                    required property var modelData
                    readonly property bool current: !!root.dev && root.dev.id === modelData.id
                    width: devChipRow.implicitWidth + 20
                    height: 28
                    radius: 14
                    color: current
                        ? Qt.rgba(root.phoneAccent.r, root.phoneAccent.g, root.phoneAccent.b, 0.24)
                        : (devChipMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                                                      : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
                    Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                    Row {
                        id: devChipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7; height: 7; radius: 4
                            color: devChip.modelData.reachable ? mocha.green : mocha.surface2
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(devChip.modelData.name || "Telefoon")
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            font.weight: devChip.current ? Font.DemiBold : Font.Normal
                            color: mocha.text
                        }
                    }
                    MouseArea {
                        id: devChipMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.selectedId = devChip.modelData.id; root.replyTo = ""; root.smsOpen = false; }
                    }
                }
            }
        }

        // --- Apparaatkaart --------------------------------------------------------
        Rectangle {
            id: hero
            Layout.fillWidth: true
            Layout.preferredHeight: heroColumn.implicitHeight + 24
            radius: Math.min(root.itemRadius + 2, 18)
            readonly property color tint: root.usable ? root.phoneAccent : mocha.subtext0
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(tint.r, tint.g, tint.b, root.usable ? 0.10 : 0.05)
            border.width: 1
            border.color: Qt.rgba(tint.r, tint.g, tint.b, root.usable ? 0.35 : 0.16)
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
            }
            clip: true

            ColumnLayout {
                id: heroColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: root.dev ? String(root.dev.name || "Telefoon")
                                : (!root.installed ? "KDE Connect ontbreekt" : (root.loaded ? "Nog geen telefoon" : "Zoeken…"))
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 18
                            font.weight: ThemeConfig.headingWeight
                            color: mocha.text
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 6
                            visible: !!root.dev
                            Rectangle {
                                id: statusDot
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7; height: 7; radius: 4
                                color: root.usable ? mocha.green : (root.dev && root.dev.pairIncoming ? mocha.yellow : mocha.subtext0)
                                // Zachte puls tijdens zoeken.
                                SequentialAnimation on opacity {
                                    running: root.searching || (!!root.dev && !!root.dev.pairRequested)
                                    loops: Animation.Infinite
                                    onRunningChanged: if (!running) statusDot.opacity = 1
                                    NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.statusLine()
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: root.usable ? mocha.green : mocha.subtext0
                            }
                        }
                    }

                    // Batterij groot rechts, zoals op het batterijpaneel.
                    Row {
                        visible: root.usable && root.dev.battery >= 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2
                        Text {
                            id: batNumber
                            text: root.usable ? root.dev.battery : ""
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 30
                            font.weight: ThemeConfig.headingWeight
                            color: mocha.text
                        }
                        Text {
                            anchors.baseline: batNumber.baseline
                            text: "%"
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 14
                            color: mocha.subtext0
                        }
                    }
                }

                // Batterijbalk met glans tijdens opladen.
                Rectangle {
                    id: batTrack
                    visible: root.usable && root.dev.battery >= 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: 10
                    radius: height / 2
                    color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.10)
                    Rectangle {
                        id: batFill
                        height: parent.height
                        radius: parent.radius
                        width: Math.max(batTrack.height, batTrack.width * (root.usable ? Math.max(0, Math.min(100, root.dev.battery)) : 0) / 100)
                        color: root.batColor
                        clip: true
                        Behavior on width { NumberAnimation { duration: ThemeConfig.duration(900); easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
                        Rectangle {
                            visible: root.usable && root.dev.charging
                            width: 50
                            height: parent.height
                            radius: parent.radius
                            property real sweep: 0
                            x: -width + (batFill.width + width) * sweep
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                            }
                            NumberAnimation on sweep {
                                from: 0; to: 1; duration: 1800
                                loops: Animation.Infinite
                                running: root.usable && root.dev.charging
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    visible: root.usable
                    spacing: 6
                    InfoChip {
                        visible: root.usable && root.dev.battery >= 0
                        icon: root.batteryIcon()
                        tint: root.batColor
                        label: root.usable && root.dev.charging ? "Laadt op" : "Op batterij"
                    }
                    InfoChip {
                        visible: root.usable && root.dev.signal >= 0
                        icon: root.usable ? root.signalIcon(root.dev.signal) : ""
                        tint: root.phoneAccent
                        label: !root.usable ? "" : (root.dev.network !== "" ? root.dev.network : "Signaal " + Math.max(0, root.dev.signal) + "/4")
                    }
                    InfoChip {
                        visible: root.notes.length > 0
                        icon: "󰂚"
                        tint: root.phoneAccent
                        label: root.notes.length === 1 ? "1 melding" : root.notes.length + " meldingen"
                    }
                }

                // Uitleg en knoppen voor alles behalve "verbonden".
                Text {
                    Layout.fillWidth: true
                    visible: !root.usable
                    wrapMode: Text.WordWrap
                    text: {
                        if (!root.installed) return "KDE Connect is nog niet geïnstalleerd. De updater zet hem erbij (kingstra update).";
                        if (!root.dev) return root.loaded
                            ? "Installeer KDE Connect op je telefoon (Play Store of F-Droid), zorg dat hij op hetzelfde netwerk zit en kies Opnieuw zoeken."
                            : "Even kijken welke telefoons er zijn…";
                        if (root.dev.pairIncoming) return "Je telefoon vraagt om te koppelen. Klopt de code op je telefoon? " + (root.dev.verificationKey ? "Code: " + root.dev.verificationKey : "");
                        if (root.dev.pairRequested) return "Bevestig het koppelverzoek op je telefoon.";
                        if (!root.dev.paired) return "Deze telefoon is in de buurt maar nog niet gekoppeld.";
                        return "Gekoppeld, maar nu niet bereikbaar. Open KDE Connect op je telefoon en kijk of hij op hetzelfde netwerk zit. Staat batterijbesparing voor KDE Connect aan, dan valt de verbinding weg als het scherm uit is.";
                    }
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: !!root.dev && !root.usable
                    spacing: 8
                    PillButton {
                        visible: !!root.dev && root.dev.pairIncoming
                        label: "Accepteren"; icon: "󰄬"; accent: mocha.green; primary: true
                        working: root.busy === "accept"
                        onTriggered: root.act("accept")
                    }
                    PillButton {
                        visible: !!root.dev && root.dev.pairIncoming
                        label: "Weigeren"; icon: "󰅖"; accent: mocha.red
                        working: root.busy === "reject"
                        onTriggered: root.act("reject")
                    }
                    PillButton {
                        visible: !!root.dev && root.dev.reachable && !root.dev.paired && !root.dev.pairIncoming && !root.dev.pairRequested
                        label: "Koppelen"; icon: "󰌹"; accent: root.phoneAccent; primary: true
                        working: root.busy === "pair"
                        onTriggered: root.act("pair")
                    }
                    PillButton {
                        visible: !!root.dev && root.dev.paired && !root.dev.reachable
                        label: root.searching ? "Zoeken…" : "Opnieuw zoeken"; icon: "󰑐"; accent: root.phoneAccent; primary: true
                        working: root.searching
                        onTriggered: root.search()
                    }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        // --- Acties ----------------------------------------------------------
        GridLayout {
            id: tiles
            Layout.fillWidth: true
            visible: root.usable
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            ActionTile {
                action: "ring"; icon: "󰂞"; label: "Zoek telefoon"; accent: mocha.red
                tip: "Laat je telefoon hard afgaan, ook als hij op stil staat"
                onTriggered: root.act("ring")
            }
            ActionTile {
                action: "clipboard"; icon: "󰅍"; label: "Klembord"; accent: mocha.accent1
                tip: "Stuur wat je op de pc hebt gekopieerd naar je telefoon"
                onTriggered: root.act("clipboard")
            }
            ActionTile {
                action: "share"; icon: "󰈙"; label: "Bestand"; accent: mocha.accent3
                tip: "Kies één of meer bestanden om naar je telefoon te sturen"
                onTriggered: root.act("share")
            }
            ActionTile {
                action: "browse"; icon: "󰉋"; label: "Bladeren"; accent: mocha.yellow
                dimmed: !root.hasSshfs
                tip: root.hasSshfs ? "Open de bestanden van je telefoon in Bestanden" : "Hiervoor is sshfs nodig (kingstra update)"
                onTriggered: root.act("browse")
            }
            ActionTile {
                action: "sms"; icon: "󰍦"; label: "Sms"; accent: mocha.green
                toggled: root.smsOpen
                tip: "Stuur een sms via je telefoon"
                onTriggered: {
                    root.smsOpen = !root.smsOpen;
                    if (root.smsOpen) smsNumber.focusInput();
                }
            }
            ActionTile {
                action: "messages"; icon: "󰭹"; label: "Gesprekken"; accent: mocha.green
                visible: root.hasSmsApp
                tip: "Open al je sms-gesprekken (KDE Connect SMS)"
                onTriggered: root.act("messages")
            }
            ActionTile {
                action: "ping"; icon: "󰍡"; label: "Testbericht"; accent: mocha.accent2
                tip: "Stuur een korte melding naar je telefoon"
                onTriggered: root.act("ping")
            }
        }

        // --- Sms -------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            visible: root.usable && root.smsOpen
            Layout.preferredHeight: smsCol.implicitHeight + 20
            radius: Math.min(root.itemRadius, 16)
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.35)

            ColumnLayout {
                id: smsCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                InputField {
                    id: smsNumber
                    Layout.fillWidth: true
                    placeholder: "Telefoonnummer, bv. 06 12345678"
                    accent: mocha.green
                    onAccepted: smsText.focusInput()
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    InputField {
                        id: smsText
                        Layout.fillWidth: true
                        placeholder: "Bericht"
                        accent: mocha.green
                        onAccepted: sendSms()
                        function sendSms() {
                            if (smsNumber.text.trim() === "" || smsText.text.trim() === "") return;
                            root.act("sms", [smsNumber.text.trim(), smsText.text]);
                        }
                    }
                    PillButton {
                        label: "Stuur"; icon: "󰒊"; accent: mocha.green; primary: true
                        working: root.busy === "sms"
                        onTriggered: smsText.sendSms()
                    }
                }
            }
        }

        // --- Scherm: telefoon op pc en pc op telefoon ------------------------
        Rectangle {
            Layout.fillWidth: true
            visible: !!root.dev && root.dev.paired
            Layout.preferredHeight: screenCol.implicitHeight + 20
            radius: Math.min(root.itemRadius, 16)
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
            border.width: 1
            border.color: root.screenInfo.mirror || root.screenInfo.vnc
                ? Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.45)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
            Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }

            ColumnLayout {
                id: screenCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Scherm"
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 10
                    font.weight: ThemeConfig.emphasisWeight
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 0.6
                    color: mocha.subtext0
                }
                Text {
                    Layout.fillWidth: true
                    visible: !root.hasScreenTools
                    wrapMode: Text.WordWrap
                    text: "Je telefoon op de pc bedienen of je pc-scherm op je telefoon bekijken: draai eerst kingstra update (scrcpy en wayvnc)."
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: mocha.subtext0
                }
                ScreenRow {
                    visible: !!root.screenInfo.scrcpy
                    icon: "󰍹"
                    title: "Telefoon op pc"
                    active: !!root.screenInfo.mirror
                    detail: root.screenInfo.mirror ? "Staat in het venster Telefoon · telefoonscherm uit"
                        : (root.screenInfo.wifiKnown ? "Via wifi, je telefoonscherm gaat uit om te sparen"
                                                 : "Eerste keer: USB-foutopsporing aan en kabel erin")
                    activeLabel: "Stoppen"
                    idleLabel: "Tonen"
                    onToggled: root.screenAction(["mirror", "toggle"])
                }
                ScreenRow {
                    visible: !!root.screenInfo.wayvnc
                    icon: "󰍺"
                    title: "Pc op telefoon"
                    active: !!root.screenInfo.vnc
                    detail: root.screenInfo.vnc
                        ? "Gedeeld · VNC-app op " + (root.screenInfo.tailscale || "?") + ":" + root.screenInfo.port
                        : (root.screenInfo.tailscale !== "" ? "Alleen via Tailscale, dus alleen je eigen apparaten"
                                                        : "Zet eerst Tailscale aan")
                    activeLabel: "Stoppen"
                    idleLabel: "Delen"
                    onToggled: root.screenAction(["share", "toggle"])
                }
            }
        }

        // --- Media van de telefoon ------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            visible: root.media !== null
            Layout.preferredHeight: mediaCol.implicitHeight + 20
            radius: Math.min(root.itemRadius, 16)
            color: root.matteStyle ? mocha.shellRaisedFill : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            ColumnLayout {
                id: mediaCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: Math.min(root.itemRadius, 12)
                        color: Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.20)
                        Text {
                            id: mediaGlyph
                            anchors.centerIn: parent
                            text: "󰎈"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 17
                            color: mocha.accent3
                            SequentialAnimation on scale {
                                running: !!root.media && root.media.playing
                                loops: Animation.Infinite
                                onRunningChanged: if (!running) mediaGlyph.scale = 1
                                NumberAnimation { to: 1.12; duration: 450; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: root.media ? (root.media.title || "Niets aan het spelen") : ""
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            color: mocha.text
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.media ? [root.media.artist, root.media.player].filter(s => !!s).join(" · ") : ""
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 10
                            color: mocha.subtext0
                            elide: Text.ElideRight
                        }
                    }
                    IconButton { icon: "󰒮"; accent: mocha.text; onTriggered: root.act("media", ["Previous"]) }
                    IconButton {
                        icon: root.media && root.media.playing ? "󰏤" : "󰐊"
                        accent: mocha.accent3
                        highlighted: true
                        onTriggered: root.act("media", ["PlayPause"])
                    }
                    IconButton { icon: "󰒭"; accent: mocha.text; onTriggered: root.act("media", ["Next"]) }
                }

                PanelSlider {
                    mocha: root.mochaPalette
                    itemRadius: root.itemRadius
                    visible: !!root.media && root.media.volume >= 0
                    icon: root.media && root.media.volume === 0 ? "󰖁" : "󰕾"
                    label: "Volume telefoon"
                    value: root.media ? root.media.volume : 0
                    accent: mocha.accent3
                    onDragToggled: (dragging) => root.mediaVolumeDragging = dragging
                    onMoved: (percent) => {
                        phoneVolume.target = Math.round(percent);
                        if (!phoneVolume.running) phoneVolume.start();
                    }
                }
            }
        }
        Timer {
            id: phoneVolume
            interval: 120
            property int target: -1
            onTriggered: if (target >= 0 && root.dev) {
                Quickshell.execDetached(["python3", root.script, "volume", root.dev.id, String(target)]);
                target = -1;
            }
        }

        // --- Meldingen van de telefoon --------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.notes.length > 0
            Text {
                Layout.fillWidth: true
                text: "Meldingen van je telefoon"
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: ThemeConfig.emphasisWeight
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.6
                color: mocha.subtext0
            }
            Text {
                visible: root.notes.length > 3
                text: root.showAllNotes ? "Minder" : "Alle " + root.notes.length
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: moreMouse.containsMouse ? mocha.text : root.phoneAccent
                MouseArea {
                    id: moreMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showAllNotes = !root.showAllNotes
                }
            }
        }

        Repeater {
            model: root.showAllNotes ? root.notes : root.notes.slice(0, 3)
            delegate: Rectangle {
                id: noteCard
                required property var modelData
                readonly property bool replying: root.replyTo === modelData.id
                Layout.fillWidth: true
                Layout.preferredHeight: noteCol.implicitHeight + 16
                radius: Math.min(root.itemRadius, 14)
                color: noteMouse.containsMouse
                    ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                    : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.04)
                border.width: 1
                border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") }
                }
                clip: true

                MouseArea {
                    id: noteMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                ColumnLayout {
                    id: noteCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    anchors.leftMargin: 10
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            Layout.alignment: Qt.AlignTop
                            radius: 14
                            color: Qt.rgba(root.phoneAccent.r, root.phoneAccent.g, root.phoneAccent.b, 0.18)
                            clip: true
                            Image {
                                id: noteIcon
                                anchors.fill: parent
                                anchors.margins: 4
                                source: noteCard.modelData.icon ? "file://" + noteCard.modelData.icon : ""
                                fillMode: Image.PreserveAspectFit
                                sourceSize.width: 40
                                sourceSize.height: 40
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: noteIcon.status !== Image.Ready
                                text: "󰂚"
                                font.family: ThemeConfig.iconFont
                                font.pixelSize: 13
                                color: root.phoneAccent
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: noteCard.modelData.app || "Melding"
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 9
                                font.weight: ThemeConfig.emphasisWeight
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.4
                                color: mocha.subtext0
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: noteCard.modelData.title || ""
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                color: mocha.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: text !== ""
                                text: noteCard.modelData.text || ""
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                color: mocha.subtext1
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        Row {
                            Layout.alignment: Qt.AlignTop
                            spacing: 4
                            opacity: noteMouse.containsMouse || noteCard.replying ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }
                            SmallButton {
                                visible: noteCard.modelData.replyable
                                icon: "󰑚"
                                accent: root.phoneAccent
                                onTriggered: {
                                    root.replyTo = noteCard.replying ? "" : noteCard.modelData.id;
                                    if (root.replyTo !== "") replyField.focusInput();
                                }
                            }
                            SmallButton {
                                visible: noteCard.modelData.dismissable
                                icon: "󰅖"
                                accent: mocha.red
                                onTriggered: root.act("dismiss", [noteCard.modelData.id])
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: noteCard.replying
                        spacing: 6
                        InputField {
                            id: replyField
                            Layout.fillWidth: true
                            placeholder: "Antwoord"
                            accent: root.phoneAccent
                            onAccepted: if (text.trim() !== "") root.act("reply", [noteCard.modelData.id, text])
                        }
                        PillButton {
                            label: "Stuur"; icon: "󰒊"; accent: root.phoneAccent; primary: true
                            working: root.busy === "reply"
                            onTriggered: if (replyField.text.trim() !== "") root.act("reply", [noteCard.modelData.id, replyField.text])
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------------
    // Componenten
    // ------------------------------------------------------------------------

    // Eén regel in de kaart Scherm: icoon, titel, uitleg en een aan/uit-knop.
    component ScreenRow: RowLayout {
        id: srow
        property string icon: ""
        property string title: ""
        property string detail: ""
        property bool active: false
        property string activeLabel: ""
        property string idleLabel: ""
        signal toggled()
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: Math.min(root.itemRadius, 16)
            color: Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, srow.active ? 0.28 : 0.12)
            Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("normal") } }
            Text {
                id: srowGlyph
                anchors.centerIn: parent
                text: srow.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 15
                color: mocha.accent3
                SequentialAnimation on opacity {
                    running: srow.active
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) srowGlyph.opacity = 1
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: srow.title
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: mocha.text
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: srow.detail
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                color: srow.active ? mocha.accent3 : mocha.subtext0
                wrapMode: Text.WordWrap
            }
        }
        PillButton {
            label: srow.active ? srow.activeLabel : srow.idleLabel
            icon: srow.active ? "󰓛" : "󰐊"
            accent: srow.active ? mocha.red : mocha.accent3
            primary: !srow.active
            onTriggered: srow.toggled()
        }
    }

    component IconButton: Rectangle {
        id: ib
        property string icon: ""
        property string tip: ""
        property color accent: mocha.text
        property bool spinning: false
        property bool highlighted: false
        signal triggered()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 16)
        color: ibMouse.containsMouse || highlighted
            ? Qt.rgba(accent.r, accent.g, accent.b, highlighted ? 0.24 : 0.20)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        scale: ibMouse.pressed ? 0.94 : (ibMouse.containsMouse ? 1.07 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Text {
            id: ibGlyph
            anchors.centerIn: parent
            text: ib.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 15
            color: ib.accent
            RotationAnimation on rotation {
                running: ib.spinning
                from: 0; to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) ibGlyph.rotation = 0
            }
        }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.triggered()
        }
    }

    component SmallButton: Rectangle {
        id: sb
        property string icon: ""
        property color accent: mocha.text
        signal triggered()
        width: 24
        height: 24
        radius: 12
        color: sbMouse.containsMouse
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.22)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Text {
            anchors.centerIn: parent
            text: sb.icon
            font.family: ThemeConfig.iconFont
            font.pixelSize: 12
            color: sbMouse.containsMouse ? sb.accent : mocha.subtext0
        }
        MouseArea {
            id: sbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sb.triggered()
        }
    }

    component InfoChip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property color tint: mocha.text
        width: chipRow.implicitWidth + 16
        height: 24
        radius: height / 2
        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 12
                color: chip.tint
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.Medium
                color: mocha.text
            }
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string label: ""
        property string icon: ""
        property color accent: mocha.primary
        property bool primary: false
        property bool working: false
        signal triggered()
        Layout.preferredHeight: 32
        Layout.preferredWidth: pillRow.implicitWidth + 24
        radius: 16
        color: primary
            ? Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse ? 0.34 : 0.24)
            : Qt.rgba(accent.r, accent.g, accent.b, pillMouse.containsMouse ? 0.18 : 0.08)
        border.width: 1
        border.color: Qt.rgba(accent.r, accent.g, accent.b, primary ? 0.55 : 0.25)
        scale: pillMouse.pressed ? 0.96 : 1.0
        opacity: working ? 0.7 : 1
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            Text {
                id: pillGlyph
                anchors.verticalCenter: parent.verticalCenter
                text: pill.working ? "󰑐" : pill.icon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 13
                color: pill.accent
                RotationAnimation on rotation {
                    running: pill.working
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) pillGlyph.rotation = 0
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: mocha.text
            }
        }
        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!pill.working) pill.triggered()
        }
    }

    // Tegel met icoon en label; draait tijdens het werk en toont kort een
    // vinkje als het gelukt is.
    component ActionTile: Rectangle {
        id: tile
        property string action: ""
        property string icon: ""
        property string label: ""
        property string tip: ""
        property color accent: mocha.primary
        property bool dimmed: false
        property bool toggled: false
        readonly property bool working: root.busy === action
        readonly property bool success: root.done === action
        signal triggered()

        Layout.fillWidth: true
        Layout.preferredHeight: 66
        radius: Math.min(root.itemRadius, 16)
        color: toggled || success
            ? Qt.rgba((success ? mocha.green : accent).r, (success ? mocha.green : accent).g, (success ? mocha.green : accent).b, 0.22)
            : (tileMouse.containsMouse
                ? Qt.rgba(accent.r, accent.g, accent.b, 0.14)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
        border.width: 1
        border.color: tileMouse.containsMouse || toggled
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.50)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
        scale: tileMouse.pressed ? 0.95 : (tileMouse.containsMouse ? 1.03 : 1.0)
        opacity: dimmed ? 0.5 : 1
        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width - 8
            spacing: 4
            Text {
                id: tileGlyph
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.success ? "󰄬" : (tile.working ? "󰑐" : tile.icon)
                font.family: ThemeConfig.iconFont
                font.pixelSize: 20
                color: tile.success ? mocha.green
                    : (tileMouse.containsMouse || tile.toggled ? tile.accent : mocha.subtext1)
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                RotationAnimation on rotation {
                    running: tile.working
                    from: 0; to: 360; duration: 900
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) tileGlyph.rotation = 0
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: tile.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
                color: tileMouse.containsMouse || tile.toggled ? mocha.text : mocha.subtext0
                elide: Text.ElideRight
                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
            }
        }

        // Uitleg bij hover, onder in de tegel.
        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!tile.working) tile.triggered()
        }
        ToolTipText { shown: tileMouse.containsMouse && tile.tip !== ""; tipText: tile.tip }
    }

    // Eenvoudige hint-ballon boven de tegel (geen QtQuick.Controls nodig).
    component ToolTipText: Rectangle {
        id: tipBox
        property bool shown: false
        property string tipText: ""
        z: 50
        width: Math.min(220, tipLabel.implicitWidth + 16)
        height: tipLabel.implicitHeight + 10
        radius: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        color: mocha.crust
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
        opacity: shown ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: tipBox.shown ? 450 : 0 }
                NumberAnimation { duration: ThemeConfig.durationToken("fast") }
            }
        }
        Text {
            id: tipLabel
            anchors.centerIn: parent
            width: Math.min(204, implicitWidth)
            text: tipBox.tipText
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            font.family: ThemeConfig.uiFont
            font.pixelSize: 10
            color: mocha.text
        }
    }

    component InputField: Rectangle {
        id: field
        property string placeholder: ""
        property color accent: mocha.primary
        property alias text: input.text
        signal accepted()
        function focusInput() { input.forceActiveFocus(); }
        Layout.preferredHeight: 32
        radius: Math.min(root.itemRadius, 12)
        color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
        border.width: 1
        border.color: input.activeFocus
            ? Qt.rgba(accent.r, accent.g, accent.b, 0.70)
            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
        Behavior on border.color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
        TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            font.family: ThemeConfig.uiFont
            font.pixelSize: 12
            color: mocha.text
            selectionColor: Qt.rgba(field.accent.r, field.accent.g, field.accent.b, 0.4)
            clip: true
            onAccepted: field.accepted()
            Keys.onEscapePressed: { root.smsOpen = false; root.replyTo = ""; }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === "" && !input.activeFocus
                text: field.placeholder
                font: input.font
                color: mocha.subtext0
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            acceptedButtons: Qt.LeftButton
            onPressed: (mouse) => { input.forceActiveFocus(); mouse.accepted = false; }
        }
    }
}
