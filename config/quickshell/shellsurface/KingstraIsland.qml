import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import ".."

// Het Kingstra-eiland: één plek midden onder de balk voor alle korte
// feedback, zoals Dynamic Island en Live Activities op macOS.
//
//   - volume, microfoon en helderheid (via hypr/scripts/osd.sh)
//   - nieuwe meldingen (in plaats van de losse kaartjes)
//   - live activiteiten: muziek die speelt, een schermopname, en stipjes
//     als de microfoon of camera in gebruik is
//
// Het eiland groeit uit de balk: de bovenhoeken lopen hol over in de rand,
// en de maat verandert met dezelfde vloeiende animatie als de panelen.
// Klik op de muziekpil om hem uit te klappen.
//
// Instellingen in ~/.local/state/kingstra/island.json:
//   { "osd": true, "notifications": true, "live": true }
// `kingstra eiland ...` schrijft dit. Met "notifications": false komen de
// oude kaartjes rechtsboven terug.
Item {
    id: root

    required property var shellWindow
    required property var mocha
    required property var chrome
    property string activeMode: "office"

    // Instellingen
    property bool osdEnabled: true
    property bool notificationsEnabled: true
    property bool liveEnabled: true
    readonly property bool handlesNotifications: notificationsEnabled
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/kingstra/island.json"

    // Plaats: onder de statusstrook, of erboven als die onderaan staat.
    readonly property bool fromBottom: ThemeConfig.barStatusStripEnabled && ThemeConfig.barStatusStripEdge === "bottom"
    readonly property int edgeInset: chrome.stripHeight
    readonly property int railLeftInset: ThemeConfig.barRailEnabled && ThemeConfig.barRailEdge === "left" ? chrome.railWidth : 0
    readonly property int railRightInset: ThemeConfig.barRailEnabled && ThemeConfig.barRailEdge === "right" ? chrome.railWidth : 0
    readonly property real centerX: railLeftInset + (parent.width - railLeftInset - railRightInset) / 2
    readonly property color fill: chrome._stripFillAt(centerX)

    // --- Toestand -------------------------------------------------------
    // mode: "" (weg), "live", "osd", "notif", "expanded"
    property string osdKind: ""
    property int osdValue: 0
    property bool osdMuted: false
    property bool osdActive: false
    property var currentNotif: null
    property var notifQueue: []
    property bool expanded: false
    property bool privacyMic: false
    property bool privacyCamera: false
    property bool privacyRecording: false

    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        return null;
    }
    readonly property bool mediaLive: liveEnabled && activePlayer !== null && ScreenProfiles.musicVisible(shellWindow.screen ? shellWindow.screen.name : "")
    readonly property bool privacyLive: liveEnabled && (privacyMic || privacyCamera || privacyRecording)
    readonly property bool hasLive: mediaLive || privacyLive

    // Aan zolang een paneel uit dezelfde rand groeit (bv. het
    // controlecentrum); dan maakt het eiland plaats.
    property bool suppressed: false

    readonly property string mode: {
        if (suppressed) return "";
        // Een toetsdruk gaat voor: je wilt meteen zien wat je deed.
        if (osdActive) return "osd";
        if (currentNotif !== null) return "notif";
        if (expanded && hasLive) return "expanded";
        if (hasLive) return "live";
        return "";
    }

    readonly property int targetWidth: mode === "notif" ? 440
        : mode === "osd" ? 320
        : mode === "expanded" ? 440
        : mode === "live" ? (mediaLive ? 260 : 120)
        : 140
    readonly property int targetHeight: mode === "notif" ? Math.max(72, notifContent.implicitHeight + 24)
        : mode === "osd" ? 48
        : mode === "expanded" ? expandedContent.implicitHeight + 28
        : mode === "live" ? 34
        : 0

    width: mode === "" && height < 1 ? 0 : visualWidth
    height: visualHeight
    x: centerX - width / 2
    y: fromBottom ? parent.height - edgeInset - height : edgeInset
    z: 35

    property real visualWidth: targetWidth
    property real visualHeight: targetHeight
    Behavior on visualWidth { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
    Behavior on visualHeight { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }

    function onFocusedScreen() {
        let monitor = Hyprland.monitorFor(shellWindow.screen);
        return monitor !== null && Hyprland.focusedMonitor !== null
            && Number(monitor.id) === Number(Hyprland.focusedMonitor.id);
    }

    function cleanText(value) {
        return String(value || "")
            .replace(/<br\s*\/?>/gi, " ")
            .replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&")
            .replace(/&lt;/g, "<")
            .replace(/&gt;/g, ">")
            .replace(/&quot;/g, "\"")
            .trim();
    }

    // --- Instellingen ---------------------------------------------------
    FileView {
        path: root.stateFile
        preload: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text() || "{}");
                root.osdEnabled = data.osd !== false;
                root.notificationsEnabled = data.notifications !== false;
                root.liveEnabled = data.live !== false;
            } catch (e) {}
        }
    }

    // --- OSD ------------------------------------------------------------
    property bool osdPrimed: false
    property string osdLastToken: ""

    function handleOsd(raw) {
        let payload;
        try {
            payload = JSON.parse(String(raw || "").trim());
        } catch (e) {
            return;
        }
        let token = String(payload.token || "");
        if (token === "") return;
        // Een oud bestand mag na een herstart geen OSD meer tonen.
        if (!osdPrimed) {
            osdPrimed = true;
            osdLastToken = token;
            let millis = Number(token.substring(0, 13));
            if (isNaN(millis) || Date.now() - millis > 2000) return;
        }
        if (token === osdLastToken) return;
        osdLastToken = token;
        if (!osdEnabled || !onFocusedScreen()) return;
        osdKind = String(payload.kind || "volume");
        osdValue = Math.max(0, Math.min(100, Number(payload.value)));
        osdMuted = payload.muted === true;
        osdActive = true;
        osdTimer.restart();
    }

    FileView {
        id: osdFile
        path: "/tmp/kingstra-island.json"
        watchChanges: true
        preload: true
        onInternalTextChanged: root.handleOsd(__text)
    }
    // FileView mist op Quickshell 0.3 geregeld een write; zelfde truc als
    // FeedbackToast. Het bestand is één korte regel.
    Timer {
        interval: 90
        running: root.osdEnabled
        repeat: true
        onTriggered: osdFile.reload()
    }
    Timer {
        id: osdTimer
        interval: 1600
        onTriggered: root.osdActive = false
    }

    readonly property string osdIcon: {
        if (osdKind === "brightness") return osdValue > 66 ? "󰃠" : (osdValue > 33 ? "󰃟" : "󰃞");
        if (osdKind === "mic") return osdMuted ? "󰍭" : "󰍬";
        if (osdKind === "caps") return "󰘲";
        if (osdMuted || osdValue === 0) return "󰝟";
        return osdValue > 66 ? "󰕾" : (osdValue > 33 ? "󰖀" : "󰕿");
    }
    readonly property string osdLabel: {
        if (osdKind === "brightness") return "Helderheid";
        if (osdKind === "mic") return osdMuted ? "Microfoon uit" : "Microfoon aan";
        if (osdKind === "caps") return osdMuted ? "Caps Lock aan" : "Caps Lock uit";
        return osdMuted ? "Gedempt" : "Volume";
    }
    readonly property bool osdShowsBar: osdKind === "volume" || osdKind === "brightness"

    // --- Meldingen ------------------------------------------------------
    function showNotification(notification) {
        if (!handlesNotifications || !notification || activeMode === "gaming" || !onFocusedScreen()) return;
        if (currentNotif === null) {
            currentNotif = notification;
            restartNotifTimer();
            return;
        }
        let q = notifQueue.slice();
        q.push(notification);
        while (q.length > 3) q.shift();
        notifQueue = q;
    }

    // Alleen doorschuiven als deze melding nog de huidige is; anders slaat
    // een klik plus het sluit-signaal er twee over.
    function advanceFrom(notification) {
        if (currentNotif === notification) nextNotification();
    }

    function nextNotification() {
        if (notifQueue.length === 0) {
            currentNotif = null;
            return;
        }
        let q = notifQueue.slice();
        currentNotif = q.shift();
        notifQueue = q;
        restartNotifTimer();
    }

    function restartNotifTimer() {
        let n = currentNotif;
        if (n && n.urgency === NotificationUrgency.Critical) {
            notifTimer.stop();
            return;
        }
        notifTimer.interval = n && n.expireTimeout > 0
            ? Math.max(3000, Math.min(10000, n.expireTimeout * 1000)) : 5000;
        notifTimer.restart();
    }

    Connections {
        target: NotificationService
        function onPopupRequested(notification) { root.showNotification(notification); }
    }
    Connections {
        target: root.currentNotif
        ignoreUnknownSignals: true
        function onClosed() { root.advanceFrom(root.currentNotif); }
    }
    Timer {
        id: notifTimer
        running: false
        onTriggered: {
            if (islandHover.hovered) restart();
            else root.nextNotification();
        }
    }

    // --- Privacy --------------------------------------------------------
    Process {
        id: probe
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/shellsurface/island-probe.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let d = JSON.parse(this.text.trim());
                    root.privacyMic = d.mic === true;
                    root.privacyCamera = d.camera === true;
                    root.privacyRecording = d.recording === true;
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 3000
        running: root.liveEnabled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    // Uitgeklapt eiland klapt vanzelf in als de muis weg is.
    Timer {
        id: collapseTimer
        interval: 1800
        onTriggered: root.expanded = false
    }
    onModeChanged: if (mode !== "expanded" && mode !== "notif") expanded = false

    // --- Vorm -----------------------------------------------------------
    readonly property real cornerR: Math.min(height / 2, 22)
    readonly property real filletR: Math.min(14, height)

    // Holle overgang links en rechts, zodat het eiland uit de strook groeit.
    Repeater {
        model: 2
        delegate: Canvas {
            required property int index
            readonly property bool isRightFillet: index === 1
            width: root.filletR
            height: root.filletR
            visible: root.height > 1
            x: isRightFillet ? root.width : -width
            y: root.fromBottom ? root.height - height : 0
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                // Vierkant min een kwartcirkel rond de hoek die van de strook
                // en het eiland af ligt: de holle overgang.
                ctx.fillStyle = root.fill;
                ctx.fillRect(0, 0, width, height);
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(isRightFillet ? width : 0, root.fromBottom ? 0 : height, width, 0, Math.PI * 2);
                ctx.fill();
                ctx.globalCompositeOperation = "source-over";
            }
            Connections {
                target: root
                function onFillChanged() { requestPaint(); }
                function onFilletRChanged() { requestPaint(); }
                function onFromBottomChanged() { requestPaint(); }
            }
        }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        color: root.fill
        topLeftRadius: root.fromBottom ? root.cornerR : 0
        topRightRadius: root.fromBottom ? root.cornerR : 0
        bottomLeftRadius: root.fromBottom ? 0 : root.cornerR
        bottomRightRadius: root.fromBottom ? 0 : root.cornerR
        clip: true

        // Dunne accentlijn langs de vrije rand.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.cornerR
            anchors.rightMargin: root.cornerR
            height: 2
            radius: 1
            y: root.fromBottom ? 0 : parent.height - height
            color: root.mode === "notif" && root.currentNotif && root.currentNotif.urgency === NotificationUrgency.Critical
                ? root.mocha.red : root.mocha.primary
            opacity: root.mode === "" ? 0 : 0.55
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
        }

        // --- Live pil ---------------------------------------------------
        RowLayout {
            id: liveContent
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 12
            spacing: 8
            opacity: root.mode === "live" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }

            Rectangle {
                visible: root.mediaLive
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                clip: true
                color: Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.25)
                Image {
                    anchors.fill: parent
                    source: root.activePlayer && root.activePlayer.trackArtUrl ? String(root.activePlayer.trackArtUrl) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 44
                    sourceSize.height: 44
                    asynchronous: true
                }
            }
            Text {
                visible: root.mediaLive
                Layout.fillWidth: true
                text: root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""
                elide: Text.ElideRight
                font.family: ThemeConfig.uiFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: root.mocha.text
            }
            Item { visible: !root.mediaLive; Layout.fillWidth: true }

            // Vaste geometrie: bewegende streepjes mogen de RowLayout of de
            // tekstbasis niet laten verspringen. Alleen hun tekeninhoud schaalt.
            Item {
                visible: root.mediaLive
                Layout.preferredWidth: 18
                Layout.preferredHeight: 16
                Layout.minimumWidth: 18
                Layout.maximumWidth: 18
                Layout.minimumHeight: 16
                Layout.maximumHeight: 16
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        x: index * 5
                        y: 1
                        width: 3
                        height: 14
                        radius: 1.5
                        color: root.mocha.primary
                        transform: Scale {
                            id: barScale
                            origin.x: 1.5
                            origin.y: 7
                            yScale: 0.45
                            SequentialAnimation on yScale {
                                running: root.visible && root.mode === "live" && root.mediaLive
                                loops: Animation.Infinite
                                NumberAnimation { to: (14 - index * 2) / 14; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                                NumberAnimation { to: (4 + index) / 14; duration: 300 + index * 50; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            // Privacy-stipjes: oranje = microfoon, groen = camera, rood = opname.
            Row {
                spacing: 4
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: [
                        { on: root.privacyMic, color: root.mocha.peach },
                        { on: root.privacyCamera, color: root.mocha.green },
                        { on: root.privacyRecording, color: root.mocha.red }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        visible: modelData.on
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.color
                        SequentialAnimation on opacity {
                            running: modelData.on
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }

        // --- OSD --------------------------------------------------------
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            opacity: root.mode === "osd" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }

            Text {
                text: root.osdIcon
                font.family: ThemeConfig.iconFont
                font.pixelSize: 18
                color: root.osdMuted && root.osdKind !== "caps" ? root.mocha.subtext0 : root.mocha.primary
            }
            Text {
                visible: !root.osdShowsBar
                Layout.fillWidth: true
                text: root.osdLabel
                font.family: ThemeConfig.uiFont
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: root.mocha.text
            }
            Rectangle {
                visible: root.osdShowsBar
                Layout.fillWidth: true
                Layout.preferredHeight: 8
                radius: 4
                color: Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.12)
                Rectangle {
                    width: parent.width * (root.osdMuted ? 0 : root.osdValue / 100)
                    height: parent.height
                    radius: 4
                    color: root.mocha.primary
                    Behavior on width { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") } }
                }
            }
            Text {
                visible: root.osdShowsBar
                Layout.preferredWidth: 30
                horizontalAlignment: Text.AlignRight
                text: root.osdMuted ? "—" : String(root.osdValue)
                font.family: ThemeConfig.monoFont
                font.pixelSize: 12
                font.weight: Font.Bold
                color: root.mocha.text
            }
        }

        // --- Melding ----------------------------------------------------
        RowLayout {
            id: notifContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12
            opacity: root.mode === "notif" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("fast") } }

            readonly property var n: root.currentNotif

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                Layout.alignment: Qt.AlignTop
                radius: 12
                color: Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.16)
                Image {
                    id: notifIcon
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    sourceSize.width: 48
                    sourceSize.height: 48
                    source: NotificationService.iconSource(notifContent.n)
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !notifIcon.visible
                    text: String(notifContent.n && notifContent.n.appName ? notifContent.n.appName : "?").charAt(0).toUpperCase()
                    font.family: ThemeConfig.displayFont
                    font.pixelSize: 15
                    font.weight: Font.Black
                    color: root.mocha.primary
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: notifContent.n ? String(notifContent.n.summary || notifContent.n.appName || "Melding") : ""
                        elide: Text.ElideRight
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: root.mocha.text
                    }
                    Text {
                        text: root.notifQueue.length > 0 ? "+" + root.notifQueue.length : (notifContent.n ? String(notifContent.n.appName || "") : "")
                        visible: text !== ""
                        Layout.maximumWidth: 110
                        elide: Text.ElideRight
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 10
                        color: root.mocha.subtext0
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: notifContent.n ? root.cleanText(notifContent.n.body) : ""
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.family: ThemeConfig.uiFont
                    font.pixelSize: 11
                    color: root.mocha.subtext1
                }
            }
        }

        // --- Uitgeklapt -------------------------------------------------
        ColumnLayout {
            id: expandedContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 10
            opacity: root.mode === "expanded" ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }

            RowLayout {
                visible: root.mediaLive
                Layout.fillWidth: true
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 14
                    clip: true
                    color: Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.2)
                    Image {
                        anchors.fill: parent
                        source: root.activePlayer && root.activePlayer.trackArtUrl ? String(root.activePlayer.trackArtUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 128
                        sourceSize.height: 128
                        asynchronous: true
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""
                        elide: Text.ElideRight
                        font.family: ThemeConfig.displayFont
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        color: root.mocha.text
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.activePlayer ? String(root.activePlayer.trackArtist || "") : ""
                        visible: text !== ""
                        elide: Text.ElideRight
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 11
                        color: root.mocha.subtext0
                    }
                    Row {
                        Layout.topMargin: 6
                        spacing: 8
                        Repeater {
                            model: [
                                { icon: "󰒮", act: "prev" },
                                { icon: "󰏤", act: "toggle" },
                                { icon: "󰒭", act: "next" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                width: 36
                                height: 28
                                radius: 14
                                color: ctl.containsMouse
                                    ? Qt.rgba(root.mocha.primary.r, root.mocha.primary.g, root.mocha.primary.b, 0.26)
                                    : Qt.rgba(root.mocha.text.r, root.mocha.text.g, root.mocha.text.b, 0.08)
                                Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon
                                    font.family: ThemeConfig.iconFont
                                    font.pixelSize: 14
                                    color: root.mocha.text
                                }
                                MouseArea {
                                    id: ctl
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let p = root.activePlayer;
                                        if (!p) return;
                                        if (modelData.act === "prev" && p.canGoPrevious) p.previous();
                                        else if (modelData.act === "next" && p.canGoNext) p.next();
                                        else if (modelData.act === "toggle" && p.canTogglePlaying) p.togglePlaying();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Repeater {
                model: [
                    { on: root.privacyMic, icon: "󰍬", text: "Microfoon in gebruik", color: root.mocha.peach },
                    { on: root.privacyCamera, icon: "󰄀", text: "Camera in gebruik", color: root.mocha.green },
                    { on: root.privacyRecording, icon: "󰑋", text: "Schermopname loopt", color: root.mocha.red }
                ]
                delegate: RowLayout {
                    required property var modelData
                    visible: modelData.on
                    spacing: 8
                    Text {
                        text: modelData.icon
                        font.family: ThemeConfig.iconFont
                        font.pixelSize: 14
                        color: modelData.color
                    }
                    Text {
                        text: modelData.text
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 12
                        color: root.mocha.text
                    }
                }
            }
        }
    }

    // --- Interactie -----------------------------------------------------
    HoverHandler {
        id: islandHover
        onHoveredChanged: {
            if (hovered) collapseTimer.stop();
            else if (root.expanded) collapseTimer.restart();
        }
    }

    // Links: melding openen of de pil uitklappen. Rechts: melding weg.
    // Midden: alleen dit eiland-bericht sluiten.
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            if (root.mode === "notif") {
                let n = root.currentNotif;
                if (NotificationService.invokeDefault(n)) NotificationService.dismiss(n);
                else Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "notifications"]);
                root.advanceFrom(n);
            } else if (root.mode === "live") {
                root.expanded = true;
            } else if (root.mode === "osd" && (root.osdKind === "volume" || root.osdKind === "mic")) {
                root.osdActive = false;
                Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "volume"]);
            }
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            if (root.mode === "notif") NotificationService.dismiss(root.currentNotif);
            else root.expanded = false;
        }
    }
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: {
            if (root.mode === "notif") root.advanceFrom(root.currentNotif);
            else if (root.mode === "osd") root.osdActive = false;
        }
    }
}
