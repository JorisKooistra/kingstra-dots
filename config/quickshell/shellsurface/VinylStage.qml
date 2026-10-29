import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."

// Venster om VinylStageContent: schermvullend op de Overlay-laag, boven de
// bar, met toetsenbordfocus zolang hij open is. DesktopWidgets laadt dit
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
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MatugenColors { id: mocha }

    property real reveal: 0
    Component.onCompleted: reveal = Qt.binding(() => win.open ? 1 : 0)
    Behavior on reveal {
        // Rustig in- en uitlopen: de speler groeit van de mediakaart naar het midden.
        NumberAnimation { duration: ThemeConfig.duration(760); easing.type: Easing.InOutCubic }
    }
    onRevealChanged: if (!open && reveal <= 0.001) finished()

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
        onTogglePlay: win.host.mediaToggle()
        onPrevious: if (p && p.canGoPrevious) p.previous()
        onNext: if (p && p.canGoNext) p.next()
        onSeek: fraction => win.host.mediaSeek(fraction)
        onCloseRequested: win.host.stageOpen = false
    }
}
