import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../"
import "../shellsurface"

// Bureaubladwidgets, zoals bij DankMaterialShell en KDE: een grote klok en,
// als er iets speelt, een mediakaart direct op de wallpaper. Ze staan op de
// Bottom-laag: boven de wallpaper, onder alle vensters, dus je ziet ze op
// een lege werkruimte. Kleuren en lettertype volgen het thema.
//
// Instellingen in ~/.local/state/kingstra/desktop-widgets.json:
//   { "enabled": true, "clock": "top-left", "media": true }
// clock: top-left, top-right, center, bottom-left, bottom-right.
// `kingstra widgets aan|uit|klok <plek>` en het toetsenbordmenu schrijven dit.
//
// De vinylknop op de mediakaart (of `kingstra vinyl`) opent VinylStage: de
// draaitafel schermvullend in perspectief, als een screensaver.
Scope {
    id: root

    property bool enabled: true
    property string clockPos: "top-left"
    property bool showMedia: true
    property bool vinylMode: true

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

    // --- Schermvullende draaitafel -----------------------------------------
    property bool stageOpen: false
    // Blijft geladen tot het sluiten is uitgefadet.
    property bool stageAlive: false
    property var stageScreen: null
    function openStage() {
        let mon = Hyprland.focusedMonitor;
        let screens = Quickshell.screens;
        let pick = screens.length > 0 ? screens[0] : null;
        for (let i = 0; mon && i < screens.length; i++) {
            if (screens[i].name === mon.name) pick = screens[i];
        }
        stageScreen = pick;
        stageAlive = true;
        stageOpen = true;
    }
    IpcHandler {
        target: "vinyl"
        function open() { root.openStage() }
        function close() { root.stageOpen = false }
        function toggle() { if (root.stageOpen) root.stageOpen = false; else root.openStage(); }
    }
    LazyLoader {
        active: root.stageAlive
        VinylStage {
            host: root
            screen: root.stageScreen
            open: root.stageOpen
            onFinished: root.stageAlive = false
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
                    width: 420
                    height: 148
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

                        MediaVinyl {
                            Layout.preferredWidth: 120
                            Layout.preferredHeight: 120
                            mocha: mocha
                            accent: mocha.primary
                            artUrl: root.activePlayer && root.activePlayer.trackArtUrl ? String(root.activePlayer.trackArtUrl) : ""
                            playing: root.playing
                            playerStyle: ScreenProfiles.profile(win.screen ? win.screen.name : "").playerStyle
                            vinylMode: playerStyle === "cover" ? false : playerStyle === "vinyl" ? true : root.vinylMode
                            showArm: true
                            progress: root.mediaProgress
                            tracking: root.mediaTracking
                            trackKey: root.mediaTrackKey
                            canSeek: root.mediaCanSeek
                            onSeekRequested: fraction => root.mediaSeek(fraction)
                            coverRadius: 16
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
