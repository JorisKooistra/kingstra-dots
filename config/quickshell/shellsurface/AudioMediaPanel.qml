import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import ".."

// Geluid & media: volume, microfoon en de lopende speler in één paneel, zoals
// de media/volume-widgets van Caelestia. De rail heeft hiervoor een eigen
// tegel; netwerk en batterij staan daar los van in de statustegel.
// Het volledige volume- en muziekpaneel blijven bereikbaar via de pijltjes.
// De vorm (blob, hoeken, groei-animatie) komt volledig uit PanelHost.
Item {
    id: root

    MatugenColors { id: mocha }

    signal panelSwitchRequested(string entryId)

    readonly property int pad: 16
    readonly property int itemRadius: Math.max(10, Math.min(16, ThemeConfig.styleWidgetRadius))
    readonly property int preferredPanelWidth: 420
    readonly property int preferredPanelHeight: Math.ceil(content.implicitHeight + pad * 2)

    // --- Speler --------------------------------------------------------------
    // Zelfde voorkeur als de rail: eerst wat speelt, dan een gepauzeerde speler
    // met titel. Met meerdere spelers kun je hier doorschakelen.
    property string pinnedIdentity: ""
    readonly property var players: Mpris.players.values
    readonly property var player: {
        let list = players;
        if (list.length === 0) return null;
        if (pinnedIdentity !== "") {
            for (let i = 0; i < list.length; i++) {
                if (String(list[i].identity || "") === pinnedIdentity) return list[i];
            }
        }
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        for (let i = 0; i < list.length; i++) {
            if (String(list[i].trackTitle || "").trim() !== "") return list[i];
        }
        return list[0];
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle: hasPlayer
        ? (String(player.trackTitle || "").trim() !== "" ? String(player.trackTitle) : String(player.identity || "Media"))
        : ""
    readonly property string trackArtist: hasPlayer ? String(player.trackArtist || "") : ""
    readonly property real trackLength: hasPlayer && player.lengthSupported ? Number(player.length || 0) : 0
    readonly property bool canSeek: hasPlayer && player.canSeek && player.positionSupported && trackLength > 0
    property real trackPosition: 0
    property bool draggingSeek: false

    function cyclePlayer() {
        let list = players;
        if (list.length < 2) return;
        let idx = list.indexOf(player);
        root.pinnedIdentity = String(list[(idx + 1) % list.length].identity || "");
    }

    function formatTime(seconds) {
        let s = Math.max(0, Math.floor(seconds || 0));
        let m = Math.floor(s / 60);
        let rest = s % 60;
        return m + ":" + (rest < 10 ? "0" : "") + rest;
    }

    // Mpris werkt `position` niet zelf bij; zonder deze tik staat de
    // voortgangsbalk stil.
    Timer {
        interval: 1000
        running: root.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.hasPlayer || root.draggingSeek) return;
            root.player.positionChanged();
            root.trackPosition = Number(root.player.position || 0);
        }
    }

    // --- Audio (wpctl, net als de rail) -------------------------------------
    property int volume: 0
    property bool muted: false
    property int micVolume: 0
    property bool micMuted: false
    property bool micKnown: false
    property string sinkName: ""
    property bool draggingVolume: false
    property bool draggingMic: false

    function setVolume(target, percent) {
        let v = Math.max(0, Math.min(100, Math.round(percent)));
        if (target === "@DEFAULT_AUDIO_SINK@") root.volume = v;
        else root.micVolume = v;
        Quickshell.execDetached(["wpctl", "set-volume", target, v + "%"]);
    }

    function toggleMute(target) {
        if (target === "@DEFAULT_AUDIO_SINK@") root.muted = !root.muted;
        else root.micMuted = !root.micMuted;
        Quickshell.execDetached(["wpctl", "set-mute", target, "toggle"]);
        refreshSoon.restart();
    }

    function refresh() {
        if (!audioPoller.running) audioPoller.running = true;
    }

    Component.onCompleted: refresh()

    Process {
        id: audioPoller
        command: ["bash", "-lc",
            "sink=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | head -n1); " +
            "src=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | head -n1); " +
            "name=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk -F'\"' '/node.description/{print $2; exit}'); " +
            "printf 'sink=%s\\nsrc=%s\\nname=%s\\n' \"$sink\" \"$src\" \"$name\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let state = {};
                let lines = this.text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let eq = lines[i].indexOf("=");
                    if (eq > 0) state[lines[i].substring(0, eq)] = lines[i].substring(eq + 1).trim();
                }

                let sink = state.sink || "";
                let sinkMatch = sink.match(/Volume:\s+([\d.]+)/);
                if (sinkMatch && !root.draggingVolume) root.volume = Math.round(parseFloat(sinkMatch[1]) * 100);
                root.muted = sink.indexOf("[MUTED]") !== -1;

                let source = state.src || "";
                let srcMatch = source.match(/Volume:\s+([\d.]+)/);
                root.micKnown = srcMatch !== null;
                if (srcMatch && !root.draggingMic) root.micVolume = Math.round(parseFloat(srcMatch[1]) * 100);
                root.micMuted = source.indexOf("[MUTED]") !== -1;

                root.sinkName = state.name || "";
            }
        }
    }

    Timer {
        id: refreshSoon
        interval: 300
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: 12

        // --- Kop -------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: "Geluid & media"
                font.family: ThemeConfig.displayFont
                font.pixelSize: 17
                font.weight: Font.Black
                color: mocha.text
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.sinkName
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                color: mocha.subtext0
                elide: Text.ElideRight
            }
        }

        // --- Mediakaart ------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: mediaColumn.implicitHeight + 20
            radius: root.itemRadius
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.26)
            border.width: 1
            border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)

            ColumnLayout {
                id: mediaColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: Math.min(root.itemRadius, 14)
                        color: Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, 0.14)
                        clip: true

                        Image {
                            id: cover
                            anchors.fill: parent
                            source: root.hasPlayer && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                            asynchronous: true
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: cover.status !== Image.Ready
                            text: "󰎆"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: 26
                            color: mocha.accent3
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? root.trackTitle : "Geen media actief"
                            font.family: ThemeConfig.displayFont
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            color: mocha.text
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.trackArtist
                            font.family: ThemeConfig.uiFont
                            font.pixelSize: 11
                            color: mocha.subtext0
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.topMargin: 4
                            spacing: 6

                            CtlButton {
                                visible: root.hasPlayer
                                icon: "󰒮"
                                enabled: root.hasPlayer && root.player.canGoPrevious
                                onTriggered: root.player.previous()
                            }
                            CtlButton {
                                visible: root.hasPlayer
                                primary: true
                                icon: root.playing ? "󰏤" : "󰐊"
                                enabled: root.hasPlayer && (root.player.canTogglePlaying || root.player.canPlay)
                                onTriggered: {
                                    if (root.player.canTogglePlaying) root.player.togglePlaying();
                                    else root.player.play();
                                }
                            }
                            CtlButton {
                                visible: root.hasPlayer
                                icon: "󰒭"
                                enabled: root.hasPlayer && root.player.canGoNext
                                onTriggered: root.player.next()
                            }
                            Item { Layout.fillWidth: true }
                            CtlButton {
                                visible: root.players.length > 1
                                icon: "󰓃"
                                label: root.hasPlayer ? String(root.player.identity || "") : ""
                                onTriggered: root.cyclePlayer()
                            }
                            CtlButton {
                                icon: "󰅂"
                                onTriggered: root.panelSwitchRequested("music")
                            }
                        }
                    }
                }

                PanelSlider {
                    mocha: mocha
                    itemRadius: root.itemRadius
                    visible: root.canSeek
                    showIcon: false
                    value: root.trackLength > 0 ? Math.round(root.trackPosition / root.trackLength * 100) : 0
                    valueText: root.formatTime(root.trackPosition) + " / " + root.formatTime(root.trackLength)
                    accent: mocha.accent3
                    onDragToggled: (dragging) => root.draggingSeek = dragging
                    onMoved: (percent) => {
                        let target = root.trackLength * percent / 100;
                        root.trackPosition = target;
                        if (root.canSeek) root.player.position = target;
                    }
                }
            }
        }

        // --- Volume en microfoon --------------------------------------------
        PanelSlider {
            mocha: mocha
            itemRadius: root.itemRadius
            icon: root.muted || root.volume === 0 ? "󰝟" : (root.volume >= 70 ? "󰕾" : (root.volume >= 30 ? "󰖀" : "󰕿"))
            label: "Volume"
            value: root.volume
            dimmed: root.muted
            accent: mocha.accent3
            detailTooltip: "Geluidspaneel"
            onIconClicked: root.toggleMute("@DEFAULT_AUDIO_SINK@")
            onDragToggled: (dragging) => root.draggingVolume = dragging
            onMoved: (percent) => root.setVolume("@DEFAULT_AUDIO_SINK@", percent)
            onDetailRequested: root.panelSwitchRequested("volume")
        }
        PanelSlider {
            mocha: mocha
            itemRadius: root.itemRadius
            visible: root.micKnown
            icon: root.micMuted ? "󰍭" : "󰍬"
            label: "Microfoon"
            value: root.micVolume
            dimmed: root.micMuted
            accent: mocha.accent1
            onIconClicked: root.toggleMute("@DEFAULT_AUDIO_SOURCE@")
            onDragToggled: (dragging) => root.draggingMic = dragging
            onMoved: (percent) => root.setVolume("@DEFAULT_AUDIO_SOURCE@", percent)
        }
    }

    component CtlButton: Rectangle {
        id: ctl
        property string icon: ""
        property string label: ""
        property bool primary: false
        signal triggered()

        Layout.preferredWidth: label !== "" ? ctlRow.implicitWidth + 16 : (primary ? 36 : 30)
        Layout.preferredHeight: 28
        radius: Math.min(root.itemRadius, 14)
        opacity: enabled ? 1.0 : 0.4
        color: primary
            ? Qt.rgba(mocha.accent3.r, mocha.accent3.g, mocha.accent3.b, ctlMouse.containsMouse ? 0.40 : 0.26)
            : (ctlMouse.containsMouse
                ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
                : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05))
        scale: ctlMouse.pressed ? 0.94 : (ctlMouse.containsMouse ? 1.05 : 1.0)
        Behavior on color {
            ColorAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("standard") }
        }
        Behavior on scale {
            NumberAnimation { duration: ThemeConfig.durationToken("fast"); easing.type: ThemeConfig.easingToken("emphasized") }
        }

        Row {
            id: ctlRow
            anchors.centerIn: parent
            spacing: 5
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ctl.icon
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 14
                color: ctl.primary ? mocha.accent3 : mocha.text
            }
            Text {
                visible: ctl.label !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: ctl.label
                font.family: ThemeConfig.uiFont
                font.pixelSize: 10
                color: mocha.subtext0
                width: Math.min(implicitWidth, 90)
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: ctlMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ctl.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ctl.triggered()
        }
    }
}
