import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Venster om de schermvullende speler: VinylStageContent (draaitafel),
// CassetteStageContent (walkman) of DiscmanStageContent (discman), naar
// host.stageDevice. Schermvullend op de Overlay-laag, boven de
// bar, met toetsenbordfocus op aanvraag zolang hij open is: Exclusive
// blokkeerde klikken op de andere schermen. DesktopWidgets laadt dit
// alleen terwijl de weergave open is of nog wegfadet.
//
// Staat in shellsurface/ en niet naast DesktopWidgets: Quickshell maakt alleen
// een qmldir voor mappen die een gescand bestand importeert. desktop/ wordt
// via een LazyLoader-pad geladen, dus typen daar zijn onderling niet bekend
// ("VinylStage is not a type").
PanelWindow {
    id: win

    required property var host
    property bool open: false
    signal finished()

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "quickshell:kingstra-vinyl-stage"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    MatugenColors { id: mocha }

    // De animatie start pas als het venster echt op het scherm staat. Begint
    // hij eerder, dan mist hij de eerste frames (schokken) en is de kleine
    // speler al weg terwijl de grote nog niet zichtbaar is (knipperen).
    // Tot dan ligt de grote speler precies over de kleine heen.
    property real reveal: 0
    property bool started: false
    // Pas starten als het venster een paar frames heeft getekend: dan zijn
    // de canvassen (nerf, arm) klaar en kost het eerste animatieframe niets.
    FrameAnimation {
        running: win.visible && !win.started
        onTriggered: if (currentFrame >= 4 && elapsedTime >= 0.1) {
            win.started = true;
            win.host.stageCovering = true;
            win.reveal = Qt.binding(() => win.open ? 1 : 0);
        }
    }
    Behavior on reveal {
        enabled: win.started
        // Rustig in- en uitlopen: de speler groeit van de mediakaart naar het midden.
        // Lineair: VinylStageContent geeft elke fase zelf een zachte curve.
        NumberAnimation { duration: ThemeConfig.duration(950); easing.type: Easing.Linear }
    }
    onRevealChanged: if (started && !open && reveal <= 0.001) {
        win.host.stageCovering = false;
        finished();
    }
    // Dicht voordat de animatie begon: meteen klaar.
    onOpenChanged: if (!open && !started) finished()

    // Welke speler groot wordt: dezelfde als op de mediakaart.
    readonly property string device: win.host.stageDevice === "cassette" || win.host.stageDevice === "discman" ? win.host.stageDevice : "vinyl"
    readonly property var p: win.host.activePlayer
    // Stand van plaat, spoelen of cd van de kleine speler, zodat er bij de
    // overgang niets verspringt.
    readonly property var spin: win.host.stageSpin

    Loader {
        id: content
        anchors.fill: parent
        focus: true
        sourceComponent: win.device === "cassette" ? cassetteStage : win.device === "discman" ? discmanStage : vinylStage
        // Tab wisselt naar de volgende speler.
        Keys.onTabPressed: win.switchTo(win.kinds[(win.kinds.indexOf(win.device) + 1) % win.kinds.length])
    }

    // --- Wisselen van speler -------------------------------------------------
    // Rechtsboven: platenspeler, cassettespeler of discman. De keuze geldt
    // voor dit thema en de mediakaart wisselt mee. Kort uit- en infaden, zodat
    // de nieuwe speler niet ineens verspringt.
    readonly property var kinds: ["vinyl", "cassette", "discman"]
    property string pendingKind: ""
    function switchTo(kind) {
        if (kind === device || swap.running || !open) return;
        pendingKind = kind;
        swap.restart();
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: content; property: "opacity"; to: 0; duration: ThemeConfig.duration(140); easing.type: Easing.InQuad }
        ScriptAction { script: win.host.switchStage(win.pendingKind) }
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: ThemeConfig.duration(260); easing.type: Easing.OutQuad }
        ScriptAction { script: content.forceActiveFocus() }
    }
    Rectangle {
        id: switcher
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 24
        width: switchRow.implicitWidth + 8
        height: 36
        radius: height / 2
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.62)
        border.width: 1
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.14)
        opacity: win.reveal > 0.9 ? (win.reveal - 0.9) * 10 : 0
        visible: opacity > 0.01
        Row {
            id: switchRow
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: [{ id: "vinyl", title: "Platenspeler" }, { id: "cassette", title: "Cassette" }, { id: "discman", title: "Discman" }]
                Rectangle {
                    id: pick
                    required property var modelData
                    readonly property bool chosen: win.device === modelData.id
                    width: pickText.implicitWidth + 24
                    height: 28
                    radius: height / 2
                    color: chosen ? Qt.rgba(mocha.primary.r, mocha.primary.g, mocha.primary.b, 0.24)
                        : pickMouse.containsMouse ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08) : "transparent"
                    border.width: chosen ? 1 : 0
                    border.color: mocha.primary
                    scale: pickMouse.pressed ? 0.96 : 1
                    Behavior on color { ColorAnimation { duration: ThemeConfig.duration(180) } }
                    Behavior on scale { NumberAnimation { duration: ThemeConfig.duration(160); easing.type: Easing.OutQuart } }
                    Text {
                        id: pickText
                        anchors.centerIn: parent
                        text: pick.modelData.title
                        color: pick.chosen ? mocha.primary : mocha.text
                        font.family: ThemeConfig.uiFont
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: pickMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.switchTo(pick.modelData.id)
                    }
                }
            }
        }
    }

    Component {
        id: vinylStage
        VinylStageContent {
            anchors.fill: parent
            focus: true
            mocha: mocha
            accent: mocha.primary
            reveal: win.reveal
            originRect: win.host.stageOrigin
            title: win.p ? String(win.p.trackTitle || "") : ""
            artist: win.p ? String(win.p.trackArtist || "") : ""
            album: win.p ? String(win.p.trackAlbum || "") : ""
            artUrl: win.p && win.p.trackArtUrl ? String(win.p.trackArtUrl) : ""
            trackKey: win.host.mediaTrackKey
            playing: win.host.playing
            tracking: win.host.mediaTracking
            progress: win.host.mediaProgress
            length: win.p && win.p.lengthSupported ? Number(win.p.length || 0) : 0
            canSeek: win.host.mediaCanSeek
            canPrevious: win.p !== null && win.p.canGoPrevious
            canNext: win.p !== null && win.p.canGoNext
            volume: win.host.mediaVolume
            onVolumeRequested: value => win.host.setMediaVolume(value)
            onTogglePlay: win.host.mediaToggle()
            onPrevious: if (win.p && win.p.canGoPrevious) win.p.previous()
            onNext: if (win.p && win.p.canGoNext) win.p.next()
            onSeek: fraction => win.host.mediaSeek(fraction)
            onCloseRequested: win.host.stageOpen = false
            rpm: win.host.vinylRpm
            onRpmRequested: value => win.host.setVinylRpm(value)
            Component.onCompleted: if (win.spin && win.spin.a !== undefined) vinyl.discAngle = win.spin.a
        }
    }
    Component {
        id: cassetteStage
        CassetteStageContent {
            anchors.fill: parent
            focus: true
            mocha: mocha
            accent: mocha.primary
            reveal: win.reveal
            originRect: win.host.stageOrigin
            title: win.p ? String(win.p.trackTitle || "") : ""
            artist: win.p ? String(win.p.trackArtist || "") : ""
            album: win.p ? String(win.p.trackAlbum || "") : ""
            artUrl: win.p && win.p.trackArtUrl ? String(win.p.trackArtUrl) : ""
            trackKey: win.host.mediaTrackKey
            playing: win.host.playing
            tracking: win.host.mediaTracking
            progress: win.host.mediaProgress
            length: win.p && win.p.lengthSupported ? Number(win.p.length || 0) : 0
            canSeek: win.host.mediaCanSeek
            canPrevious: win.p !== null && win.p.canGoPrevious
            canNext: win.p !== null && win.p.canGoNext
            volume: win.host.mediaVolume
            onVolumeRequested: value => win.host.setMediaVolume(value)
            onTogglePlay: win.host.mediaToggle()
            onPrevious: if (win.p && win.p.canGoPrevious) win.p.previous()
            onNext: if (win.p && win.p.canGoNext) win.p.next()
            onSeek: fraction => win.host.mediaSeek(fraction)
            onCloseRequested: win.host.stageOpen = false
            Component.onCompleted: deck.applySpinState(win.spin)
        }
    }
    Component {
        id: discmanStage
        DiscmanStageContent {
            anchors.fill: parent
            focus: true
            mocha: mocha
            accent: mocha.primary
            reveal: win.reveal
            originRect: win.host.stageOrigin
            title: win.p ? String(win.p.trackTitle || "") : ""
            artist: win.p ? String(win.p.trackArtist || "") : ""
            album: win.p ? String(win.p.trackAlbum || "") : ""
            artUrl: win.p && win.p.trackArtUrl ? String(win.p.trackArtUrl) : ""
            trackKey: win.host.mediaTrackKey
            playing: win.host.playing
            tracking: win.host.mediaTracking
            progress: win.host.mediaProgress
            length: win.p && win.p.lengthSupported ? Number(win.p.length || 0) : 0
            canSeek: win.host.mediaCanSeek
            canPrevious: win.p !== null && win.p.canGoPrevious
            canNext: win.p !== null && win.p.canGoNext
            volume: win.host.mediaVolume
            onVolumeRequested: value => win.host.setMediaVolume(value)
            onTogglePlay: win.host.mediaToggle()
            onPrevious: if (win.p && win.p.canGoPrevious) win.p.previous()
            onNext: if (win.p && win.p.canGoNext) win.p.next()
            onSeek: fraction => win.host.mediaSeek(fraction)
            onCloseRequested: win.host.stageOpen = false
            Component.onCompleted: deck.applySpinState(win.spin)
        }
    }
}
