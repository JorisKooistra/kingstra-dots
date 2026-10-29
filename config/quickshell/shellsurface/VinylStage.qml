import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Venster om VinylStageContent: schermvullend op de Overlay-laag, boven de
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

    VinylStageContent {
        id: content
        anchors.fill: parent
        focus: true
        mocha: mocha
        accent: mocha.primary
        reveal: win.reveal
        originRect: win.host.stageOrigin
        Component.onCompleted: vinyl.discAngle = win.host.stageDiscAngle
        readonly property var p: win.host.activePlayer
        title: p ? String(p.trackTitle || "") : ""
        artist: p ? String(p.trackArtist || "") : ""
        album: p ? String(p.trackAlbum || "") : ""
        artUrl: p && p.trackArtUrl ? String(p.trackArtUrl) : ""
        trackKey: win.host.mediaTrackKey
        playing: win.host.playing
        tracking: win.host.mediaTracking
        progress: win.host.mediaProgress
        length: p && p.lengthSupported ? Number(p.length || 0) : 0
        canSeek: win.host.mediaCanSeek
        canPrevious: p !== null && p.canGoPrevious
        canNext: p !== null && p.canGoNext
        volume: win.host.mediaVolume
        onVolumeRequested: value => win.host.setMediaVolume(value)
        onTogglePlay: win.host.mediaToggle()
        onPrevious: if (p && p.canGoPrevious) p.previous()
        onNext: if (p && p.canGoNext) p.next()
        onSeek: fraction => win.host.mediaSeek(fraction)
        onCloseRequested: win.host.stageOpen = false
    }
}
