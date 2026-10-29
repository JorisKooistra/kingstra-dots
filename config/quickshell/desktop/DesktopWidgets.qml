import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../"
import "../shellsurface"

// Bureaubladwidgets, zoals bij DankMaterialShell en KDE: een grote klok en,
// als er iets speelt, een mediakaart direct op de wallpaper. Ze staan op de
// Bottom-laag: boven de wallpaper, onder alle vensters, dus je ziet ze op
// een lege werkruimte. Kleuren en lettertype volgen het thema.
//
// Instellingen in ~/.local/state/kingstra/desktop-widgets.json:
//   { "enabled": true, "clock": "top-left", "media": true, "vinylSaver": 120 }
// clock: top-left, top-right, center, bottom-left, bottom-right.
// `kingstra widgets aan|uit|klok <plek>` en het toetsenbordmenu schrijven dit.
//
// De knop op de mediakaart (of `kingstra vinyl`) opent VinylStage: de speler
// van de kaart schermvullend in perspectief, als een screensaver. Welke
// speler (draaitafel, cassettespeler of discman) kies je per scherm in
// Super+A (playerStyle); `kingstra cassette` en `kingstra discman` openen
// die meteen groot.
Scope {
    id: root

    property bool enabled: true
    property string clockPos: "top-left"
    property bool showMedia: true
    property bool vinylMode: true
    // Seconden zonder invoer (met muziek aan) voor de draaitafel-screensaver; 0 = uit.
    property real saverSeconds: 120

    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/kingstra/desktop-widgets.json"

    FileView {
        id: desktopStateFile
        path: root.stateFile
        preload: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text() || "{}");
                root.enabled = data.enabled !== false;
                root.clockPos = String(data.clock || "top-left");
                root.showMedia = data.media !== false;
                root.saverSeconds = data.vinylSaver !== undefined ? Math.max(0, Number(data.vinylSaver) || 0) : 120;
            } catch (e) {}
        }
    }

    // Zelfde keuze als in Geluid & media: plaat of hoes.
    FileView {
        id: mediaStyleFile
        path: Quickshell.env("HOME") + "/.local/state/kingstra/media-view"
        preload: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.vinylMode = String(text() || "").trim() !== "cover"
    }

    // Toerental van de draaitafel (33 of 45), gedeeld door de kleine speler
    // en de grote, en onthouden. 45 laat een single zien.
    property int vinylRpm: 33
    readonly property string rpmFile: Quickshell.env("HOME") + "/.local/state/kingstra/vinyl-rpm"
    FileView {
        id: rpmStateFile
        path: root.rpmFile
        preload: true
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.vinylRpm = String(text() || "").trim() === "45" ? 45 : 33
    }
    function setVinylRpm(value) {
        let rpm = value === 45 ? 45 : 33;
        if (rpm === root.vinylRpm) return;
        root.vinylRpm = rpm;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh", root.rpmFile, String(rpm)]);
    }

    Timer { interval: 1000; repeat: true; running: true; onTriggered: { desktopStateFile.reload(); mediaStyleFile.reload(); } }

    property var now: new Date()
    Timer {
        interval: 1000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // Mpris werkt `position` niet zelf bij; zonder dit staat de arm stil.
            if (root.activePlayer && root.activePlayer.positionSupported) root.activePlayer.positionChanged();
            root.now = new Date();
        }
    }

    // De speler die speelt, anders een gepauzeerde met een titel: zo blijft
    // de kaart staan na pauze en kun je hem hier ook weer starten.
    readonly property var activePlayer: {
        let players = Mpris.players.values;
        for (let i = 0; i < players.length; i++) {
            if (players[i].playbackState === MprisPlaybackState.Playing) return players[i];
        }
        for (let i = 0; i < players.length; i++) {
            if (String(players[i].trackTitle || "").trim() !== "") return players[i];
        }
        return null;
    }
    readonly property bool playing: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool mediaTracking: {
        let p = activePlayer;
        return p !== null && p.lengthSupported && p.length > 0;
    }
    readonly property real mediaProgress: {
        let tick = now;
        let p = activePlayer;
        if (!p || !p.positionSupported || !p.lengthSupported || p.length <= 0)
            return 0;
        return Math.max(0, Math.min(1, p.position / p.length));
    }

    // Album (of anders de hoes): verandert dit, dan wisselt de plaat.
    readonly property string mediaTrackKey: {
        let p = activePlayer;
        if (!p) return "";
        let album = String(p.trackAlbum || "").trim();
        return album !== "" ? album : String(p.trackArtUrl || "");
    }
    readonly property bool mediaCanSeek: {
        let p = activePlayer;
        return p !== null && p.canSeek && p.positionSupported && mediaTracking;
    }
    function mediaSeek(fraction) {
        let p = activePlayer;
        if (!p || !mediaCanSeek) return;
        p.position = Math.max(0, Math.min(1, fraction)) * p.length;
    }
    function mediaToggle() {
        let p = activePlayer;
        if (!p) return;
        if (p.canTogglePlaying) p.togglePlaying();
        else if (p.canPlay) p.play();
    }

    // Systeemvolume voor de schuif op de draaitafel.
    readonly property var audioSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: root.audioSink ? [root.audioSink] : [] }
    readonly property real mediaVolume: audioSink && audioSink.audio && audioSink.ready ? audioSink.audio.volume : -1
    function setMediaVolume(v) {
        if (!audioSink || !audioSink.audio) return;
        audioSink.audio.muted = false;
        audioSink.audio.volume = Math.max(0, Math.min(1, v));
    }

    // --- Schermvullende draaitafel -----------------------------------------
    property bool stageOpen: false
    // Blijft geladen tot het sluiten is uitgefadet.
    property bool stageAlive: false
    // De grote speler staat op het scherm en ligt over de kleine heen; pas
    // dan verdwijnt de kleine, anders knippert het.
    property bool stageCovering: false
    property var stageScreen: null
    // Waar de kleine speler op het scherm staat; de grote groeit daaruit.
    property rect stageOrigin: Qt.rect(0, 0, 0, 0)
    // Welke speler groot wordt: vinyl, cassette of discman.
    property string stageDevice: "vinyl"
    // Stand van plaat, spoelen of cd van de kleine speler.
    property var stageSpin: ({})
    property var deckItems: ({})
    function registerDeck(name, item) {
        let d = Object.assign({}, deckItems);
        d[name] = item;
        deckItems = d;
    }
    Component.onCompleted: Hyprland.refreshMonitors()
    function deviceFor(style) {
        return style === "cassette" || style === "discman" ? style
            : style === "cover" ? "" : style === "vinyl" ? "vinyl" : (root.vinylMode ? "vinyl" : "");
    }
    // kind leeg: de speler die op de kaart staat (of de draaitafel).
    function openStage(kind) {
        let mon = Hyprland.focusedMonitor;
        let screens = Quickshell.screens;
        let pick = screens.length > 0 ? screens[0] : null;
        for (let i = 0; mon && i < screens.length; i++) {
            if (screens[i].name === mon.name) pick = screens[i];
        }
        stageScreen = pick;
        stageOrigin = Qt.rect(0, 0, 0, 0);
        stageSpin = ({});
        let slot = pick ? deckItems[pick.name] : null;
        let shown = slot ? slot.device : "";
        stageDevice = kind ? kind : (shown !== "" ? shown : "vinyl");
        let deck = slot && shown === stageDevice ? slot.activeDeck : null;
        if (deck && deck.visible && deck.opacity > 0.5 && deck.width > 0 && slot.parentCard.shown) {
            // Het bureaubladvenster begint na gereserveerde ruimte (bar, rail);
            // het schermvullende venster op 0,0. Hyprland kent die marges.
            let hm = Hyprland.monitorFor(pick);
            let ipc = hm ? hm.lastIpcObject : null;
            let res = ipc && ipc.reserved ? ipc.reserved : [0, 0, 0, 0];
            let p = deck.mapToItem(null, 0, 0);
            stageOrigin = Qt.rect(p.x + Number(res[0] || 0), p.y + Number(res[1] || 0), deck.width, deck.height);
            stageSpin = stageDevice === "vinyl" ? { a: deck.vinyl.discAngle } : deck.spinState();
        }
        Hyprland.refreshMonitors();
        stageAlive = true;
        stageOpen = true;
    }
    IpcHandler {
        target: "vinyl"
        function open() { root.openStage() }
        function close() { root.stageOpen = false }
        function toggle() { if (root.stageOpen) root.stageOpen = false; else root.openStage(); }
        function cassette() { root.toggleStage("cassette") }
        function discman() { root.toggleStage("discman") }
        function turntable() { root.toggleStage("vinyl") }
    }
    function toggleStage(kind) {
        if (root.stageOpen && root.stageDevice === kind) root.stageOpen = false;
        else if (!root.stageOpen) root.openStage(kind);
    }
    LazyLoader {
        active: root.saverSeconds > 0
        source: "VinylSaverIdle.qml"
        onItemChanged: if (item) {
            item.host = root;
            item.timeout = Qt.binding(() => root.saverSeconds);
        }
    }
    LazyLoader {
        active: root.stageAlive
        VinylStage {
            host: root
            screen: root.stageScreen
            open: root.stageOpen
            onFinished: { root.stageCovering = false; root.stageAlive = false; }
        }
    }

    Variants {
        model: root.enabled ? Quickshell.screens : []

        delegate: Component {
            PanelWindow {
                id: win
                required property var modelData
                screen: modelData

                anchors { top: true; bottom: true; left: true; right: true }
                color: "transparent"

                WlrLayershell.namespace: "quickshell:kingstra-desktop-widgets"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.exclusiveZone: 0
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                // Alleen de widgets zelf zijn klikbaar; de rest van het
                // bureaublad blijft gewoon van de wallpaper en de vensters.
                mask: Region {
                    Region { item: clock }
                    Region { item: mediaCard }
                }

                MatugenColors { id: mocha }

                readonly property var nl: Qt.locale("nl_NL")
                readonly property int margin: 96

                // --- Klok ------------------------------------------------------
                Item {
                    id: clock
                    width: clockCol.implicitWidth
                    height: clockCol.implicitHeight
                    x: root.clockPos.indexOf("right") !== -1 ? win.width - width - win.margin
                        : (root.clockPos === "center" ? (win.width - width) / 2 : win.margin)
                    y: root.clockPos.indexOf("bottom") !== -1 ? win.height - height - win.margin
                        : (root.clockPos === "center" ? (win.height - height) / 2 - 40 : win.margin)
                    Behavior on x { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
                    Behavior on y { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.55)
                        shadowBlur: 0.8
                        shadowVerticalOffset: 3
                    }

                    ColumnLayout {
                        id: clockCol
                        spacing: -6
                        readonly property int align: root.clockPos.indexOf("right") !== -1 ? Qt.AlignRight
                            : (root.clockPos === "center" ? Qt.AlignHCenter : Qt.AlignLeft)
                        Text {
                            Layout.alignment: clockCol.align
                            text: Qt.formatDateTime(root.now, "HH:mm")
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 112
                            font.weight: Font.Black
                            color: mocha.text
                        }
                        Text {
                            Layout.alignment: clockCol.align
                            text: root.now.toLocaleDateString(win.nl, "dddd d MMMM")
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            color: mocha.primary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "toggle", "calendar"])
                    }
                }

                // --- Media -----------------------------------------------------
                // Onder de klok, of erboven als de klok onderaan staat.
                Rectangle {
                    id: mediaCard
                    readonly property bool shown: root.showMedia && root.activePlayer !== null && ScreenProfiles.profile(win.screen ? win.screen.name : "").desktopMedia
                    width: deckSlot.device === "vinyl" || deckSlot.device === "cassette" ? 460 : deckSlot.device === "discman" ? 424 : 420
                    height: 148
                    Behavior on width { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
                    radius: Math.max(16, ThemeConfig.styleWidgetRadius + 6)
                    x: root.clockPos.indexOf("right") !== -1 ? win.width - width - win.margin
                        : (root.clockPos === "center" ? (win.width - width) / 2 : win.margin)
                    y: root.clockPos.indexOf("bottom") !== -1 ? clock.y - height - 18 : clock.y + clock.height + 18
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.62)
                    border.width: 1
                    border.color: Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.30)
                    opacity: shown ? 1 : 0
                    scale: shown ? 1 : 0.94
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("normal"); easing.type: ThemeConfig.easingToken("emphasized") } }

                    // Schermvullende draaitafel openen.
                    Rectangle {
                        z: 2
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 26
                        height: 26
                        radius: 13
                        color: stageMouse.containsMouse
                            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.26)
                            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                        scale: stageMouse.pressed ? 0.92 : 1
                        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                        Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: Easing.OutCubic } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰊓"
                            font.family: ThemeConfig.iconFont
                            font.pixelSize: 13
                            color: mocha.text
                        }
                        MouseArea {
                            id: stageMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openStage()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        anchors.rightMargin: 40
                        spacing: 12

                        // Draaitafel, cassettespeler of discman (zelfde vorm als
                        // de schermvullende), of de hoes.
                        Item {
                            id: deckSlot
                            readonly property string style: ScreenProfiles.profile(win.screen ? win.screen.name : "").playerStyle
                            readonly property string device: root.deviceFor(style)
                            readonly property bool turntable: device === "vinyl"
                            readonly property var activeDeck: device === "cassette" ? miniCassette : device === "discman" ? miniDisc : miniDeck
                            readonly property var parentCard: mediaCard
                            // Onder de schermvullende speler weg, die hier uit groeit.
                            readonly property bool covered: root.stageCovering && root.stageScreen === win.screen
                            Layout.preferredWidth: device === "vinyl" || device === "cassette" ? 160 : device === "discman" ? 124 : 120
                            Layout.preferredHeight: 124
                            Component.onCompleted: root.registerDeck(win.screen ? win.screen.name : "", deckSlot)

                            TurntableDeck {
                                id: miniDeck
                                anchors.centerIn: parent
                                width: 160
                                height: 124
                                compact: true
                                mocha: mocha
                                accent: mocha.primary
                                artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? String(root.activePlayer.trackArtUrl) : ""
                                trackKey: root.mediaTrackKey
                                playing: root.playing
                                tracking: root.mediaTracking
                                progress: root.mediaProgress
                                canSeek: root.mediaCanSeek
                                volume: root.mediaVolume
                                rpm: root.vinylRpm
                                onRpmRequested: value => root.setVinylRpm(value)
                                onVolumeRequested: value => root.setMediaVolume(value)
                                onTogglePlay: root.mediaToggle()
                                onSeek: fraction => root.mediaSeek(fraction)
                                opacity: !deckSlot.turntable ? 0 : (deckSlot.covered ? 0 : 1)
                                visible: opacity > 0.01
                                scale: deckSlot.turntable ? 1 : 0.9
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
                            }
                            CassetteDeck {
                                id: miniCassette
                                anchors.centerIn: parent
                                width: 160
                                height: 114
                                compact: true
                                mocha: mocha
                                accent: mocha.primary
                                title: root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""
                                artist: root.activePlayer ? String(root.activePlayer.trackArtist || "") : ""
                                playing: root.playing
                                position: root.mediaTracking ? root.mediaProgress : 0
                                onTogglePlay: root.mediaToggle()
                                opacity: deckSlot.device !== "cassette" ? 0 : (deckSlot.covered ? 0 : 1)
                                visible: opacity > 0.01
                                scale: deckSlot.device === "cassette" ? 1 : 0.9
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
                            }
                            DiscDeck {
                                id: miniDisc
                                anchors.centerIn: parent
                                width: 124
                                height: 124
                                compact: true
                                mocha: mocha
                                accent: mocha.primary
                                artUrl: miniDeck.artUrl
                                playing: root.playing
                                tracking: root.mediaTracking
                                position: root.mediaProgress
                                length: root.activePlayer && root.activePlayer.lengthSupported ? Number(root.activePlayer.length || 0) : 0
                                onTogglePlay: root.mediaToggle()
                                opacity: deckSlot.device !== "discman" ? 0 : (deckSlot.covered ? 0 : 1)
                                visible: opacity > 0.01
                                scale: deckSlot.device === "discman" ? 1 : 0.9
                                Behavior on scale { NumberAnimation { duration: ThemeConfig.durationToken("spatial"); easing.type: ThemeConfig.easingToken("emphasized") } }
                            }
                            MediaVinyl {
                                anchors.centerIn: parent
                                width: 120
                                height: 120
                                mocha: mocha
                                accent: mocha.primary
                                artUrl: miniDeck.artUrl
                                playing: root.playing
                                vinylMode: false
                                showArm: false
                                coverRadius: 16
                                opacity: deckSlot.device !== "" ? 0 : 1
                                visible: opacity > 0.01
                                Behavior on opacity { NumberAnimation { duration: ThemeConfig.durationToken("normal") } }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: root.activePlayer ? String(root.activePlayer.trackTitle || "") : ""
                                font.family: ThemeConfig.displayFont
                                font.pixelSize: 15
                                font.weight: Font.Bold
                                color: mocha.text
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.activePlayer ? String(root.activePlayer.trackArtist || "") : ""
                                visible: text !== ""
                                font.family: ThemeConfig.uiFont
                                font.pixelSize: 11
                                color: mocha.subtext0
                                elide: Text.ElideRight
                            }
                            Row {
                                Layout.topMargin: 4
                                spacing: 6
                                Repeater {
                                    model: [
                                        { icon: "󰒮", act: "prev" },
                                        { icon: root.playing ? "󰏤" : "󰐊", act: "toggle" },
                                        { icon: "󰒭", act: "next" }
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 30
                                        height: 26
                                        radius: 13
                                        color: btnMouse.containsMouse
                                            ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.26)
                                            : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                                        Behavior on color { ColorAnimation { duration: ThemeConfig.durationToken("fast") } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.icon
                                            font.family: ThemeConfig.iconFont
                                            font.pixelSize: 13
                                            color: mocha.text
                                        }
                                        MouseArea {
                                            id: btnMouse
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
                }
            }
        }
    }
}
